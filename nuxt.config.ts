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
    '@vite-pwa/nuxt',
  ],

  pwa: {
    registerType: 'autoUpdate',
    includeAssets: ['favicon.webp', 'loader.webp'],
    manifest: {
      name: 'بُرهان',
      short_name: 'بُرهان',
      description: 'منصة الردود الفكرية والحوارات العلمية',
      theme_color: '#0a0a0a',
      background_color: '#0a0a0a',
      display: 'standalone',
      orientation: 'any',
      lang: 'ar',
      dir: 'rtl',
      icons: [
        { src: 'pwa/icon-192.png', sizes: '192x192', type: 'image/png' },
        { src: 'pwa/icon-512.png', sizes: '512x512', type: 'image/png' },
        { src: 'pwa/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any maskable' },
      ],
    },
    workbox: {
      globPatterns: ['**/*.{js,css,webp,png,svg,woff2}'],
      navigateFallback: null,
    },
  },

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
    bundle: { optimizeTranslationDirective: false },
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
