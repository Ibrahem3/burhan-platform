<script setup lang="ts">
type OrgWithCount = {
  id: string
  name: any
  org_slug: string
  settings: any
  created_at: string
  content_count: number
}

definePageMeta({
  title: 'Main Hub',
  layout: false,
})

const { t, locale } = useI18n()
const { currentLocale, toggleLocale } = useLocale()
const { user, profile, signOut, isAuthenticated } = useUser()
const currentLocaleVal = computed(() => locale.value as 'ar' | 'en')

const { data: organizations, pending, error } = useFetch<OrgWithCount[]>('/api/orgs', {
  transform: (data) => data ?? [],
})

const speedDialOpen = ref(false)

const speedDialItems = computed(() => [
  {
    key: 'home',
    icon: '<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" /></svg>',
    label: t('tenant.nav_home'),
    action: () => { speedDialOpen.value = false; scrollToSection('hub-hero') },
  },
  {
    key: 'orgs',
    icon: '<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>',
    label: t('hub.orgs_title'),
    action: () => { speedDialOpen.value = false; scrollToSection('orgs-grid') },
  },
  ...(isAuthenticated.value ? [{
    key: 'dashboard',
    icon: '<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>',
    label: t('nav.dashboard'),
    action: () => { speedDialOpen.value = false; navigateTo('/dashboard') },
  }] : []),
  {
    key: 'locale',
    icon: '<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m0 4h.01M21 12l-4 4m0 0l-4-4m4 4V8" /></svg>',
    label: currentLocale.value === 'ar' ? 'English' : 'العربية',
    action: () => { toggleLocale(); speedDialOpen.value = false },
  },
  ...(!isAuthenticated.value ? [{
    key: 'signup',
    icon: '<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" /></svg>',
    label: t('nav.signup'),
    action: () => { speedDialOpen.value = false; navigateTo('/signup') },
  }, {
    key: 'login',
    icon: '<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1" /></svg>',
    label: t('nav.login'),
    action: () => { speedDialOpen.value = false; navigateTo('/login') },
  }] : []),
  ...(isAuthenticated.value ? [{
    key: 'logout',
    red: true,
    icon: '<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" /></svg>',
    label: t('nav.logout'),
    action: () => { speedDialOpen.value = false; signOut() },
  }] : []),
])

useHead({
  meta: [
    { name: 'description', content: t('seo.hub_description') },
    { property: 'og:title', content: t('seo.hub_title') },
    { property: 'og:description', content: t('seo.hub_description') },
  ],
})

function localizedName(org: OrgWithCount): string {
  return localizedValue(org.name, currentLocaleVal.value)
}

function localizedNameEn(org: OrgWithCount): string {
  return localizedValue(org.name, 'en')
}

function orgLogo(org: OrgWithCount): string | null {
  if (!org.settings) return null
  const s = typeof org.settings === 'string' ? JSON.parse(org.settings) : org.settings
  return s?.logos?.dark || s?.logos?.light || null
}

function scrollToSection(id: string) {
  speedDialOpen.value = false
  const el = document.getElementById(id)
  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' })
}
</script>

