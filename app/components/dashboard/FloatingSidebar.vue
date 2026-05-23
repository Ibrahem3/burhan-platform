<script setup lang="ts">
const route = useRoute()
const supabase = useSupabaseClient()
const { t, locale, setLocale } = useI18n()
const localePath = useLocalePath()
const user = useSupabaseUser()

const org = useState('org')
const isPinned = useCookie('sidebar-pinned', { default: () => false })
const mobileNavOpen = ref(false)

const { visible: fabVisible } = useScrollAware()

if (!org.value && user.value) {
  supabase
    .from('profiles')
    .select('organization_id')
    .eq('id', user.value.id)
    .maybeSingle()
    .then(({ data: profile }) => {
      if (profile?.organization_id) {
        supabase
          .from('organizations')
          .select('id, name, org_slug, settings')
          .eq('id', profile.organization_id)
          .maybeSingle()
          .then(({ data: orgData }) => {
            if (orgData) org.value = orgData
          })
      }
    })
}

const isActive = (path: string) => route.path === localePath(path)

const orgName = computed(() => {
  const o = org.value as { name?: Record<string,string> | string } | null
  if (!o?.name) return ''
  return localizedValue(o.name, locale.value === 'en' ? 'en' : 'ar')
})

const orgSlug = computed(() => {
  const o = org.value as { org_slug?: string } | null
  return o?.org_slug || ''
})

const userInitials = computed(() => {
  const email = user.value?.email || ''
  return email.charAt(0).toUpperCase()
})

const userEmail = computed(() => user.value?.email || '')

function togglePin() {
  isPinned.value = !isPinned.value
}

function toggleLocale() {
  const newLocale = locale.value === 'ar' ? 'en' : 'ar'
  locale.value = newLocale
  document.documentElement.lang = newLocale
  document.documentElement.dir = newLocale === 'ar' ? 'rtl' : 'ltr'
  document.documentElement.classList.remove('rtl', 'ltr')
  document.documentElement.classList.add(newLocale === 'ar' ? 'rtl' : 'ltr')
}

async function logout() {
  await supabase.auth.signOut()
  await navigateTo('/login')
}

function openMobileNav() {
  mobileNavOpen.value = true
}

function closeMobileNav() {
  mobileNavOpen.value = false
}
</script>

