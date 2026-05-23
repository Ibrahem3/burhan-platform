export default defineNuxtConfig({
  compatibilityDate: '2025-04-01',

  future: {
    compatibilityVersion: 4,
  },

  srcDir: 'app/',

  nitro: {
    preset: 'cloudflare-pages',
  },

  modules: [
    '@nuxtjs/tailwindcss',
    '@nuxtjs/supabase',
    '@nuxtjs/i18n',
  ],

  components: [
    { path: '~/components/ui', pathPrefix: false },
    { path: '~/components/hub', pathPrefix: false },
    { path: '~/components/tenant', pathPrefix: false },
    { path: '~/components/premium', pathPrefix: false },
    { path: '~/components/dashboard', pathPrefix: false },
    '~/components',
  ],

  tailwindcss: {
    configPath: './tailwind.config.ts',
    cssPath: './app/assets/css/main.css',
    viewer: false,
    exposeConfig: false,
  },

  supabase: {
    serviceKey: process.env.SUPABASE_SECRET_KEY,
    redirect: false,
    clientOptions: {
      auth: {
        flowType: 'pkce',
        detectSessionInUrl: true,
        persistSession: true,
      },
    },
  },

  i18n: {
    restructureDir: false,
    locales: [
      { code: 'ar', iso: 'ar-EG', dir: 'rtl' },
      { code: 'en', iso: 'en-US', dir: 'ltr' },
    ],
    defaultLocale: 'ar',
    strategy: 'prefix_except_default',
    vueI18n: './app/i18n.config.ts',
  },

  vite: {
    optimizeDeps: {
      include: [
        '@vue/devtools-core',
        '@vue/devtools-kit',
      ],
    },
  },

  app: {
    pageTransition: {
      name: 'fade',
      mode: 'out-in',
    },
  },
})
