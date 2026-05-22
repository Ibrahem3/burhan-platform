import ar from './i18n/ar.json'
import en from './i18n/en.json'

export default defineI18nConfig(() => ({
  legacy: false,
  locale: 'ar',
  messages: {
    ar,
    en,
  },
}))