<template>
  <!-- ======== Desktop Sidebar (lg+) ======== -->
  <div
    class="hidden lg:block fixed z-50"
    :class="locale === 'ar' ? 'right-6' : 'left-6'"
    style="bottom: 1rem;"
  >
    <div
      class="floating-sidebar border border-white/5 shadow-2xl"
      :class="{ pinned: isPinned }"
      :style="{ backgroundColor: 'rgba(10, 10, 10, 0.96)' }"
      @dblclick="togglePin"
    >
      <!-- Collapsed bubble -->
      <div class="bubble-icon">
        <div class="w-10 h-10 rounded-xl bg-gold/10 flex items-center justify-center">
          <svg class="w-5 h-5 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
          </svg>
        </div>
      </div>

      <!-- Expanded content -->
      <div class="expanded-content">
        <div class="flex flex-col h-full">
          <!-- Header -->
          <div class="flex items-center justify-between px-6 h-16 shrink-0 border-b border-white/5">
            <div class="flex items-center gap-3 overflow-hidden">
              <div class="w-8 h-8 rounded-lg bg-gold/10 flex items-center justify-center shrink-0">
                <svg class="w-4 h-4 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
                </svg>
              </div>
              <div class="min-w-0">
                <p class="text-sm font-bold text-white truncate">{{ orgName || $t('dashboard.title') }}</p>
                <p class="text-[10px] text-gray-500 font-medium">{{ $t('dashboard.hub_label') }}</p>
              </div>
            </div>
            <button
              class="p-1.5 rounded-lg hover:bg-white/5 transition-colors shrink-0"
              :title="isPinned ? $t('dashboard.unpin') : $t('dashboard.pin')"
              @click="togglePin"
            >
              <svg
                class="w-3.5 h-3.5 transition-transform duration-300"
                :class="isPinned ? 'rotate-45 text-gold' : 'text-gray-500'"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
              </svg>
            </button>
          </div>

          <!-- Navigation -->
          <nav class="flex-1 overflow-y-auto px-3 py-4 space-y-1">
            <NuxtLink
              :to="localePath('/dashboard')"
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200"
              :class="isActive('/dashboard') ? 'bg-gold/10 text-gold' : 'text-gray-400 hover:text-white hover:bg-white/5'"
            >
              <svg class="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
              </svg>
              <span>{{ $t('dashboard.overview') }}</span>
            </NuxtLink>
            <NuxtLink
              :to="localePath('/dashboard/branches')"
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200"
              :class="isActive('/dashboard/branches') ? 'bg-gold/10 text-gold' : 'text-gray-400 hover:text-white hover:bg-white/5'"
            >
              <svg class="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01" />
              </svg>
              <span>{{ $t('dashboard.branches') }}</span>
            </NuxtLink>
            <NuxtLink
              :to="localePath('/dashboard/entities')"
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200"
              :class="isActive('/dashboard/entities') ? 'bg-gold/10 text-gold' : 'text-gray-400 hover:text-white hover:bg-white/5'"
            >
              <svg class="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              <span>{{ $t('dashboard.entities') }}</span>
            </NuxtLink>
          </nav>

          <!-- Hub link -->
          <div class="px-3 py-2 border-t border-white/5">
            <NuxtLink
              :to="orgSlug ? localePath(`/${orgSlug}`) : localePath('/')"
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium text-gray-500 hover:text-gold hover:bg-white/5 transition-all duration-200"
            >
              <svg class="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
              <span>{{ $t('dashboard.system_hub') }}</span>
            </NuxtLink>
          </div>

          <!-- Footer -->
          <div class="shrink-0 border-t border-white/5 px-3 py-3">
            <div class="flex items-center gap-3 px-3 py-2">
              <div class="w-8 h-8 rounded-full bg-gold/20 flex items-center justify-center text-xs font-bold text-gold shrink-0">
                {{ userInitials }}
              </div>
              <div class="min-w-0 flex-1">
                <p class="text-xs text-gray-400 truncate">{{ userEmail }}</p>
              </div>
              <button
                class="p-1.5 text-gray-500 hover:text-gold rounded-lg hover:bg-gold/10 transition-all shrink-0"
                :title="locale === 'ar' ? $t('locale.switch_to_en') : $t('locale.switch_to_ar')"
                @click="toggleLocale"
              >
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </button>
              <button
                class="p-1.5 text-gray-500 hover:text-red-400 rounded-lg hover:bg-red-500/10 transition-all shrink-0"
                :title="$t('common.logout')"
                @click="logout"
              >
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- ======== Mobile: Bubble Trigger (below lg) ======== -->
  <div
    class="lg:hidden fixed z-50 transition-transform duration-300"
    :class="[locale === 'ar' ? 'right-4' : 'left-4', fabVisible ? 'translate-y-0' : 'translate-y-20']"
    style="bottom: 1rem;"
  >
    <button
      class="w-12 h-12 rounded-full border border-white/10 shadow-2xl flex items-center justify-center transition-all active:scale-90 hover:border-gold/30"
      :style="{ backgroundColor: 'rgba(10, 10, 10, 0.96)', backdropFilter: 'blur(32px)' }"
      @click="openMobileNav"
      :aria-label="$t('dashboard.hub_label')"
    >
      <div class="w-8 h-8 rounded-lg bg-gold/10 flex items-center justify-center">
        <svg class="w-4 h-4 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
        </svg>
      </div>
    </button>
  </div>

  <!-- ======== Mobile: Navigation Overlay (below lg) ======== -->
  <Transition name="mobile-nav">
    <div
      v-if="mobileNavOpen"
      class="lg:hidden fixed inset-0 z-[60] flex flex-col"
      :style="{ backgroundColor: 'rgba(10, 10, 10, 0.98)' }"
    >
      <!-- Backdrop click to close -->
      <div
        class="absolute inset-0"
        @click="closeMobileNav"
      />

      <!-- Content -->
      <div class="relative z-10 flex flex-col h-full px-5 pt-12 pb-6">
        <!-- Close button -->
        <button
          class="absolute top-4 self-center p-2 rounded-full bg-white/5 border border-white/10 text-gray-400 hover:text-white transition-all"
          @click="closeMobileNav"
          :aria-label="$t('layout.close_menu')"
        >
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>

        <!-- Header -->
        <div class="text-center mb-8">
          <div class="w-12 h-12 mx-auto mb-3 rounded-2xl bg-gold/10 flex items-center justify-center">
            <svg class="w-6 h-6 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
            </svg>
          </div>
          <p class="text-lg font-bold text-white">{{ orgName || $t('dashboard.title') }}</p>
          <p class="text-xs text-gray-500">{{ $t('dashboard.hub_label') }}</p>
        </div>

        <!-- Navigation -->
        <nav class="flex-1 space-y-1 overflow-y-auto px-2">
          <NuxtLink
            :to="localePath('/dashboard')"
            class="flex items-center gap-4 px-4 py-3.5 rounded-2xl text-sm font-medium transition-all duration-200"
            :class="isActive('/dashboard') ? 'bg-gold/10 text-gold' : 'text-gray-400 hover:text-white hover:bg-white/5'"
            @click="closeMobileNav"
          >
            <svg class="w-5 h-5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
            </svg>
            <span>{{ $t('dashboard.overview') }}</span>
          </NuxtLink>
          <NuxtLink
            :to="localePath('/dashboard/branches')"
            class="flex items-center gap-4 px-4 py-3.5 rounded-2xl text-sm font-medium transition-all duration-200"
            :class="isActive('/dashboard/branches') ? 'bg-gold/10 text-gold' : 'text-gray-400 hover:text-white hover:bg-white/5'"
            @click="closeMobileNav"
          >
            <svg class="w-5 h-5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01" />
            </svg>
            <span>{{ $t('dashboard.branches') }}</span>
          </NuxtLink>
          <NuxtLink
            :to="localePath('/dashboard/entities')"
            class="flex items-center gap-4 px-4 py-3.5 rounded-2xl text-sm font-medium transition-all duration-200"
            :class="isActive('/dashboard/entities') ? 'bg-gold/10 text-gold' : 'text-gray-400 hover:text-white hover:bg-white/5'"
            @click="closeMobileNav"
          >
            <svg class="w-5 h-5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            <span>{{ $t('dashboard.entities') }}</span>
          </NuxtLink>

          <hr class="border-white/5 my-4" />

          <NuxtLink
            :to="orgSlug ? localePath(`/${orgSlug}`) : localePath('/')"
            class="flex items-center gap-4 px-4 py-3.5 rounded-2xl text-sm font-medium text-gray-500 hover:text-gold hover:bg-white/5 transition-all duration-200"
            @click="closeMobileNav"
          >
            <svg class="w-5 h-5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            <span>{{ $t('dashboard.system_hub') }}</span>
          </NuxtLink>
        </nav>

        <!-- Footer -->
        <div class="shrink-0 border-t border-white/5 pt-4 mt-4">
          <div class="flex items-center justify-between px-2">
            <div class="flex items-center gap-3 min-w-0">
              <div class="w-9 h-9 rounded-full bg-gold/20 flex items-center justify-center text-sm font-bold text-gold shrink-0">
                {{ userInitials }}
              </div>
              <div class="min-w-0">
                <p class="text-sm text-gray-300 truncate">{{ userEmail }}</p>
              </div>
            </div>
            <div class="flex items-center gap-2">
              <button
                class="p-2 text-gray-500 hover:text-gold rounded-xl hover:bg-gold/10 transition-all"
                :title="locale === 'ar' ? $t('locale.switch_to_en') : $t('locale.switch_to_ar')"
                @click="toggleLocale"
              >
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </button>
              <button
                class="p-2 text-gray-500 hover:text-red-400 rounded-xl hover:bg-red-500/10 transition-all"
                :title="$t('common.logout')"
                @click="logout"
              >
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.floating-sidebar {
  position: relative;
  width: 60px;
  height: 60px;
  border-radius: 9999px;
  transition: width 0.35s ease, height 0.35s ease, border-radius 0.35s ease;
  overflow: hidden;
  backdrop-filter: blur(32px);
  -webkit-backdrop-filter: blur(32px);
}

.floating-sidebar:hover,
.floating-sidebar.pinned {
  width: 320px;
  height: calc(100vh - 2rem);
  border-radius: 1rem;
}

.bubble-icon {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: opacity 0.2s ease;
  z-index: 1;
}

.floating-sidebar:hover .bubble-icon,
.floating-sidebar.pinned .bubble-icon {
  opacity: 0;
  pointer-events: none;
}

.expanded-content {
  height: 100%;
  display: flex;
  flex-direction: column;
  opacity: 0;
  transition: opacity 0.25s ease 0.1s;
}

.floating-sidebar:hover .expanded-content,
.floating-sidebar.pinned .expanded-content {
  opacity: 1;
}

/* Mobile overlay transitions */
.mobile-nav-enter-active {
  transition: opacity 0.25s ease;
}
.mobile-nav-leave-active {
  transition: opacity 0.2s ease;
}
.mobile-nav-enter-from,
.mobile-nav-leave-to {
  opacity: 0;
}
</style>
