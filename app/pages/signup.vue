<script setup lang="ts">
definePageMeta({
  title: 'Sign Up',
})

const supabase = useSupabaseClient()
const { t } = useI18n()

const step = ref<'account' | 'org' | 'verify'>('account')
const loading = ref(false)
const error = ref('')

const account = reactive({
  fullName: '',
  email: '',
  password: '',
  confirmPassword: '',
})

const org = reactive({
  name: '',
  slug: '',
})

// OTP Reactive State
const otpCode = ref('')
const resendCooldown = ref(0)
const isResending = ref(false)
const isVerifying = ref(false)
const provisioningFailed = ref(false)
const verifiedAccessToken = ref('')

let cooldownTimer: ReturnType<typeof setInterval> | null = null

function startCooldown(seconds = 60) {
  if (cooldownTimer) {
    clearInterval(cooldownTimer)
    cooldownTimer = null
  }
  resendCooldown.value = seconds
  cooldownTimer = setInterval(() => {
    if (resendCooldown.value > 0) {
      resendCooldown.value--
    } else {
      if (cooldownTimer) {
        clearInterval(cooldownTimer)
        cooldownTimer = null
      }
    }
  }, 1000)
}

onUnmounted(() => {
  if (cooldownTimer) {
    clearInterval(cooldownTimer)
    cooldownTimer = null
  }
})

function sanitizeSlug(value: string) {
  return value.toLowerCase().replace(/[^a-z0-9-]/g, '').replace(/-+/g, '-').replace(/^-|-$/g, '')
}

function generateSlug(name: string) {
  return sanitizeSlug(name.replace(/\s+/g, '-'))
}

watch(() => org.name, (val) => {
  if (!org.slug || org.slug === sanitizeSlug(org.name)) {
    org.slug = generateSlug(val)
  }
})

function validateAccount(): boolean {
  if (!account.fullName || !account.email || !account.password) {
    error.value = 'Please fill in all fields'
    return false
  }
  if (account.password !== account.confirmPassword) {
    error.value = t('auth.password_mismatch')
    return false
  }
  if (account.password.length < 7) {
    error.value = t('auth.password_min_length')
    return false
  }
  return true
}

function validateOrg(): boolean {
  if (!org.name) {
    error.value = 'Organization name is required'
    return false
  }
  if (!org.slug || org.slug.length < 2) {
    error.value = t('auth.org_slug_format')
    return false
  }
  return true
}

function proceedToOrg() {
  error.value = ''
  if (validateAccount()) {
    step.value = 'org'
  }
}

function goBack() {
  error.value = ''
  step.value = 'account'
}

function changeEmail() {
  error.value = ''
  // Security boundary: wipe password and OTP state on return to account step
  account.password = ''
  account.confirmPassword = ''
  otpCode.value = ''
  verifiedAccessToken.value = ''
  provisioningFailed.value = false
  if (cooldownTimer) {
    clearInterval(cooldownTimer)
    cooldownTimer = null
  }
  resendCooldown.value = 0
  step.value = 'account'
}

async function provisionTenant(accessToken: string) {
  loading.value = true
  provisioningFailed.value = false
  error.value = ''

  try {
    const res = await $fetch<{ org: { org_slug: string } }>('/api/auth/register-tenant', {
      method: 'POST',
      body: {
        accessToken,
        orgName: org.name,
        orgSlug: org.slug,
      },
    })

    // Wipe sensitive in-memory state before navigating away
    otpCode.value = ''
    verifiedAccessToken.value = ''
    provisioningFailed.value = false

    await navigateTo('/dashboard')
  } catch (err: any) {
    provisioningFailed.value = true
    verifiedAccessToken.value = accessToken // Keep token strictly in memory for retry
    if (err?.statusCode === 409) {
      if (err?.data?.code === 'user_already_has_tenant') {
        error.value = t('auth.user_already_has_tenant', 'User already owns an organization')
      } else {
        error.value = t('auth.org_slug_taken')
      }
    } else {
      error.value = t('auth.provisioning_failed')
    }
  } finally {
    loading.value = false
  }
}

