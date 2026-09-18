import crypto from 'node:crypto'

export interface EncryptedPayload {
  ciphertext: string
  iv: string
  tag: string
  keyVersion: number
}

const CURRENT_KEY_VERSION = 1

/**
 * Load and validate the master encryption key from environment.
 * Fail-closed: Must be exactly 64 hex characters decoding to 32 raw bytes.
 */
export function getMasterKey(): Buffer {
  const rawKey = process.env.BYOK_ENCRYPTION_KEY?.trim()
  if (!rawKey) {
    throw new Error('BYOK_ENCRYPTION_KEY is not configured in environment')
  }

  if (!/^[0-9a-fA-F]{64}$/.test(rawKey)) {
    throw new Error('BYOK_ENCRYPTION_KEY must be exactly 64 hexadecimal characters (32 bytes)')
  }

  const keyBuf = Buffer.from(rawKey, 'hex')
  if (keyBuf.length !== 32) {
    throw new Error('BYOK_ENCRYPTION_KEY decoded byte length is invalid (must be 32 bytes)')
  }

  return keyBuf
}

/**
 * Encrypt a plaintext secret using AES-256-GCM.
 * Generates a cryptographically random unique 12-byte IV for each invocation.
 */
export function encryptSecret(plaintext: string): EncryptedPayload {
  if (typeof plaintext !== 'string' || plaintext.length === 0) {
    throw new Error('Plaintext secret must be a non-empty string')
  }

  const masterKey = getMasterKey()
  const iv = crypto.randomBytes(12)
  const cipher = crypto.createCipheriv('aes-256-gcm', masterKey, iv)

  const encryptedBuf = Buffer.concat([
    cipher.update(plaintext, 'utf8'),
    cipher.final(),
  ])

  const tag = cipher.getAuthTag()

  return {
    ciphertext: encryptedBuf.toString('hex'),
    iv: iv.toString('hex'),
    tag: tag.toString('hex'),
    keyVersion: CURRENT_KEY_VERSION,
  }
}

/**
 * Decrypt an AES-256-GCM payload.
 * Verifies authenticity tag; fails safely if tampered or invalid.
 */
export function decryptSecret(ciphertext: string, iv: string, tag: string, keyVersion: number = CURRENT_KEY_VERSION): string {
  if (!ciphertext || !iv || !tag) {
    throw new Error('Missing encrypted material components (ciphertext, iv, or tag)')
  }

  const masterKey = getMasterKey()

  try {
    const ivBuf = Buffer.from(iv, 'hex')
    const tagBuf = Buffer.from(tag, 'hex')
    const cipherBuf = Buffer.from(ciphertext, 'hex')

    if (ivBuf.length !== 12) {
      throw new Error('Invalid IV length')
    }
    if (tagBuf.length !== 16) {
      throw new Error('Invalid auth tag length')
    }

    const decipher = crypto.createDecipheriv('aes-256-gcm', masterKey, ivBuf)
    decipher.setAuthTag(tagBuf)

    const decrypted = Buffer.concat([
      decipher.update(cipherBuf),
      decipher.final(),
    ])

    return decrypted.toString('utf8')
  } catch (err: any) {
    throw new Error('Decryption failed: authentication tag verification failed or corrupted ciphertext')
  }
}
