export function localizedValue(value: unknown, locale: string): string {
  if (!value) return ''
  const obj = typeof value === 'string' ? JSON.parse(value as string) : value
  return obj?.[locale] || obj?.ar || ''
}
