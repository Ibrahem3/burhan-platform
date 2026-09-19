<script setup lang="ts">
const { org, orgName, orgSlug } = useOrg()
const { user, signOut, isSuperAdmin } = useUser()
const { currentLocale, toggleLocale } = useLocale()
const route = useRoute()

const isHub = computed(() => route.path === '/')
const isObservatory = computed(() => route.path.startsWith('/observatory'))
const isTenant = computed(() => !isObservatory.value && !!route.params.org_slug)

const orgLogoSrc = computed(() => {
  if (!org.value) return null
  const s = org.value.settings as Record<string, any> | null
  return s?.logos?.dark ?? s?.logos?.light ?? null
})

const displayOrgName = computed(() => localizedValue(orgName.value, currentLocale.value))

const menuOpen = ref(false)

function closeMenu() {
  menuOpen.value = false
}
</script>

<template>
  <div class="min-h-screen bg-onyx text-gray-100 flex flex-col">
    <!-- Skip link -->
    <a
      href="#main-content"
      class="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-[100] focus:px-4 focus:py-2 focus:bg-gold focus:text-onyx focus:rounded-xl focus:outline-none"
    >
      {{ $t('layout.skip_to_content') }}
    </a>

    <!-- Sovereign Enterprise Navbar -->
    <header class="sticky top-0 z-50 backdrop-blur-xl bg-onyx/85 border-b border-white/10 shadow-lg shadow-black/40">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 h-16 sm:h-20 flex items-center justify-between gap-4">
        
        <!-- Left / Start: Brand Lockup & Identity -->
        <div class="flex items-center gap-3">
          <NuxtLink to="/" class="group flex items-center gap-3 focus:outline-none" :aria-label="$t('brand.name')">
            <div class="relative w-10 h-10 sm:w-11 sm:h-11 rounded-2xl p-0.5 bg-gradient-to-br from-gold/30 via-white/10 to-transparent border border-white/10 flex items-center justify-center overflow-hidden transition-all duration-300 group-hover:scale-105 group-hover:border-gold/50 shadow-md shadow-black/50">
              <img src="/loader.webp" class="h-8 sm:h-9 w-auto object-contain" alt="برهان" />
            </div>
            <div class="flex flex-col">
              <div class="flex items-center gap-2">
                <span class="text-base sm:text-lg font-black tracking-tight gradient-gold">{{ $t('brand.name') }}</span>
                <span class="text-[10px] font-mono font-semibold px-1.5 py-0.5 rounded-full bg-gold/10 text-gold border border-gold/20 hidden sm:inline-block">v2.0</span>
              </div>
              <span class="text-[10px] text-gray-500 font-medium tracking-wide hidden sm:block">{{ $t('brand.tagline') }}</span>
            </div>
          </NuxtLink>

          <!-- Tenant Context Badge (if visiting inside tenant) -->
          <template v-if="org && isTenant">
            <div class="hidden sm:flex items-center gap-2 ms-2 ps-3 border-s border-white/10">
              <img
                v-if="orgLogoSrc"
                :src="orgLogoSrc"
                :alt="displayOrgName"
                class="h-5 w-auto max-w-[80px] object-contain rounded"
              />
              <NuxtLink
                :to="`/${orgSlug}`"
                class="text-xs font-semibold text-gray-300 hover:text-gold transition-colors truncate max-w-[140px]"
              >
                {{ displayOrgName }}
              </NuxtLink>
            </div>
          </template>
        </div>

        <!-- Center: Desktop Navigation Links -->
        <nav class="hidden md:flex items-center gap-1.5 p-1 rounded-2xl glass bg-white/[0.02] border border-white/5" aria-label="Main Navigation">
          <NuxtLink
            to="/"
            class="px-3.5 py-1.5 text-xs sm:text-sm font-medium rounded-xl transition-all"
            :class="isHub ? 'text-gold bg-gold/10 font-bold border border-gold/20 shadow-sm' : 'text-gray-400 hover:text-white hover:bg-white/5'"
          >
            {{ $t('nav.home') }}
          </NuxtLink>

          <NuxtLink
            to="/observatory"
            class="px-3.5 py-1.5 text-xs sm:text-sm font-medium rounded-xl transition-all"
            :class="isObservatory ? 'text-gold bg-gold/10 font-bold border border-gold/20 shadow-sm' : 'text-gray-400 hover:text-white hover:bg-white/5'"
          >
            {{ $t('observatory.nav') }}
          </NuxtLink>

          <NuxtLink
            to="/about"
            class="px-3.5 py-1.5 text-xs sm:text-sm font-medium text-gray-400 hover:text-white rounded-xl hover:bg-white/5 transition-all"
          >
            {{ $t('footer.about_platform') }}
          </NuxtLink>
        </nav>

        <!-- Right / End: Language Switcher + Auth CTAs + Mobile Hamburger -->
        <div class="flex items-center gap-2 sm:gap-3">
          <!-- Locale Switcher Pill -->
          <button
            class="inline-flex items-center gap-1.5 px-2.5 sm:px-3 py-1.5 text-xs font-medium text-gray-300 hover:text-gold rounded-xl glass bg-white/[0.03] hover:bg-white/[0.08] border border-white/10 transition-all"
            :aria-label="$t('locale.switch_to_en')"
            :title="$t(currentLocale === 'ar' ? 'locale.switch_to_en' : 'locale.switch_to_ar')"
            @click="toggleLocale()"
          >
            <svg class="w-3.5 h-3.5 text-gold shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m0 4h.01M21 12l-4 4m0 0l-4-4m4 4V8" />
            </svg>
            <span class="font-mono uppercase">{{ currentLocale === 'ar' ? 'EN' : 'عربي' }}</span>
          </button>

          <!-- Auth Actions (Desktop) -->
          <div class="hidden sm:flex items-center gap-2">
            <template v-if="user">
              <NuxtLink v-if="isSuperAdmin" to="/admin/dashboard">
                <Button variant="ghost" size="sm" class="text-xs h-9">{{ $t('nav.admin') }}</Button>
              </NuxtLink>
              <NuxtLink to="/dashboard">
                <Button variant="outline" size="sm" class="text-xs h-9 border-white/15 hover:border-gold/40">
                  {{ $t('nav.dashboard') }}
                </Button>
              </NuxtLink>
              <Button variant="ghost" size="sm" class="text-xs text-red-400 hover:text-red-300 h-9" @click="signOut()">
                {{ $t('nav.logout') }}
              </Button>
            </template>
            <template v-else>
              <NuxtLink to="/login">
                <Button variant="ghost" size="sm" class="text-xs h-9">{{ $t('nav.login') }}</Button>
              </NuxtLink>
              <NuxtLink to="/signup">
                <Button size="sm" class="text-xs h-9 font-bold shadow-lg shadow-gold/20 bg-gold hover:bg-gold-500 text-onyx">
                  {{ $t('nav.signup') }}
                </Button>
              </NuxtLink>
            </template>
          </div>

          <!-- Mobile Hamburger Toggle -->
          <button
            class="md:hidden p-2 text-gray-400 hover:text-white transition-colors rounded-xl bg-white/[0.03] border border-white/10"
            :aria-label="menuOpen ? $t('layout.close_menu') : $t('layout.menu_toggle')"
            :aria-expanded="menuOpen"
            @click="menuOpen = !menuOpen"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path
                v-if="!menuOpen"
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 6h16M4 12h16M4 18h16"
              />
              <path
                v-else
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>
      </div>

      <!-- Mobile: Dropdown Menu with Glassmorphic Style -->
      <Transition name="slide-down">
        <div
          v-if="menuOpen"
          class="md:hidden border-t border-white/10 glass bg-onyx/95 backdrop-blur-2xl"
        >
          <nav class="px-4 py-4 space-y-2" aria-label="Mobile navigation">
            <NuxtLink
              to="/"
              class="flex items-center justify-between px-3.5 py-2.5 text-sm font-medium rounded-xl transition-all"
              :class="isHub ? 'text-gold bg-gold/10 font-bold border border-gold/20' : 'text-gray-300 hover:text-white hover:bg-white/5'"
              @click="closeMenu"
            >
              <span>{{ $t('nav.home') }}</span>
              <span v-if="isHub" class="w-1.5 h-1.5 rounded-full bg-gold" />
            </NuxtLink>

            <NuxtLink
              to="/observatory"
              class="flex items-center justify-between px-3.5 py-2.5 text-sm font-medium rounded-xl transition-all"
              :class="isObservatory ? 'text-gold bg-gold/10 font-bold border border-gold/20' : 'text-gray-300 hover:text-white hover:bg-white/5'"
              @click="closeMenu"
            >
              <span>{{ $t('observatory.nav') }}</span>
              <span v-if="isObservatory" class="w-1.5 h-1.5 rounded-full bg-gold" />
            </NuxtLink>

            <NuxtLink
              to="/about"
              class="block px-3.5 py-2.5 text-sm font-medium text-gray-300 hover:text-white rounded-xl hover:bg-white/5 transition-all"
              @click="closeMenu"
            >
              {{ $t('footer.about_platform') }}
            </NuxtLink>

            <div v-if="org && isTenant" class="p-3 rounded-xl bg-white/[0.02] border border-white/5 flex items-center gap-2">
              <img
                v-if="orgLogoSrc"
                :src="orgLogoSrc"
                :alt="displayOrgName"
                class="h-6 w-auto max-w-[80px] object-contain rounded"
              />
              <NuxtLink
                :to="`/${orgSlug}`"
                class="text-xs font-semibold text-gray-300 hover:text-gold truncate"
                @click="closeMenu"
              >
                {{ displayOrgName }}
              </NuxtLink>
            </div>

            <hr class="border-white/10 my-2" />

            <template v-if="user">
              <NuxtLink
                v-if="isSuperAdmin"
                to="/admin/dashboard"
                class="block px-3.5 py-2.5 text-sm text-gray-300 hover:text-white rounded-xl hover:bg-white/5 transition-colors"
                @click="closeMenu"
              >
                {{ $t('nav.admin') }}
              </NuxtLink>
              <NuxtLink
                to="/dashboard"
                class="block px-3.5 py-2.5 text-sm font-bold text-gold hover:text-white rounded-xl bg-gold/5 border border-gold/20 transition-colors"
                @click="closeMenu"
              >
                {{ $t('nav.dashboard') }}
              </NuxtLink>
              <button
                class="block w-full px-3.5 py-2.5 text-sm text-red-400 hover:text-red-300 rounded-xl hover:bg-red-500/10 transition-colors"
                :class="currentLocale === 'ar' ? 'text-right' : 'text-left'"
                @click="signOut(); closeMenu()"
              >
                {{ $t('nav.logout') }}
              </button>
            </template>
            <template v-else>
              <div class="grid grid-cols-2 gap-2 pt-1">
                <NuxtLink
                  to="/login"
                  class="flex items-center justify-center px-4 py-2.5 text-sm font-medium text-gray-300 hover:text-white rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 transition-all"
                  @click="closeMenu"
                >
                  {{ $t('auth.login_btn') }}
                </NuxtLink>
                <NuxtLink
                  to="/signup"
                  class="flex items-center justify-center px-4 py-2.5 text-sm font-bold text-onyx bg-gold hover:bg-gold-500 rounded-xl shadow-lg shadow-gold/20 transition-all"
                  @click="closeMenu"
                >
                  {{ $t('nav.signup') }}
                </NuxtLink>
              </div>
            </template>
          </nav>
        </div>
      </Transition>
    </header>

    <!-- Main content -->
    <main id="main-content" class="flex-1">
      <slot />
    </main>

    <!-- Sovereign Enterprise 4-Column Footer -->
    <footer class="border-t border-white/10 glass bg-gradient-to-b from-onyx/80 via-[#0B0B0B] to-[#070707] mt-auto">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 py-12 sm:py-16">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-12 gap-10 lg:gap-8 pb-12">
          <!-- Column 1: Brand & Operational Status (5 cols) -->
          <div class="lg:col-span-5 space-y-4">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-2xl p-0.5 bg-gradient-to-br from-gold/30 via-white/10 to-transparent border border-white/10 flex items-center justify-center overflow-hidden shadow-md">
                <img src="/loader.webp" class="h-8 w-auto object-contain" alt="برهان" />
              </div>
              <div>
                <span class="text-lg font-black tracking-tight gradient-gold">{{ $t('brand.name') }}</span>
                <p class="text-xs text-gray-500">{{ $t('brand.tagline') }}</p>
              </div>
            </div>

            <p class="text-xs text-gray-400 leading-relaxed max-w-sm">
              {{ $t('footer.description') }}
            </p>

            <!-- Live Status Capsule -->
            <div class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/[0.03] border border-white/10 text-xs text-gray-400">
              <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
              <span class="text-[11px] font-mono">{{ currentLocale === 'ar' ? 'الأنظمة تعمل بكفاءة' : 'All Systems Operational' }}</span>
            </div>
          </div>

          <!-- Column 2: Platform Links (2 cols) -->
          <div class="lg:col-span-2 space-y-3">
            <p class="text-xs font-bold text-white uppercase tracking-wider">
              {{ currentLocale === 'ar' ? 'المنصة' : 'Platform' }}
            </p>
            <ul class="space-y-2.5 text-xs text-gray-400">
              <li>
                <NuxtLink to="/" class="hover:text-gold transition-colors">
                  {{ $t('nav.home') }}
                </NuxtLink>
              </li>
              <li>
                <NuxtLink to="/observatory" class="hover:text-gold transition-colors">
                  {{ $t('observatory.nav') }}
                </NuxtLink>
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
            <div class="pt-2">
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
.slide-down-enter-active,
.slide-down-leave-active {
  transition: all 0.25s ease;
  overflow: hidden;
}

.slide-down-enter-from,
.slide-down-leave-to {
  max-height: 0;
  opacity: 0;
}

.slide-down-enter-to,
.slide-down-leave-from {
  max-height: 500px;
  opacity: 1;
}
</style>
