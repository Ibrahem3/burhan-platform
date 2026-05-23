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
const { user, signOut, isAuthenticated } = useUser()
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

    <!-- ===== Backdrop for speed dial ===== -->
    <Transition name="fade">
      <div
        v-if="speedDialOpen"
        class="fixed inset-0 z-40 bg-black/30"
        @click="speedDialOpen = false"
      />
    </Transition>

    <!-- ===== Speed Dial Wrapper ===== -->
    <div
      class="fixed bottom-6 z-50 flex flex-col items-center"
      :class="currentLocale === 'ar' ? 'right-6' : 'left-6'"
    >
      <!-- Speed Dial Items (in reverse order so first item is closest to FAB) -->
      <TransitionGroup name="dial" tag="div" class="flex flex-col items-center gap-3 mb-4">
        <button
          v-for="(item, i) in speedDialItems"
          :key="item.key"
          v-show="speedDialOpen"
          :style="{ transitionDelay: `${(speedDialItems.length - 1 - i) * 0.04}s` }"
          :class="[
            'flex items-center gap-2.5 px-4 py-2.5 glass backdrop-blur-2xl rounded-xl border border-white/10 shadow-lg transition-all duration-200 text-sm whitespace-nowrap',
            item.red
              ? 'text-red-400 hover:bg-red-500/10 hover:border-red-500/30'
              : 'text-gray-300 hover:text-gold hover:bg-gold/10 hover:border-gold/30',
          ]"
          @click="item.action()"
        >
          <span class="w-4 h-4 shrink-0" v-html="item.icon" />
          <span>{{ item.label }}</span>
        </button>
      </TransitionGroup>

      <!-- FAB -->
      <button
        class="w-14 h-14 glass backdrop-blur-md rounded-2xl border border-white/10 shadow-glow-lg hover:shadow-glow transition-all duration-300 flex items-center justify-center"
        :aria-label="$t('common.menu')"
        @click="speedDialOpen = !speedDialOpen"
      >
        <svg
          class="w-6 h-6 text-gold transition-transform duration-300"
          :class="{ 'rotate-90': speedDialOpen }"
          fill="none" viewBox="0 0 24 24" stroke="currentColor"
        >
          <path v-if="!speedDialOpen" stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 6h16M4 12h16M4 18h16" />
          <path v-else stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M6 18L18 6M6 6l12 12" />
        </svg>
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
      <section id="orgs-grid" class="max-w-7xl mx-auto px-4 pb-24">
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
        <div v-else-if="organizations.length === 0" class="text-center py-16">
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
            <GlassCard :hover="true">
              <div class="flex flex-col items-center text-center gap-4">
                <div class="relative">
                  <div class="w-20 h-20 rounded-2xl overflow-hidden shrink-0 transition-all duration-300 group-hover:shadow-glow">
                    <img
                      v-if="orgLogo(org)"
                      :src="orgLogo(org)!"
                      :alt="localizedName(org)"
                      class="w-full h-full object-contain bg-white/5 p-2"
                    />
                    <div
                      v-else
                      class="w-full h-full bg-gradient-to-br from-gold/20 to-gold/5 flex items-center justify-center"
                    >
                      <span class="text-3xl font-bold gradient-gold">
                        {{ localizedName(org).charAt(0) || localizedNameEn(org).charAt(0) || '?' }}
                      </span>
                    </div>
                  </div>
                  <div class="absolute -inset-2 bg-gold/0 group-hover:bg-gold/5 rounded-3xl blur-xl transition-all duration-500 -z-10" />
                </div>
                <div class="space-y-1">
                  <h3 class="text-lg font-semibold text-white group-hover:text-gold transition-colors line-clamp-2">
                    {{ localizedName(org) }}
                  </h3>
                  <p v-if="localizedNameEn(org) !== localizedName(org)" class="text-xs text-gray-500 line-clamp-1">
                    {{ localizedNameEn(org) }}
                  </p>
                </div>
                <div class="flex items-center gap-3">
                  <span class="text-xs text-gray-600 font-mono">/{{ org.org_slug }}</span>
                  <Badge v-if="org.content_count > 0" variant="info" size="sm">
                    {{ $t('hub.orgs_count', { count: org.content_count }) }}
                  </Badge>
                </div>
              </div>
            </GlassCard>
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

.dial-enter-active,
.dial-leave-active {
  transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
}
.dial-enter-from,
.dial-leave-to {
  opacity: 0;
  transform: translateY(12px) scale(0.95);
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