async function handleSignup() {
  error.value = ''
  if (!validateOrg()) return

  loading.value = true

  try {
    const { data, error: signupError } = await supabase.auth.signUp({
      email: account.email,
      password: account.password,
      options: {
        data: {
          full_name: account.fullName,
        },
      },
    })

    if (signupError) {
      const code = signupError.code || ''
      const msg = signupError.message || ''
      const status = signupError.status || 0

      if (code === 'weak_password' || status === 422 || msg.toLowerCase().includes('weak_password')) {
        error.value = t('auth.weak_password')
      } else if (code === 'over_email_send_rate_limit' || status === 429) {
        error.value = t('auth.rate_limited')
      } else if (code === 'user_already_exists' || msg.toLowerCase().includes('already registered')) {
        error.value = t('auth.signup_error')
      } else {
        error.value = t('auth.signup_error')
      }
      return
    }

    if (data?.session?.access_token) {
      // Direct session granted (email confirmation disabled)
      await provisionTenant(data.session.access_token)
      return
    }

    // Email Confirmation required
    // Security: wipe passwords from memory before entering OTP step
    account.password = ''
    account.confirmPassword = ''

    otpCode.value = ''
    startCooldown(60)
    step.value = 'verify'
  } catch (err: any) {
    error.value = t('auth.signup_error')
  } finally {
    loading.value = false
  }
}

async function handleVerifyOtp() {
  error.value = ''
  const trimmed = otpCode.value.trim()

  if (!/^\d{6}$/.test(trimmed)) {
    error.value = t('auth.invalid_otp')
    return
  }

  isVerifying.value = true

  try {
    const { data, error: otpError } = await supabase.auth.verifyOtp({
      email: account.email,
      token: trimmed,
      type: 'signup',
    })

    if (otpError) {
      const code = otpError.code || ''
      const msg = otpError.message || ''
      const status = otpError.status || 0

      if (code === 'otp_expired' || msg.toLowerCase().includes('expired')) {
        error.value = t('auth.expired_otp')
      } else if (code === 'over_email_send_rate_limit' || status === 429) {
        error.value = t('auth.rate_limited')
      } else if (code === 'otp_invalid' || code === 'bad_code' || msg.toLowerCase().includes('invalid')) {
        error.value = t('auth.invalid_otp')
      } else {
        error.value = t('auth.invalid_otp')
      }
      return
    }

    const accessToken = data?.session?.access_token
    if (!accessToken) {
      error.value = t('auth.provisioning_failed')
      return
    }

    await provisionTenant(accessToken)
  } catch (err: any) {
    error.value = t('auth.provisioning_failed')
  } finally {
    isVerifying.value = false
  }
}

async function handleResendOtp() {
  if (resendCooldown.value > 0 || isResending.value) return

  error.value = ''
  isResending.value = true

  try {
    const { error: resendErr } = await supabase.auth.resend({
      type: 'signup',
      email: account.email,
    })

    if (resendErr) {
      const code = resendErr.code || ''
      const status = resendErr.status || 0
      if (code === 'over_email_send_rate_limit' || status === 429) {
        error.value = t('auth.rate_limited')
      } else {
        error.value = t('auth.invalid_otp')
      }
      return
    }

    otpCode.value = ''
    startCooldown(60)
  } catch {
    error.value = t('auth.invalid_otp')
  } finally {
    isResending.value = false
  }
}
</script>