<template>
  <div class="min-h-screen bg-onyx text-gray-100 flex flex-col">
    <a
      href="#main-content"
      class="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-[100] focus:px-4 focus:py-2 focus:bg-gold focus:text-onyx focus:rounded-xl focus:outline-none"
    >
      {{ $t('layout.skip_to_content') }}
    </a>

    <!-- ===== Backdrop for Quick Panel ===== -->
    <Transition name="fade">
      <div
        v-if="speedDialOpen"
        class="fixed inset-0 z-40 bg-black/40 backdrop-blur-sm"
        @click="speedDialOpen = false"
      />
    </Transition>

    <!-- ===== Modern Floating Command Dock ===== -->
    <div
      class="fixed bottom-4 sm:bottom-6 z-50 flex flex-col"
      :class="currentLocale === 'ar' ? 'right-4 sm:right-6 items-end' : 'left-4 sm:left-6 items-start'"
    >
      <!-- Sleek Glass Command Panel -->
      <Transition name="panel-pop">
        <div
          v-if="speedDialOpen"
          class="mb-2.5 sm:mb-3 w-72 sm:w-80 max-w-[calc(100vw-2rem)] glass backdrop-blur-2xl bg-onyx/90 border border-white/10 rounded-2xl sm:rounded-3xl p-3 sm:p-4 shadow-2xl shadow-black/80 ring-1 ring-white/5 flex flex-col gap-2.5 sm:gap-3.5"
        >
          <!-- User / Status Header -->
          <div class="flex items-center justify-between pb-2 sm:pb-3 border-b border-white/5 px-1">
            <div class="flex items-center gap-2 sm:gap-2.5 min-w-0">
              <div class="w-7 h-7 sm:w-8 sm:h-8 rounded-lg sm:rounded-xl bg-gold/10 border border-gold/20 flex items-center justify-center shrink-0 text-gold text-[11px] sm:text-xs font-bold">
                <span v-if="isAuthenticated && profile?.role">{{ profile.role.charAt(0).toUpperCase() }}</span>
                <span v-else>✦</span>
              </div>
              <div class="min-w-0 flex-1">
                <p class="text-[11px] sm:text-xs font-medium text-white truncate">
                  {{ isAuthenticated ? (user?.email || $t('nav.dashboard')) : $t('hub.title') }}
                </p>
                <p class="text-[9px] sm:text-[10px] text-gray-400 capitalize">
                  {{ isAuthenticated ? (profile?.role || 'User') : $t('seo.hub_title') }}
                </p>
              </div>
            </div>

            <!-- Close button -->
            <button
              class="w-6 h-6 sm:w-7 sm:h-7 rounded-lg text-gray-400 hover:text-white hover:bg-white/5 flex items-center justify-center transition-colors"
              @click="speedDialOpen = false"
            >
              <svg class="w-3.5 h-3.5 sm:w-4 sm:h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Section: Quick Navigation -->
          <div class="space-y-0.5 sm:space-y-1">
            <p class="text-[9px] sm:text-[10px] font-semibold text-gray-500 uppercase tracking-wider px-2 mb-0.5 sm:mb-1">
              {{ currentLocale === 'ar' ? 'التنقل السريع' : 'Navigation' }}
            </p>
            <button
              class="w-full flex items-center gap-2.5 sm:gap-3 px-2.5 sm:px-3 py-1.5 sm:py-2 rounded-lg sm:rounded-xl text-[11px] sm:text-xs font-medium text-gray-300 hover:text-white hover:bg-white/5 transition-all text-start group"
              @click="speedDialOpen = false; scrollToSection('hub-hero')"
            >
              <div class="w-6 h-6 sm:w-7 sm:h-7 rounded-md sm:rounded-lg bg-white/5 flex items-center justify-center text-gray-400 group-hover:text-gold group-hover:bg-gold/10 transition-colors">
                <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                </svg>
              </div>
              <span class="flex-1">{{ $t('tenant.nav_home') }}</span>
            </button>

            <button
              class="w-full flex items-center gap-2.5 sm:gap-3 px-2.5 sm:px-3 py-1.5 sm:py-2 rounded-lg sm:rounded-xl text-[11px] sm:text-xs font-medium text-gray-300 hover:text-white hover:bg-white/5 transition-all text-start group"
              @click="speedDialOpen = false; scrollToSection('orgs-grid')"
            >
              <div class="w-6 h-6 sm:w-7 sm:h-7 rounded-md sm:rounded-lg bg-white/5 flex items-center justify-center text-gray-400 group-hover:text-gold group-hover:bg-gold/10 transition-colors">
                <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                </svg>
              </div>
              <span class="flex-1">{{ $t('hub.orgs_title') }}</span>
              <span class="text-[9px] sm:text-[10px] text-gray-500 bg-white/5 px-1.5 sm:px-2 py-0.5 rounded-full">{{ organizations?.length || 0 }}</span>
            </button>
          </div>

          <!-- Section: Account / Actions -->
          <div class="space-y-0.5 sm:space-y-1 pt-1 border-t border-white/5">
            <p class="text-[9px] sm:text-[10px] font-semibold text-gray-500 uppercase tracking-wider px-2 mb-0.5 sm:mb-1">
              {{ currentLocale === 'ar' ? 'الحساب والنظام' : 'Account & Controls' }}
            </p>

            <template v-if="isAuthenticated">
              <button
                class="w-full flex items-center gap-2.5 sm:gap-3 px-2.5 sm:px-3 py-1.5 sm:py-2 rounded-lg sm:rounded-xl text-[11px] sm:text-xs font-medium text-gold hover:text-gold-300 hover:bg-gold/10 transition-all text-start group"
                @click="speedDialOpen = false; navigateTo('/dashboard')"
              >
                <div class="w-6 h-6 sm:w-7 sm:h-7 rounded-md sm:rounded-lg bg-gold/10 flex items-center justify-center text-gold">
                  <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                </div>
                <span class="flex-1">{{ $t('nav.dashboard') }}</span>
                <span class="text-[9px] sm:text-[10px] text-gold/80 border border-gold/30 px-1.5 py-0.5 rounded">Pro</span>
              </button>

              <button
                class="w-full flex items-center gap-2.5 sm:gap-3 px-2.5 sm:px-3 py-1.5 sm:py-2 rounded-lg sm:rounded-xl text-[11px] sm:text-xs font-medium text-red-400 hover:text-red-300 hover:bg-red-500/10 transition-all text-start group"
                @click="speedDialOpen = false; signOut()"
              >
                <div class="w-6 h-6 sm:w-7 sm:h-7 rounded-md sm:rounded-lg bg-red-500/10 flex items-center justify-center text-red-400">
                  <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                  </svg>
                </div>
                <span class="flex-1">{{ $t('nav.logout') }}</span>
              </button>
            </template>

            <template v-else>
              <div class="grid grid-cols-2 gap-1.5 sm:gap-2 pt-0.5 sm:pt-1">
                <button
                  class="flex items-center justify-center gap-1.5 sm:gap-2 py-1.5 sm:py-2 px-2 sm:px-3 rounded-lg sm:rounded-xl text-[11px] sm:text-xs font-medium text-gray-300 bg-white/5 hover:bg-white/10 border border-white/5 transition-all"
                  @click="speedDialOpen = false; navigateTo('/login')"
                >
                  <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1" />
                  </svg>
                  <span>{{ $t('nav.login') }}</span>
                </button>

                <button
                  class="flex items-center justify-center gap-1.5 sm:gap-2 py-1.5 sm:py-2 px-2 sm:px-3 rounded-lg sm:rounded-xl text-[11px] sm:text-xs font-medium text-onyx bg-gold hover:bg-gold-500 shadow-md shadow-gold/20 transition-all"
                  @click="speedDialOpen = false; navigateTo('/signup')"
                >
                  <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                  </svg>
                  <span>{{ $t('nav.signup') }}</span>
                </button>
              </div>
            </template>
          </div>

          <!-- Section: Footer / Locale Switcher -->
          <div class="pt-1.5 sm:pt-2 border-t border-white/5 flex items-center justify-between px-1">
            <span class="text-[10px] sm:text-[11px] text-gray-500">{{ currentLocale === 'ar' ? 'اللغة' : 'Language' }}</span>
            <button
              class="flex items-center gap-1 sm:gap-1.5 text-[11px] sm:text-xs text-gold hover:text-gold-300 bg-gold/5 hover:bg-gold/10 border border-gold/20 px-2 sm:px-2.5 py-0.5 sm:py-1 rounded-md sm:rounded-lg transition-all"
              @click="toggleLocale(); speedDialOpen = false"
            >
              <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m0 4h.01M21 12l-4 4m0 0l-4-4m4 4V8" />
              </svg>
              <span>{{ currentLocale === 'ar' ? 'English' : 'العربية' }}</span>
            </button>
          </div>
        </div>
      </Transition>

      <!-- Sleek Trigger Button -->
      <button
        class="group relative h-10 sm:h-13 px-2.5 sm:px-4 glass backdrop-blur-xl bg-onyx/80 hover:bg-onyx/95 rounded-xl sm:rounded-2xl border border-white/10 hover:border-gold/40 shadow-lg sm:shadow-xl shadow-black/50 hover:shadow-glow transition-all duration-300 flex items-center gap-2 sm:gap-2.5 cursor-pointer select-none"
        :aria-label="$t('common.menu')"
        @click="speedDialOpen = !speedDialOpen"
      >
        <!-- Gold Ambient Indicator -->
        <span class="absolute -top-0.5 -right-0.5 sm:-top-1 sm:-right-1 flex h-2 w-2 sm:h-2.5 sm:w-2.5">
          <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-gold opacity-75" />
          <span class="relative inline-flex rounded-full h-2 w-2 sm:h-2.5 sm:w-2.5 bg-gold" />
        </span>

        <!-- Icon Animation -->
        <div class="w-6 h-6 sm:w-7 sm:h-7 rounded-lg sm:rounded-xl bg-gold/10 border border-gold/20 flex items-center justify-center text-gold group-hover:scale-105 transition-transform duration-300">
          <svg
            class="w-3.5 h-3.5 sm:w-4 sm:h-4 transition-transform duration-300"
            :class="{ 'rotate-90 text-gold-300': speedDialOpen }"
            fill="none" viewBox="0 0 24 24" stroke="currentColor"
          >
            <path v-if="!speedDialOpen" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16m-7 6h7" />
            <path v-else stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </div>

        <span class="text-xs font-semibold text-gray-200 group-hover:text-gold transition-colors hidden sm:inline">
          {{ speedDialOpen ? (currentLocale === 'ar' ? 'إغلاق' : 'Close') : (currentLocale === 'ar' ? 'القائمة السريعة' : 'Quick Menu') }}
        </span>
      </button>
    </div>

    <!-- ===== Main Content ===== -->
    <main id="main-content" class="flex-1">
      <!-- Hero Section -->
      <section id="hub-hero" class="relative overflow-hidden py-20 md:py-28 lg:py-36">
        <div class="absolute top-1/4 -left-40 w-[500px] h-[500px] bg-gold/5 rounded-full blur-3xl" />
        <div class="absolute top-1/3 -right-40 w-[400px] h-[400px] bg-gold/3 rounded-full blur-3xl" />
        <div class="absolute bottom-1/4 left-1/2 -translate-x-1/2 w-[600px] h-[300px] bg-gold/3 rounded-full blur-3xl" />
        <div class="absolute inset-0 bg-gradient-to-b from-gold/5 via-transparent to-transparent pointer-events-none" />

        <div class="relative z-10 text-center max-w-4xl mx-auto px-4">
          <div class="animate-fade-in">
            <h1 class="text-5xl md:text-7xl lg:text-8xl font-bold mb-6 tracking-tight">
              <span class="gradient-gold">{{ $t('hub.title') }}</span>
            </h1>
            <p class="text-lg md:text-xl lg:text-2xl text-gray-400 mb-8 max-w-2xl mx-auto leading-relaxed">
              {{ $t('hub.hero_description') }}
            </p>
            <div class="flex flex-wrap items-center justify-center gap-4">
              <button
                class="cta-glow inline-flex items-center justify-center font-medium transition-all duration-300 rounded-xl px-8 py-3.5 md:px-10 md:py-4 text-base md:text-lg bg-gold text-onyx hover:bg-gold-500 active:bg-gold-600 shadow-lg shadow-gold/20"
                @click="scrollToSection('orgs-grid')"
              >
                {{ $t('hub.browse_orgs') }}
              </button>
              <Button variant="outline" size="lg">
                {{ $t('hub.cta_learn') }}
              </Button>
            </div>
          </div>
        </div>
      </section>

      <!-- Organizations Grid -->
      <section id="orgs-grid" class="max-w-7xl mx-auto px-4 pt-16 md:pt-24 pb-24">
        <div class="mb-10 text-center">
          <h2 class="text-3xl md:text-4xl font-bold text-white mb-2">
            {{ $t('hub.orgs_title') }}
          </h2>
          <p class="text-sm text-gray-500">
            {{ $t('hub.orgs_subtitle') }}
          </p>
        </div>

        <!-- Loading -->
        <div v-if="pending" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          <div v-for="i in 6" :key="i">
            <GlassCard>
              <div class="animate-pulse space-y-4">
                <div class="w-16 h-16 rounded-2xl bg-white/5 mx-auto" />
                <div class="h-5 bg-white/5 rounded w-2/3 mx-auto" />
                <div class="h-3 bg-white/5 rounded w-1/2 mx-auto" />
                <div class="flex justify-center">
                  <div class="h-6 bg-white/5 rounded-full w-20" />
                </div>
              </div>
            </GlassCard>
          </div>
        </div>

        <!-- Error -->
        <div v-else-if="error" class="text-center py-16">
          <GlassCard class="max-w-md mx-auto">
            <div class="py-8">
              <div class="w-12 h-12 mx-auto mb-4 rounded-full bg-red-500/10 flex items-center justify-center">
                <svg class="w-6 h-6 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
                </svg>
              </div>
              <p class="text-gray-400">{{ $t('common.error') }}</p>
              <p class="text-xs text-gray-600 mt-1">{{ $t('common.retry') }}</p>
            </div>
          </GlassCard>
        </div>

        <!-- Empty -->
        <div v-else-if="!organizations || organizations.length === 0" class="text-center py-16">
          <GlassCard class="max-w-md mx-auto">
            <div class="py-8">
              <svg class="w-12 h-12 text-gray-600 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
              </svg>
              <p class="text-gray-500">{{ $t('hub.no_orgs') }}</p>
            </div>
          </GlassCard>
        </div>

        <!-- Orgs cards -->
        <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          <NuxtLink
            v-for="org in organizations"
            :key="org.id"
            :to="`/${org.org_slug}`"
            class="block group focus:outline-none focus-visible:ring-2 focus-visible:ring-gold/50 rounded-2xl"
          >
            <div
              class="relative rounded-2xl p-5 border border-white/[0.05] overflow-hidden transition-all duration-500 group-hover:border-gold/35 group-hover:shadow-glow group-hover:-translate-y-1"
              style="background: rgba(10, 10, 10, 0.75); backdrop-filter: blur(20px); box-shadow: inset 0 1px 0 rgba(255,255,255,0.02);"
            >
              <!-- Top border glow gradient -->
              <div class="absolute inset-x-0 top-0 h-[2px] bg-gradient-to-r from-gold/0 via-gold/40 to-gold/0 opacity-60 group-hover:opacity-100 transition-opacity" />

              <!-- Hover background glow -->
              <div class="absolute -bottom-24 -left-24 w-48 h-48 bg-gold/[0.01] group-hover:bg-gold/[0.04] rounded-full blur-3xl transition-all duration-700 group-hover:scale-150 pointer-events-none" />

              <div class="relative flex items-start gap-4">
                <!-- Logo Frame -->
                <div class="shrink-0">
                  <div class="w-16 h-16 rounded-xl overflow-hidden border border-white/5 bg-white/[0.02] transition-all duration-500 group-hover:border-gold/20 group-hover:shadow-glow-sm">
                    <img
                      v-if="orgLogo(org)"
                      :src="orgLogo(org)!"
                      :alt="localizedName(org)"
                      class="w-full h-full object-contain p-2 transition-transform duration-500 group-hover:scale-105"
                    />
                    <div
                      v-else
                      class="w-full h-full bg-gradient-to-br from-gold/20 to-gold/5 flex items-center justify-center transition-transform duration-500 group-hover:scale-105"
                    >
                      <span class="text-2xl font-bold gradient-gold">
                        {{ localizedName(org).charAt(0) || localizedNameEn(org).charAt(0) || '?' }}
                      </span>
                    </div>
                  </div>
                </div>

                <!-- Info Block -->
                <div class="min-w-0 flex-1 pt-0.5">
                  <h3 class="text-base font-bold text-white group-hover:text-gold transition-colors duration-300 line-clamp-2 leading-snug">
                    {{ localizedName(org) }}
                  </h3>
                  <p v-if="localizedNameEn(org) !== localizedName(org)" class="text-[11px] text-gray-500 mt-0.5 line-clamp-1 leading-relaxed">
                    {{ localizedNameEn(org) }}
                  </p>
                  
                  <div class="flex flex-wrap items-center gap-2 mt-3">
                    <!-- Monospace slug badge -->
                    <span class="inline-block px-2 py-0.5 text-[10px] font-mono rounded bg-white/[0.04] text-gray-400 group-hover:bg-gold/10 group-hover:text-gold/90 border border-white/5 group-hover:border-gold/25 transition-all duration-300">
                      /{{ org.org_slug }}
                    </span>
                    <span class="text-[10px] text-gray-700">•</span>
                    <!-- Materials counter -->
                    <span class="inline-flex items-center gap-1 text-[11px] text-gray-500 group-hover:text-gray-400 transition-colors">
                      <svg class="w-3.5 h-3.5 text-gold/40 group-hover:text-gold/60 transition-colors shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                      </svg>
                      {{ $t('hub.orgs_count', { count: org.content_count }) }}
                    </span>
                  </div>
                </div>

                <!-- Navigation Arrow -->
                <div 
                  class="shrink-0 pt-1 opacity-25 group-hover:opacity-100 transition-all duration-300"
                  :class="[
                    locale === 'ar' ? 'translate-x-1 group-hover:-translate-x-0.5' : '-translate-x-1 group-hover:translate-x-0.5'
                  ]"
                >
                  <svg class="w-4 h-4 text-gold" :class="locale === 'ar' ? 'rotate-180' : ''" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
                  </svg>
                </div>
              </div>
            </div>
          </NuxtLink>
        </div>
      </section>
    </main>

    <!-- ===== Footer ===== -->
    <footer class="border-t border-white/5 glass mt-auto">
      <div class="max-w-7xl mx-auto px-4 py-10">
        <div class="flex flex-col md:flex-row items-center justify-between gap-6">
          <div class="flex flex-col items-center md:items-start gap-1">
            <span class="text-lg font-bold gradient-gold">{{ $t('brand.name') }}</span>
            <span class="text-xs text-gray-500">{{ $t('brand.tagline') }}</span>
          </div>
          <div class="flex items-center gap-6">
            <NuxtLink to="/about" class="text-sm text-gray-500 hover:text-gold transition-colors">
              {{ $t('footer.about_platform') }}
            </NuxtLink>
            <NuxtLink to="/terms" class="text-sm text-gray-500 hover:text-gold transition-colors">
              {{ $t('footer.terms') }}
            </NuxtLink>
            <NuxtLink to="/privacy" class="text-sm text-gray-500 hover:text-gold transition-colors">
              {{ $t('footer.privacy') }}
            </NuxtLink>
            <NuxtLink to="/contact" class="text-sm text-gray-500 hover:text-gold transition-colors">
              {{ $t('footer.contact') }}
            </NuxtLink>
          </div>
        </div>
        <div class="border-t border-white/5 mt-6 pt-6 text-center">
          <p class="text-xs text-gray-600">
            &copy; {{ new Date().getFullYear() }} {{ $t('footer.rights') }}
          </p>
        </div>
      </div>
    </footer>
  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

.panel-pop-enter-active {
  transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}
.panel-pop-leave-active {
  transition: all 0.2s cubic-bezier(0.4, 0, 1, 1);
}
.panel-pop-enter-from,
.panel-pop-leave-to {
  opacity: 0;
  transform: translateY(16px) scale(0.94);
}

.cta-glow {
  animation: ctaPulse 3s ease-in-out infinite;
}

@keyframes ctaPulse {
  0%, 100% {
    box-shadow: 0 0 20px rgba(212, 175, 55, 0.3), 0 4px 14px rgba(212, 175, 55, 0.15);
  }
  50% {
    box-shadow: 0 0 40px rgba(212, 175, 55, 0.5), 0 4px 20px rgba(212, 175, 55, 0.25);
  }
}
</style>
