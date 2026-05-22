export type LocaleCode = 'ar' | 'en'
export type LocalizedJson<T = string> = Partial<Record<LocaleCode, T>>

export const useLocale = () => {
  const { locale, setLocale, t } = useI18n()

  const isRtl = computed<boolean>(() => locale.value === 'ar')
  const isArabic = computed<boolean>(() => locale.value === 'ar')
  const currentLocale = computed<LocaleCode>(() => (locale.value === 'en' ? 'en' : 'ar'))

  function extractLocalized<T = string>(jsonb: LocalizedJson<T> | null | undefined, fallback: T | null = null): T | null {
    if (!jsonb) return fallback
    return jsonb[currentLocale.value] ?? jsonb.en ?? fallback ?? null
  }

  async function switchLocale(newLocale: string) {
    const html = document.documentElement
    html.classList.remove('rtl', 'ltr')
    await setLocale(newLocale)
    html.lang = newLocale
    html.dir = newLocale === 'ar' ? 'rtl' : 'ltr'
    html.classList.add(newLocale === 'ar' ? 'rtl' : 'ltr')
  }

  function toggleLocale() {
    return switchLocale(currentLocale.value === 'ar' ? 'en' : 'ar')
  }

  function localePath(path: string): string {
    if (currentLocale.value === 'ar') return path
    return `/${currentLocale.value}${path.startsWith('/') ? '' : '/'}${path}`
  }

  return {
    locale,
    currentLocale,
    isRtl,
    isArabic,
    extractLocalized,
    switchLocale,
    toggleLocale,
    localePath,
    $t: t,
  }
}