<template>
  <div class="min-h-[calc(100vh-4rem)] flex items-center justify-center px-4 py-12">
    <div class="absolute inset-0 overflow-hidden pointer-events-none">
      <div class="absolute top-1/4 -right-40 w-[500px] h-[500px] bg-gold/5 rounded-full blur-3xl" />
      <div class="absolute bottom-1/4 -left-40 w-[400px] h-[400px] bg-gold/3 rounded-full blur-3xl" />
    </div>

    <div class="relative w-full max-w-md">
      <GlassCard padding="lg">
        <div class="text-center mb-8">
          <h1 class="text-2xl font-bold gradient-gold mb-2">
            {{ step === 'verify' ? $t('auth.otp_title') : $t('auth.create_account') }}
          </h1>
          <p class="text-sm text-gray-500">
            {{
              step === 'account'
                ? $t('brand.tagline')
                : step === 'org'
                  ? $t('auth.org_setup_desc')
                  : $t('auth.otp_desc', { email: account.email })
            }}
          </p>
        </div>

        <!-- Step indicator (3 steps) -->
        <div class="flex items-center justify-center gap-2 mb-8">
          <div
            class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-all duration-300"
            :class="step === 'account' ? 'bg-gold text-onyx' : 'bg-gold/20 text-gold'"
          >1</div>
          <div class="w-6 h-0.5 rounded" :class="step === 'org' || step === 'verify' ? 'bg-gold/60' : 'bg-white/10'" />
          <div
            class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-all duration-300"
            :class="step === 'org' ? 'bg-gold text-onyx' : step === 'verify' ? 'bg-gold/20 text-gold' : 'bg-white/10 text-gray-500'"
          >2</div>
          <div class="w-6 h-0.5 rounded" :class="step === 'verify' ? 'bg-gold/60' : 'bg-white/10'" />
          <div
            class="w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-all duration-300"
            :class="step === 'verify' ? 'bg-gold text-onyx' : 'bg-white/10 text-gray-500'"
          >3</div>
        </div>

        <!-- Step 1: Account -->
        <form v-if="step === 'account'" novalidate @submit.prevent="proceedToOrg">
          <div class="space-y-4">
            <div>
              <label for="name" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.full_name_label') }}
              </label>
              <input
                id="name"
                v-model="account.fullName"
                type="text"
                autocomplete="name"
                :placeholder="$t('auth.full_name_placeholder')"
                class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
              />
            </div>

            <div>
              <label for="email" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.email') }}
              </label>
              <input
                id="email"
                v-model="account.email"
                type="email"
                autocomplete="email"
                :placeholder="$t('auth.email_placeholder')"
                class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                required
              />
            </div>

            <div>
              <label for="password" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.password') }}
              </label>
              <input
                id="password"
                v-model="account.password"
                type="password"
                autocomplete="new-password"
                :placeholder="$t('auth.password_placeholder')"
                class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                required
              />
            </div>

            <div>
              <label for="confirm" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.confirm_password') }}
              </label>
              <input
                id="confirm"
                v-model="account.confirmPassword"
                type="password"
                autocomplete="new-password"
                :placeholder="$t('auth.confirm_password')"
                class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                required
              />
            </div>

            <div v-if="error" class="text-red-400 text-sm text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
              {{ error }}
            </div>

            <Button type="submit" block>
              {{ $t('common.next') }}
            </Button>
          </div>
        </form>

        <!-- Step 2: Organization -->
        <form v-else-if="step === 'org'" novalidate @submit.prevent="handleSignup">
          <div class="space-y-4">
            <div>
              <label for="org-name" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.org_name') }}
              </label>
              <input
                id="org-name"
                v-model="org.name"
                type="text"
                :placeholder="$t('auth.org_name_placeholder')"
                class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                :disabled="loading"
                required
              />
            </div>

            <div>
              <label for="org-slug" class="block text-sm font-medium text-gray-400 mb-1.5">
                {{ $t('auth.org_slug') }}
              </label>
              <div class="relative">
                <span class="absolute inset-y-0 left-4 flex items-center text-xs text-gray-600 pointer-events-none" dir="ltr">/</span>
                <input
                  id="org-slug"
                  v-model="org.slug"
                  type="text"
                  :placeholder="$t('auth.org_slug_placeholder')"
                  class="w-full px-4 py-2.5 pl-7 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 font-mono text-sm focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                  :disabled="loading"
                  dir="ltr"
                  required
                  @input="org.slug = sanitizeSlug(org.slug)"
                />
              </div>
              <p class="text-xs text-gray-600 mt-1.5">{{ $t('auth.org_slug_format') }}</p>
            </div>

            <div v-if="error" class="text-red-400 text-sm text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
              {{ error }}
            </div>

            <div class="flex gap-3">
              <Button variant="outline" :disabled="loading" @click="goBack">
                {{ $t('common.previous') }}
              </Button>
              <Button type="submit" block :loading="loading">
                {{ $t('auth.signup_btn') }}
              </Button>
            </div>
          </div>
        </form>

        <!-- Step 3: Verify OTP -->
        <div v-else-if="step === 'verify'" class="space-y-5">
          <div class="p-3 bg-white/5 border border-white/10 rounded-xl text-center">
            <span class="text-xs text-gray-400 block mb-1">{{ $t('auth.email') }}</span>
            <span dir="ltr" class="text-sm font-semibold text-gold">{{ account.email }}</span>
          </div>

          <!-- Provisioning retry state (if verifyOtp succeeded but register-tenant failed) -->
          <div v-if="provisioningFailed" class="space-y-4">
            <div class="text-red-400 text-sm text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3">
              {{ error || $t('auth.provisioning_failed') }}
            </div>

            <Button
              type="button"
              block
              :loading="loading"
              @click="provisionTenant(verifiedAccessToken)"
            >
              {{ $t('auth.retry_provisioning') }}
            </Button>
          </div>

          <!-- Normal OTP entry form -->
          <form v-else novalidate @submit.prevent="handleVerifyOtp">
            <div class="space-y-4">
              <div>
                <label for="otp-input" class="block text-sm font-medium text-gray-400 mb-1.5 text-center">
                  {{ $t('auth.otp_title') }}
                </label>
                <input
                  id="otp-input"
                  v-model="otpCode"
                  type="text"
                  inputmode="numeric"
                  autocomplete="one-time-code"
                  maxlength="6"
                  dir="ltr"
                  :placeholder="$t('auth.otp_placeholder')"
                  class="w-full px-4 py-3 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 font-mono text-xl font-bold tracking-[0.5em] text-center focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                  :disabled="isVerifying || loading"
                  required
                  @input="otpCode = otpCode.replace(/[^0-9]/g, '').slice(0, 6)"
                />
              </div>

              <div v-if="error" class="text-red-400 text-sm text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
                {{ error }}
              </div>

              <Button type="submit" block :loading="isVerifying || loading" :disabled="otpCode.trim().length !== 6">
                {{ $t('auth.verify_btn') }}
              </Button>

              <div class="flex items-center justify-between pt-2">
                <button
                  type="button"
                  class="text-xs text-gray-400 hover:text-white transition-colors"
                  :disabled="isVerifying || loading"
                  @click="changeEmail"
                >
                  {{ $t('auth.change_email') }}
                </button>

                <button
                  type="button"
                  class="text-xs font-medium text-gold hover:text-gold-500 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  :disabled="resendCooldown > 0 || isResending || isVerifying || loading"
                  @click="handleResendOtp"
                >
                  <span v-if="resendCooldown > 0">
                    {{ $t('auth.resend_wait', { seconds: resendCooldown }) }}
                  </span>
                  <span v-else-if="isResending">...</span>
                  <span v-else>
                    {{ $t('auth.resend_btn') }}
                  </span>
                </button>
              </div>
            </div>
          </form>
        </div>

        <div class="mt-6 text-center">
          <p class="text-sm text-gray-500">
            {{ $t('auth.has_account') }}
            <NuxtLink to="/login" class="text-gold hover:text-gold-500 transition-colors font-medium">
              {{ $t('auth.login_btn') }}
            </NuxtLink>
          </p>
        </div>
      </GlassCard>
    </div>
  </div>
</template>
