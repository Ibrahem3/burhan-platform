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
  pageTransition: false,
})

const { t, locale } = useI18n()
const { currentLocale, toggleLocale } = useLocale()
const { user, profile, signOut, isAuthenticated } = useUser()
const currentLocaleVal = computed(() => locale.value as 'ar' | 'en')

const { data: organizations, pending, error } = useFetch<OrgWithCount[]>('/api/orgs', {
  transform: (data) => data ?? [],
})

const totalPublicContent = computed(() => {
  return organizations.value?.reduce((sum, o) => sum + (o.content_count || 0), 0) || 0
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

function orgTagline(org: OrgWithCount): string {
  if (!org.settings) return ''
  const s = typeof org.settings === 'string' ? JSON.parse(org.settings) : org.settings
  return localizedValue(s?.description, currentLocaleVal.value) || ''
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

            <!-- Ainux Tools Ecosystem Link -->
            <a
              href="https://tools.ainux.online/"
              target="_blank"
              rel="noopener noreferrer"
              class="w-full flex items-center gap-2.5 sm:gap-3 px-2.5 sm:px-3 py-1.5 sm:py-2 rounded-lg sm:rounded-xl text-[11px] sm:text-xs font-medium text-gray-300 hover:text-gold hover:bg-gold/5 transition-all text-start group"
              @click="speedDialOpen = false"
            >
              <div class="w-6 h-6 sm:w-7 sm:h-7 rounded-md sm:rounded-lg bg-gold/10 flex items-center justify-center text-gold text-xs">
                🛠️
              </div>
              <span class="flex-1">{{ currentLocale === 'ar' ? 'أدوات آينوكس' : 'Ainux Tools' }}</span>
              <span class="text-[9px] sm:text-[10px] text-gold bg-gold/10 border border-gold/20 px-1.5 py-0.2 rounded-full font-mono">57</span>
            </a>

            <!-- GitHub Repo Link -->
            <a
              href="https://github.com/Ibrahem3/burhan-platform"
              target="_blank"
              rel="noopener noreferrer"
              class="w-full flex items-center gap-2.5 sm:gap-3 px-2.5 sm:px-3 py-1.5 sm:py-2 rounded-lg sm:rounded-xl text-[11px] sm:text-xs font-medium text-gray-300 hover:text-white hover:bg-white/5 transition-all text-start group"
              @click="speedDialOpen = false"
            >
              <div class="w-6 h-6 sm:w-7 sm:h-7 rounded-md sm:rounded-lg bg-white/5 flex items-center justify-center text-gray-400 group-hover:text-white transition-colors">
                <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
                  <path fill-rule="evenodd" clip-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" />
                </svg>
              </div>
              <span class="flex-1">GitHub Repo</span>
              <span class="text-[9px] sm:text-[10px] text-gray-500 font-mono">Open</span>
            </a>
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
      <section id="hub-hero" class="relative overflow-hidden py-24 md:py-32 lg:py-40">
        <!-- Ambient Mesh Gradients & Dot Matrix Background -->
        <div class="absolute top-1/4 -left-40 w-[600px] h-[600px] bg-gold/10 rounded-full blur-[128px] pointer-events-none" />
        <div class="absolute top-1/3 -right-40 w-[500px] h-[500px] bg-gold/5 rounded-full blur-[128px] pointer-events-none" />
        <div class="absolute bottom-10 left-1/2 -translate-x-1/2 w-[800px] h-[350px] bg-gradient-to-t from-gold/10 via-transparent to-transparent blur-3xl pointer-events-none" />
        
        <!-- Architectural Tech Grid Pattern with Radial Fade -->
        <div class="absolute inset-0 bg-[linear-gradient(to_right,#ffffff05_1px,transparent_1px),linear-gradient(to_bottom,#ffffff05_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_40%,#000_70%,transparent_100%)] pointer-events-none" />

        <div class="relative z-10 text-center max-w-5xl mx-auto px-4">
          <!-- Top Announcement Capsule -->
          <div class="inline-flex items-center gap-2.5 px-4 py-1.5 rounded-full glass bg-white/[0.03] border border-white/10 hover:border-gold/30 shadow-lg shadow-black/40 mb-8 transition-all duration-300">
            <span class="flex h-2 w-2 relative">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
              <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
            </span>
            <span class="text-xs text-gray-300 font-medium">
              {{ currentLocale === 'ar' ? 'المنظومة السيادية للردود والحوارات الفكرية' : 'Sovereign Multi-Tenant Knowledge Architecture' }}
            </span>
            <span class="text-gray-600">•</span>
            <span class="text-[11px] font-mono text-gold bg-gold/10 px-2 py-0.5 rounded-md border border-gold/20">
              v2.0
            </span>
          </div>

          <!-- Main Title with Deep Gold Gradient -->
          <h1 class="text-6xl sm:text-7xl md:text-8xl lg:text-9xl font-extrabold mb-6 tracking-tight leading-none select-none">
            <span class="gradient-gold drop-shadow-2xl">{{ $t('hub.title') }}</span>
          </h1>

          <!-- Tagline Subtitle -->
          <p class="text-xl sm:text-2xl md:text-3xl font-bold text-white mb-6 max-w-3xl mx-auto leading-snug">
            {{ $t('hub.subtitle') }}
          </p>

          <!-- Description Text -->
          <p class="text-sm sm:text-base md:text-lg text-gray-400 mb-10 max-w-2xl mx-auto leading-relaxed">
            {{ $t('hub.hero_description') }}
          </p>

          <!-- Action Buttons -->
          <div class="flex flex-wrap items-center justify-center gap-3 sm:gap-4 mb-10">
            <button
              class="cta-glow inline-flex items-center justify-center gap-2.5 font-semibold transition-all duration-300 rounded-2xl px-7 py-3.5 sm:px-8 sm:py-4 text-base md:text-lg bg-gold text-onyx hover:bg-gold-500 active:bg-gold-600 shadow-xl shadow-gold/25 group cursor-pointer"
              @click="scrollToSection('orgs-grid')"
            >
              <svg class="w-5 h-5 transition-transform duration-300 group-hover:rotate-45" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
              </svg>
              <span>{{ $t('hub.browse_orgs') }}</span>
            </button>

            <NuxtLink
              to="/signup"
              class="inline-flex items-center justify-center gap-2 font-semibold transition-all duration-300 rounded-2xl px-6 py-3.5 sm:px-7 sm:py-4 text-base md:text-lg glass bg-white/[0.04] hover:bg-white/[0.08] text-white border border-white/10 hover:border-gold/40 shadow-xl group"
            >
              <span>{{ currentLocale === 'ar' ? 'أنشئ منظمتك الخاصة' : 'Launch Your Organization' }}</span>
              <span class="transition-transform duration-300 group-hover:translate-x-1" :class="currentLocale === 'ar' ? 'group-hover:-translate-x-1' : ''">
                {{ currentLocale === 'ar' ? '←' : '→' }}
              </span>
            </NuxtLink>

            <!-- GitHub Repository Button -->
            <a
              href="https://github.com/Ibrahem3/burhan-platform"
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center justify-center gap-2.5 font-semibold transition-all duration-300 rounded-2xl px-5 py-3.5 sm:py-4 text-sm sm:text-base glass bg-white/[0.03] hover:bg-white/[0.08] text-gray-200 hover:text-white border border-white/10 hover:border-gold/40 shadow-xl group"
              title="GitHub Open Source Repository"
            >
              <svg class="w-5 h-5 text-gray-300 group-hover:text-gold transition-colors" fill="currentColor" viewBox="0 0 24 24">
                <path fill-rule="evenodd" clip-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" />
              </svg>
              <span>GitHub</span>
              <span class="text-[10px] font-mono text-gold bg-gold/10 px-2 py-0.5 rounded border border-gold/20">Open Source</span>
            </a>
          </div>

          <!-- Ainux Client-Side Tools Interactive Banner -->
          <div class="mb-12 max-w-2xl mx-auto">
            <a
              href="https://tools.ainux.online/"
              target="_blank"
              rel="noopener noreferrer"
              class="group relative block p-3 sm:p-4 rounded-2xl glass bg-gradient-to-r from-gold/[0.06] via-white/[0.02] to-gold/[0.06] border border-white/10 hover:border-gold/40 shadow-xl shadow-black/50 transition-all duration-300 hover:scale-[1.01]"
            >
              <div class="flex items-center justify-between gap-3 text-start">
                <div class="flex items-center gap-3">
                  <div class="w-10 h-10 rounded-xl bg-gold/10 border border-gold/20 flex items-center justify-center shrink-0 text-gold text-lg group-hover:rotate-12 transition-transform duration-300">
                    🛠️
                  </div>
                  <div>
                    <div class="flex items-center gap-2">
                      <span class="text-xs sm:text-sm font-bold text-white group-hover:text-gold transition-colors">
                        {{ currentLocale === 'ar' ? 'منظومة أدوات آينوكس المجانية' : 'Ainux Client-Side Tools Hub' }}
                      </span>
                      <span class="text-[10px] font-mono font-bold px-1.5 py-0.5 rounded bg-gold/20 text-gold border border-gold/30">
                        57 Tools
                      </span>
                    </div>
                    <p class="text-[11px] text-gray-400 mt-0.5">
                      {{ currentLocale === 'ar'
                        ? 'تعديل PDF، إزالة الخلفيات، وتحويل الوسائط.. تعمل 100% داخل متصفحك بدون خوادم وبأعلى خصوصية'
                        : 'PDF editing, background removal, media converters.. 100% client-side zero-server privacy'
                      }}
                    </p>
                  </div>
                </div>

                <div class="shrink-0 hidden sm:flex items-center text-xs font-bold text-gold gap-1 group-hover:translate-x-1 rtl:group-hover:-translate-x-1 transition-transform">
                  <span>{{ currentLocale === 'ar' ? 'تصفح الأدوات' : 'Open Tools' }}</span>
                  <span>{{ currentLocale === 'ar' ? '←' : '→' }}</span>
                </div>
              </div>
            </a>
          </div>

          <!-- Live Metrics & Trust Ribbon -->
          <div class="grid grid-cols-2 md:grid-cols-4 gap-3 max-w-4xl mx-auto pt-8 border-t border-white/5">
            <div class="glass backdrop-blur-md bg-white/[0.02] border border-white/5 rounded-2xl p-4 text-center">
              <p class="text-xl sm:text-2xl font-bold gradient-gold">{{ organizations?.length || 0 }}</p>
              <p class="text-xs text-gray-400 mt-1">{{ currentLocale === 'ar' ? 'منظمات نشطة' : 'Active Tenants' }}</p>
            </div>
            <div class="glass backdrop-blur-md bg-white/[0.02] border border-white/5 rounded-2xl p-4 text-center">
              <p class="text-xl sm:text-2xl font-bold text-white">{{ totalPublicContent }}</p>
              <p class="text-xs text-gray-400 mt-1">{{ currentLocale === 'ar' ? 'مادة ومرجع موثق' : 'Published Entries' }}</p>
            </div>
            <div class="glass backdrop-blur-md bg-white/[0.02] border border-white/5 rounded-2xl p-4 text-center">
              <p class="text-xl sm:text-2xl font-bold gradient-gold">100%</p>
              <p class="text-xs text-gray-400 mt-1">{{ currentLocale === 'ar' ? 'عزل بيانات سيادي' : 'Isolated Multi-Tenancy' }}</p>
            </div>
            <div class="glass backdrop-blur-md bg-white/[0.02] border border-white/5 rounded-2xl p-4 text-center">
              <p class="text-xl sm:text-2xl font-bold text-emerald-400">DeAI</p>
              <p class="text-xs text-gray-400 mt-1">{{ currentLocale === 'ar' ? 'ذكاء اصطناعي مشفر' : 'Encrypted BYOK AI' }}</p>
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
        <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-7">
          <NuxtLink
            v-for="org in organizations"
            :key="org.id"
            :to="`/${org.org_slug}`"
            class="group block focus:outline-none focus-visible:ring-2 focus-visible:ring-gold/50 rounded-3xl"
          >
            <div
              class="relative rounded-3xl border border-white/[0.08] overflow-hidden transition-all duration-500 group-hover:border-gold/40 group-hover:shadow-glow group-hover:-translate-y-1.5 flex flex-col h-full"
              style="background: rgba(14, 14, 14, 0.85); backdrop-filter: blur(24px); box-shadow: inset 0 1px 0 rgba(255,255,255,0.05);"
            >
              <!-- Card Top Header Banner -->
              <div class="relative h-24 sm:h-28 overflow-hidden bg-gradient-to-br from-gold/15 via-gold/5 to-transparent border-b border-white/5">
                <!-- Decorative Geometric Pattern -->
                <div class="absolute inset-0 opacity-15 bg-[radial-gradient(#d4af37_1px,transparent_1px)] [background-size:12px_12px]" />
                <div class="absolute top-0 right-0 w-36 h-36 bg-gold/10 rounded-full blur-2xl group-hover:bg-gold/20 transition-all duration-700 pointer-events-none" />
                
                <!-- Status / Material Badge in Top Corner -->
                <div class="absolute top-3.5" :class="currentLocale === 'ar' ? 'left-3.5' : 'right-3.5'">
                  <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-onyx/80 backdrop-blur-md border border-white/10 text-[11px] text-gray-300 shadow-sm">
                    <span class="w-1.5 h-1.5 rounded-full bg-gold animate-pulse" />
                    <span>{{ $t('hub.orgs_count', { count: org.content_count }) }}</span>
                  </div>
                </div>

                <!-- Slug Watermark -->
                <div class="absolute bottom-2 font-mono text-[10px] text-gray-600/60 uppercase tracking-widest pointer-events-none" :class="currentLocale === 'ar' ? 'left-4' : 'right-4'">
                  /{{ org.org_slug }}
                </div>
              </div>

              <!-- Main Card Body with Overlapping Avatar -->
              <div class="relative px-5 pt-0 pb-5 flex-1 flex flex-col">
                <!-- Floating Avatar Overlap -->
                <div class="-mt-10 mb-3 flex items-end justify-between">
                  <div class="relative w-16 h-16 sm:w-18 sm:h-18 rounded-2xl p-1 bg-onyx border-2 border-white/10 group-hover:border-gold/50 shadow-2xl transition-all duration-500 group-hover:scale-105 group-hover:shadow-glow-sm">
                    <div class="w-full h-full rounded-xl overflow-hidden bg-white/[0.03] flex items-center justify-center">
                      <img
                        v-if="orgLogo(org)"
                        :src="orgLogo(org)!"
                        :alt="localizedName(org)"
                        class="w-full h-full object-contain p-1.5 transition-transform duration-500 group-hover:scale-110"
                      />
                      <div
                        v-else
                        class="w-full h-full bg-gradient-to-br from-gold/25 via-gold/10 to-transparent flex items-center justify-center"
                      >
                        <span class="text-2xl font-bold gradient-gold">
                          {{ localizedName(org).charAt(0) || localizedNameEn(org).charAt(0) || '?' }}
                        </span>
                      </div>
                    </div>
                  </div>

                  <!-- Quick Action Indicator -->
                  <div class="w-8 h-8 rounded-xl bg-white/5 border border-white/5 flex items-center justify-center text-gray-400 group-hover:text-gold group-hover:bg-gold/10 group-hover:border-gold/20 transition-all duration-300">
                    <svg class="w-4 h-4 transition-transform duration-300 group-hover:scale-110" :class="currentLocale === 'ar' ? 'rotate-180 group-hover:-translate-x-0.5' : 'group-hover:translate-x-0.5'" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
                    </svg>
                  </div>
                </div>

                <!-- Titles and Identity -->
                <div class="space-y-1 mb-3">
                  <h3 class="text-base sm:text-lg font-bold text-white group-hover:text-gold transition-colors duration-300 line-clamp-1 leading-snug">
                    {{ localizedName(org) }}
                  </h3>
                  <p v-if="localizedNameEn(org) !== localizedName(org)" class="text-xs text-gray-500 line-clamp-1">
                    {{ localizedNameEn(org) }}
                  </p>
                </div>

                <!-- Tagline / Bio (if available) or Default Overview -->
                <p class="text-xs text-gray-400 line-clamp-2 leading-relaxed flex-1 mb-4">
                  {{ orgTagline(org) || $t('hub.hero_description') }}
                </p>

                <!-- Footer Meta: Verified Badge + Explore CTA -->
                <div class="pt-3 border-t border-white/5 flex items-center justify-between text-xs text-gray-400">
                  <div class="flex items-center gap-1.5 text-gray-400 font-mono text-[11px]">
                    <span class="w-1.5 h-1.5 rounded-full bg-emerald-400/80" />
                    <span>{{ currentLocale === 'ar' ? 'منصة معتمدة' : 'Verified' }}</span>
                  </div>

                  <span class="inline-flex items-center gap-1 font-semibold text-gold group-hover:text-gold-300 transition-colors text-[11px]">
                    <span>{{ currentLocale === 'ar' ? 'دخول المنظمة' : 'Visit Hub' }}</span>
                    <span>{{ currentLocale === 'ar' ? '←' : '→' }}</span>
                  </span>
                </div>
              </div>
            </div>
          </NuxtLink>
        </div>
      </section>
    </main>

    <!-- ===== Pre-Footer Enterprise CTA Strip ===== -->
    <section class="max-w-7xl mx-auto px-4 pb-16">
      <div class="relative rounded-3xl overflow-hidden glass border border-white/10 p-8 sm:p-12 shadow-2xl bg-gradient-to-r from-gold/10 via-white/[0.02] to-gold/5">
        <div class="absolute -top-24 -right-24 w-64 h-64 bg-gold/15 rounded-full blur-3xl pointer-events-none" />
        <div class="absolute -bottom-24 -left-24 w-64 h-64 bg-gold/10 rounded-full blur-3xl pointer-events-none" />

        <div class="relative z-10 flex flex-col lg:flex-row items-center justify-between gap-8 text-center lg:text-start">
          <div class="space-y-3 max-w-2xl">
            <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-gold/10 border border-gold/20 text-xs text-gold font-medium">
              <span>✦</span>
              <span>{{ currentLocale === 'ar' ? 'للمؤسسات والمراكز الفكرية' : 'For Institutions & Intellectual Centers' }}</span>
            </div>
            <h2 class="text-2xl sm:text-3xl lg:text-4xl font-extrabold text-white tracking-tight">
              {{ currentLocale === 'ar' ? 'هل تدير منظومة معرفية أو فكرية؟' : 'Managing a Knowledge or Research Entity?' }}
            </h2>
            <p class="text-sm sm:text-base text-gray-400 leading-relaxed">
              {{ currentLocale === 'ar' 
                ? 'انضم إلى شبكة برهان وأسّس مساحتك الرقمية المستقلة بأعلى معايير العزل والأمان والذكاء الاصطناعي السيادي.' 
                : 'Join Burhan network to establish your independent digital hub backed by sovereign tenant isolation, BYOK encryption, and modern learning series.' 
              }}
            </p>
          </div>

          <div class="flex flex-wrap items-center justify-center gap-4 shrink-0">
            <NuxtLink
              to="/signup"
              class="cta-glow inline-flex items-center gap-2.5 font-bold transition-all duration-300 rounded-2xl px-8 py-4 text-base bg-gold text-onyx hover:bg-gold-500 active:bg-gold-600 shadow-xl shadow-gold/20"
            >
              <span>{{ currentLocale === 'ar' ? 'ابدأ تأسيس منظمتك الآن' : 'Launch Your Platform' }}</span>
              <span>{{ currentLocale === 'ar' ? '←' : '→' }}</span>
            </NuxtLink>
            <NuxtLink
              to="/about"
              class="inline-flex items-center gap-2 font-medium transition-all duration-300 rounded-2xl px-6 py-4 text-base glass bg-white/5 hover:bg-white/10 text-white border border-white/10 hover:border-gold/30"
            >
              {{ $t('footer.about_platform') }}
            </NuxtLink>
          </div>
        </div>
      </div>
    </section>

    <!-- ===== Sovereign Foundation Footer ===== -->
    <footer class="border-t border-white/5 glass bg-onyx/80 backdrop-blur-2xl mt-auto">
      <div class="max-w-7xl mx-auto px-4 pt-16 pb-12">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-12 gap-10 lg:gap-8 mb-14">
          <!-- Column 1: Brand & Mission (5 cols) -->
          <div class="lg:col-span-5 space-y-4">
            <div class="flex items-center gap-3">
              <span class="text-2xl font-black tracking-tight gradient-gold">{{ $t('brand.name') }}</span>
              <span class="text-[10px] font-mono uppercase px-2 py-0.5 rounded bg-gold/10 text-gold border border-gold/20">
                v2.0 Sovereign
              </span>
            </div>

            <p class="text-xs text-gray-400 leading-relaxed max-w-sm">
              {{ $t('hub.hero_description') }}
            </p>

            <!-- System Live Status Indicator -->
            <div class="pt-2 flex items-center gap-2.5">
              <span class="flex h-2 w-2 relative">
                <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
              </span>
              <span class="text-xs font-mono text-gray-400">
                {{ currentLocale === 'ar' ? 'جميع أنظمة برهان تعمل بكفاءة' : 'All Systems Operational' }}
              </span>
            </div>
          </div>

          <!-- Column 2: Platform Links (2 cols) -->
          <div class="lg:col-span-2 space-y-3">
            <p class="text-xs font-bold text-white uppercase tracking-wider">
              {{ currentLocale === 'ar' ? 'المنظومة' : 'Platform' }}
            </p>
            <ul class="space-y-2.5 text-xs text-gray-400">
              <li>
                <button class="hover:text-gold transition-colors text-start" @click="scrollToSection('orgs-grid')">
                  {{ $t('hub.orgs_title') }}
                </button>
              </li>
              <li>
                <NuxtLink to="/signup" class="hover:text-gold transition-colors">
                  {{ currentLocale === 'ar' ? 'تسجيل منظمة' : 'Register Tenant' }}
                </NuxtLink>
              </li>
              <li>
                <NuxtLink to="/dashboard" class="hover:text-gold transition-colors">
                  {{ $t('nav.dashboard') }}
                </NuxtLink>
              </li>
            </ul>
          </div>

          <!-- Column 3: Trust & Governance (2 cols) -->
          <div class="lg:col-span-2 space-y-3">
            <p class="text-xs font-bold text-white uppercase tracking-wider">
              {{ currentLocale === 'ar' ? 'الحوكمة والميثاق' : 'Governance' }}
            </p>
            <ul class="space-y-2.5 text-xs text-gray-400">
              <li>
                <NuxtLink to="/about" class="hover:text-gold transition-colors">
                  {{ $t('footer.about_platform') }}
                </NuxtLink>
              </li>
              <li>
                <NuxtLink to="/terms" class="hover:text-gold transition-colors">
                  {{ $t('footer.terms') }}
                </NuxtLink>
              </li>
              <li>
                <NuxtLink to="/privacy" class="hover:text-gold transition-colors">
                  {{ $t('footer.privacy') }}
                </NuxtLink>
              </li>
            </ul>
          </div>

          <!-- Column 4: Contact & Locale (3 cols) -->
          <div class="lg:col-span-3 space-y-3">
            <p class="text-xs font-bold text-white uppercase tracking-wider">
              {{ currentLocale === 'ar' ? 'التواصل واللغة' : 'Connect' }}
            </p>
            <ul class="space-y-2.5 text-xs text-gray-400">
              <li>
                <NuxtLink to="/contact" class="hover:text-gold transition-colors">
                  {{ $t('footer.contact') }}
                </NuxtLink>
              </li>
              <li>
                <a href="https://tools.ainux.online/" target="_blank" rel="noopener noreferrer" class="hover:text-gold transition-colors inline-flex items-center gap-1.5 text-gray-300 group">
                  <span class="text-gold">🛠️</span>
                  <span class="group-hover:underline">{{ currentLocale === 'ar' ? 'أدوات آينوكس (57 أداة مجانية)' : 'Ainux Tools (57 Tools)' }}</span>
                  <span class="text-[10px] text-gold font-mono">↗</span>
                </a>
              </li>
              <li>
                <a href="https://github.com/Ibrahem3/burhan-platform" target="_blank" rel="noopener noreferrer" class="hover:text-gold transition-colors inline-flex items-center gap-1.5 text-gray-400 group">
                  <svg class="w-3.5 h-3.5 fill-currentColor" viewBox="0 0 24 24">
                    <path fill-rule="evenodd" clip-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" />
                  </svg>
                  <span class="group-hover:underline">GitHub Repository</span>
                  <span class="text-[10px] text-gray-500 font-mono">↗</span>
                </a>
              </li>
            </ul>

            <!-- Inline Language Selector Pill -->
            <div class="pt-3">
              <button
                class="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl glass bg-white/5 hover:bg-white/10 border border-white/10 text-xs text-gray-300 hover:text-gold transition-all"
                @click="toggleLocale()"
              >
                <svg class="w-3.5 h-3.5 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m0 4h.01M21 12l-4 4m0 0l-4-4m4 4V8" />
                </svg>
                <span>{{ currentLocale === 'ar' ? 'English' : 'العربية' }}</span>
              </button>
            </div>
          </div>
        </div>

        <!-- Sub-Footer Bottom Bar (Centered) -->
        <div class="border-t border-white/5 pt-8 flex flex-col items-center justify-center text-center gap-2.5">
          <div class="flex flex-wrap items-center justify-center gap-2 text-xs text-gray-400">
            <span>&copy; {{ new Date().getFullYear() }} {{ $t('footer.rights') }}</span>
            <span class="text-gray-600">•</span>
            <span class="inline-flex items-center gap-1.5" dir="ltr">
              <span class="text-gray-500">Powered by</span>
              <a
                href="https://ainux.online"
                target="_blank"
                rel="noopener noreferrer"
                class="text-gold font-bold hover:underline transition-colors"
              >Ainux</a>
            </span>
          </div>
          <p class="text-[11px] font-mono text-gray-600 text-center">
            Engineered for Sovereign Knowledge & Multi-Tenant Integrity
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
