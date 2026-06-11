<script setup lang="ts">
const { org, orgName, orgSlug } = useOrg()
const { user, signOut, isSuperAdmin } = useUser()
const { currentLocale, toggleLocale } = useLocale()
const route = useRoute()

const isHub = computed(() => route.path === '/')
const isTenant = computed(() => !!route.params.org_slug)

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

    <!-- Navbar -->
    <header class="sticky top-0 z-50 glass border-b border-white/5">
      <div class="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
        <!-- Desktop start-side buttons (always order-1; dir handles RTL/LTR) -->
        <div class="hidden md:flex items-center gap-2 flex-[3] order-1">
          <NuxtLink
            to="/"
            class="px-3 py-2 text-sm text-gray-400 hover:text-white transition-colors rounded-lg hover:bg-white/5"
            :class="{ 'text-gold': isHub }"
          >
            {{ $t('nav.home') }}
          </NuxtLink>

          <NuxtLink
            to="/observatory"
            class="px-3 py-2 text-sm text-gray-400 hover:text-white transition-colors rounded-lg hover:bg-white/5"
          >
            {{ $t('observatory.nav') }}
          </NuxtLink>

          <button
            class="px-2 py-1.5 text-xs font-medium text-gray-400 hover:text-gold transition-colors rounded-lg hover:bg-white/5 tracking-wider"
            :aria-label="$t('locale.switch_to_en')"
            :title="$t(currentLocale === 'ar' ? 'locale.switch_to_en' : 'locale.switch_to_ar')"
            @click="toggleLocale()"
          >
            {{ currentLocale === 'ar' ? 'EN' : 'AR' }}
          </button>

          <template v-if="user">
            <NuxtLink v-if="isSuperAdmin" to="/admin/dashboard">
              <Button variant="ghost" size="sm">{{ $t('nav.admin') }}</Button>
            </NuxtLink>
            <NuxtLink to="/dashboard">
              <Button variant="ghost" size="sm">{{ $t('nav.dashboard') }}</Button>
            </NuxtLink>
            <Button variant="ghost" size="sm" @click="signOut()">{{ $t('nav.logout') }}</Button>
          </template>
          <template v-else>
            <NuxtLink to="/login">
              <Button variant="ghost" size="sm">{{ $t('nav.login') }}</Button>
            </NuxtLink>
            <NuxtLink to="/signup">
              <Button size="sm">{{ $t('nav.signup') }}</Button>
            </NuxtLink>
          </template>
        </div>

        <!-- Center: Logo -->
        <div class="order-2 flex-1 md:flex-[4] flex justify-center">
          <NuxtLink to="/" :aria-label="$t('brand.name')">
            <img src="/loader.webp" class="h-9 md:h-11 w-auto" alt="برهان" />
          </NuxtLink>
        </div>

        <!-- Desktop end-side spacer + Mobile hamburger -->
        <template v-if="org && isTenant">
          <div class="flex items-center justify-end md:flex-[3] gap-2 order-3">
            <div class="hidden md:flex items-center gap-2 truncate">
              <img
                v-if="orgLogoSrc"
                :src="orgLogoSrc"
                :alt="displayOrgName"
                class="h-6 w-auto max-w-[100px] object-contain"
              />
              <NuxtLink
                :to="`/${orgSlug}`"
                class="text-xs text-gray-400 hover:text-white truncate transition-colors"
              >
                {{ displayOrgName }}
              </NuxtLink>
            </div>
            <button
              class="md:hidden p-2 text-gray-400 hover:text-white transition-colors rounded-lg hover:bg-white/5"
              :aria-label="menuOpen ? $t('layout.close_menu') : $t('layout.menu_toggle')"
              :aria-expanded="menuOpen"
              @click="menuOpen = !menuOpen"
            >
              <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
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
        </template>
        <template v-else>
          <div class="flex items-center justify-end md:flex-[3] order-3">
            <button
              class="md:hidden p-2 text-gray-400 hover:text-white transition-colors rounded-lg hover:bg-white/5"
              :aria-label="menuOpen ? $t('layout.close_menu') : $t('layout.menu_toggle')"
              :aria-expanded="menuOpen"
              @click="menuOpen = !menuOpen"
            >
              <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
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
        </template>
      </div>

      <!-- Mobile: dropdown menu -->
      <Transition name="slide-down">
        <div
          v-if="menuOpen"
          class="md:hidden border-t border-white/5 glass"
        >
          <nav class="px-4 py-4 space-y-1" aria-label="Mobile navigation">
            <NuxtLink
              to="/"
              class="block px-3 py-2.5 text-sm text-gray-400 hover:text-white rounded-lg hover:bg-white/5 transition-colors"
              :class="{ 'text-gold bg-gold/5': isHub }"
              @click="closeMenu"
            >
              {{ $t('nav.home') }}
            </NuxtLink>

            <NuxtLink
              to="/observatory"
              class="block px-3 py-2.5 text-sm text-gray-400 hover:text-white rounded-lg hover:bg-white/5 transition-colors"
              @click="closeMenu"
            >
              {{ $t('observatory.nav') }}
            </NuxtLink>

            <button
              class="block w-full px-3 py-2.5 text-sm text-gray-400 hover:text-gold rounded-lg hover:bg-white/5 transition-colors"
              :class="currentLocale === 'ar' ? 'text-right' : 'text-left'"
              @click="toggleLocale(); closeMenu()"
            >
              {{ currentLocale === 'ar' ? 'English' : 'العربية' }}
            </button>

            <hr class="border-white/5 my-2" />

            <template v-if="user">
              <NuxtLink
                v-if="isSuperAdmin"
                to="/admin/dashboard"
                class="block px-3 py-2.5 text-sm text-gray-400 hover:text-white rounded-lg hover:bg-white/5 transition-colors"
                @click="closeMenu"
              >
                {{ $t('nav.admin') }}
              </NuxtLink>
              <NuxtLink
                to="/dashboard"
                class="block px-3 py-2.5 text-sm text-gray-400 hover:text-white rounded-lg hover:bg-white/5 transition-colors"
                @click="closeMenu"
              >
                {{ $t('nav.dashboard') }}
              </NuxtLink>
              <button
                class="block w-full px-3 py-2.5 text-sm text-gray-400 hover:text-white rounded-lg hover:bg-white/5 transition-colors"
                :class="currentLocale === 'ar' ? 'text-right' : 'text-left'"
                @click="signOut(); closeMenu()"
              >
                {{ $t('nav.logout') }}
              </button>
            </template>
            <template v-else>
              <NuxtLink
                to="/login"
                class="block px-3 py-2.5 text-sm text-gray-400 hover:text-white rounded-lg hover:bg-white/5 transition-colors"
                @click="closeMenu"
              >
                {{ $t('nav.login') }}
              </NuxtLink>
              <NuxtLink
                to="/signup"
                class="block px-3 py-2.5 text-sm text-gold font-semibold rounded-lg hover:bg-gold/10 transition-colors"
                @click="closeMenu"
              >
                {{ $t('nav.signup') }}
              </NuxtLink>
            </template>
          </nav>
        </div>
      </Transition>
    </header>

    <!-- Main content -->
    <main id="main-content" class="flex-1">
      <slot />
    </main>

    <!-- Footer -->
    <footer class="border-t border-white/5 glass mt-auto">
      <div class="max-w-7xl mx-auto px-4 py-10">
        <div class="flex flex-col md:flex-row items-center justify-between gap-6">
          <!-- Brand -->
          <div class="flex flex-col items-center md:items-start gap-1">
            <span class="text-lg font-bold gradient-gold">{{ $t('brand.name') }}</span>
            <span class="text-xs text-gray-500">{{ $t('brand.tagline') }}</span>
          </div>

          <!-- Links -->
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

        <!-- Divider -->
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
