export function localizedValue(value: unknown, locale: string): string {
  if (!value) return ''

  if (typeof value === 'object' && value !== null) {
    const obj = value as Record<string, any>
    return obj[locale] || obj.ar || obj.en || ''
  }

  if (typeof value === 'string') {
    const trimmed = value.trim()
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        const parsed = JSON.parse(trimmed)
        if (typeof parsed === 'object' && parsed !== null) {
          return parsed[locale] || parsed.ar || parsed.en || trimmed
        }
      } catch {
        return value
      }
    }
    return value
  }

  return String(value)
}
