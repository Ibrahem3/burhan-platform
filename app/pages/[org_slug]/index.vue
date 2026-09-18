<script setup lang="ts">
import type { Database, Json } from '~/types/database'

definePageMeta({
  layout: false,
})

const supabase = useSupabaseClient<Database>()
const route = useRoute()
const { locale, t } = useI18n()
const { currentLocale, extractLocalized, toggleLocale } = useLocale()
const { org, orgName, orgSlug, branches, loading: orgLoading, error: orgError, fetchOrg } = useOrg()
const { entities, fetchOrgEntities, loading: entitiesLoading } = useEntities()
const { user, profile, signOut, isAuthenticated } = useUser()

const displayOrgName = computed(() => localizedValue(orgName.value, currentLocale.value))
const displayOrgNameEn = computed(() => localizedValue(orgName.value, 'en'))

const pageTitle = computed(() => displayOrgName.value || t('tenant.org_not_found_title'))

useHead({
  title: pageTitle,
})

watch(
  () => route.params.org_slug,
  (slug) => {
    if (slug && typeof slug === 'string') {
      fetchOrg(slug)
    }
  },
  { immediate: true },
)

interface Series {
  id: string
  organization_id: string
  branch_id: string
  title: Json
  description?: Json
  cover_url?: string
  is_active: boolean
  created_at: string
}

type Entity = Database['public']['Tables']['entities']['Row']

const seriesList = ref<Series[]>([])
const seriesLoading = ref(false)
const latestEntities = ref<Entity[]>([])
const latestLoading = ref(false)
const speedDialOpen = ref(false)

async function fetchSeries(orgId: string) {
  seriesLoading.value = true
  const { data } = await supabase
    .from('series')
    .select('*')
    .eq('organization_id', orgId)
    .eq('is_active', true)
    .order('created_at', { ascending: false })
    .limit(6)
  if (data) seriesList.value = data as unknown as Series[]
  seriesLoading.value = false
}

async function fetchLatestEntities(orgId: string) {
  latestLoading.value = true
  const { data } = await supabase
    .from('entities')
    .select('*')
    .eq('organization_id', orgId)
    .eq('is_public_to_hub', true)
    .order('created_at', { ascending: false })
    .limit(8)
  if (data) latestEntities.value = data as unknown as Entity[]
  latestLoading.value = false
}

const showAbout = ref(false)

watch(
  () => org.value?.id,
  (orgId) => {
    if (orgId) {
      fetchSeries(orgId)
      fetchLatestEntities(orgId)
      fetchOrgEntities(orgId)
    }
  },
  { immediate: true },
)

function seriesTitle(s: Series): string {
  const t = s.title as Record<string, string>
  return t[locale.value] || t.ar || t.en || ''
}

function seriesBranchName(s: Series): string {
  const b = branches.value.find(b => b.id === s.branch_id)
  if (!b) return ''
  const name = b.name as Record<string, string>
  return name[locale.value] || name.ar || name.en || ''
}

function seriesDescription(s: Series): string {
  if (!s.description) return ''
  const d = s.description as Record<string, string>
  return d[locale.value] || d.ar || d.en || ''
}

function contentTypeIcon(entity: Entity): string {
  if (entity.content_type === 'video') return '🎥'
  if (entity.content_type === 'audio') return '🎙️'
  if (entity.content_type === 'article' || !entity.content_type) return '📝'
  return '📄'
}

function contentTypeBadgeVariant(entity: Entity): string {
  if (entity.content_type === 'video') return 'info'
  if (entity.content_type === 'audio') return 'warning'
  return 'default'
}

function contentTypeLabel(entity: Entity): string {
  if (entity.content_type === 'video') return t('entities.video')
  if (entity.content_type === 'audio') return t('dashboard.type_audio')
  if (entity.content_type === 'article' || !entity.content_type) return t('entities.article')
  return entity.content_type
}

function entityThumbnail(entity: Entity): string | null {
  if (entity.content_type === 'video' && entity.video_id) {
    return `https://img.youtube.com/vi/${entity.video_id}/hqdefault.jpg`
  }
  const content = entity.content as { image_url?: string } | null
  if (content?.image_url) return content.image_url
  return null
}

function entityTitle(entity: Entity): string {
  return localizedValue(entity.title, currentLocale.value)
}

function entityDate(entity: Entity): string {
  return new Date(entity.created_at).toLocaleDateString(
    currentLocale.value === 'ar' ? 'ar-SA' : 'en-US',
    { year: 'numeric', month: 'short', day: 'numeric' },
  )
}

function orgLogo(): string | null {
  if (!org.value?.settings) return null
  const s = typeof org.value.settings === 'string' ? JSON.parse(org.value.settings) : org.value.settings
  return s?.logos?.dark || s?.logos?.light || null
}

function getTagline(): string {
  if (!org.value?.settings) return ''
  const s = typeof org.value.settings === 'string' ? JSON.parse(org.value.settings) : org.value.settings
  return extractLocalized<string>(s?.description) ?? ''
}

function orgInitial(): string {
  return displayOrgName.value.charAt(0) || displayOrgNameEn.value.charAt(0) || '?'
}

function scrollToSection(id: string) {
  speedDialOpen.value = false
  if (id === 'about') {
    showAbout.value = true
    nextTick(() => {
      const el = document.getElementById('org-about')
      if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' })
    })
    return
  }
  showAbout.value = false
  const el = document.getElementById(id)
  if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

const speedDialItems = computed(() => [
  {
    key: 'home',
    icon: '<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" /></svg>',
    label: t('tenant.nav_home'),
    action: () => { speedDialOpen.value = false; scrollToSection('org-hero') },
  },
  {
    key: 'series',
    icon: '<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" /></svg>',
    label: t('tenant.series_title'),
    action: () => { speedDialOpen.value = false; scrollToSection('org-series') },
  },
  {
    key: 'latest',
    icon: '<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" /></svg>',
    label: t('tenant.latest_title'),
    action: () => { speedDialOpen.value = false; scrollToSection('org-latest') },
  },
  {
    key: 'about',
    icon: '<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>',
    label: t('tenant.nav_about'),
    action: () => { speedDialOpen.value = false; scrollToSection('about') },
  },
  {
    key: 'locale',
    icon: '<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m0 4h.01M21 12l-4 4m0 0l-4-4m4 4V8" /></svg>',
    label: currentLocale.value === 'ar' ? 'English' : 'العربية',
    action: () => { toggleLocale(); speedDialOpen.value = false },
  },
  ...(isAuthenticated.value ? [{
    key: 'dashboard',
    icon: '<svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>',
    label: t('nav.dashboard'),
    action: () => { speedDialOpen.value = false; navigateTo('/dashboard') },
  }] : []),
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
</script>

<template>
  <div class="min-h-screen bg-onyx text-gray-100 flex flex-col">
    <a
      href="#main-content"
      class="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4 focus:z-[100] focus:px-4 focus:py-2 focus:bg-gold focus:text-onyx focus:rounded-xl focus:outline-none"
    >
      {{ $t('layout.skip_to_content') }}
    </a>

    <!-- ===== Sovereign Tenant Top Navbar ===== -->
    <header v-if="org" class="sticky top-0 z-40 backdrop-blur-xl bg-onyx/85 border-b border-white/10 shadow-lg shadow-black/40">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 h-16 sm:h-20 flex items-center justify-between gap-4">
        
        <!-- Start: Back to Hub + Tenant Identity -->
        <div class="flex items-center gap-3 min-w-0">
          <NuxtLink
            to="/"
            class="group inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl glass bg-white/[0.03] hover:bg-white/[0.08] border border-white/10 text-xs font-semibold text-gray-300 hover:text-gold transition-all shrink-0"
            :title="$t('hub.title')"
          >
            <svg class="w-4 h-4 text-gold transition-transform duration-300 group-hover:-translate-x-1 rtl:group-hover:translate-x-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            <span class="hidden sm:inline">{{ currentLocale === 'ar' ? 'الرئيسية' : 'Hub' }}</span>
          </NuxtLink>

          <!-- Divider -->
          <div class="h-5 w-px bg-white/10 shrink-0 hidden sm:block" />

          <!-- Tenant Lockup -->
          <div class="flex items-center gap-2.5 min-w-0">
            <div class="w-8 h-8 sm:w-9 sm:h-9 rounded-xl p-0.5 bg-gradient-to-br from-gold/30 via-white/10 to-transparent border border-white/10 flex items-center justify-center shrink-0 overflow-hidden shadow-sm">
              <img v-if="orgLogo()" :src="orgLogo()!" :alt="displayOrgName" class="w-full h-full object-contain" />
              <span v-else class="text-xs font-black text-gold">{{ orgInitial() }}</span>
            </div>
            <div class="min-w-0">
              <div class="flex items-center gap-1.5">
                <span class="text-xs sm:text-sm font-bold text-white truncate max-w-[120px] sm:max-w-[200px] md:max-w-xs">{{ displayOrgName }}</span>
                <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 shrink-0" :title="currentLocale === 'ar' ? 'جهة معرفية معتمدة' : 'Verified Tenant'" />
              </div>
              <p class="text-[10px] text-gray-500 font-mono truncate hidden md:block">/{{ orgSlug }}</p>
            </div>
          </div>
        </div>

        <!-- Center: Section Quick Navigation -->
        <nav class="hidden md:flex items-center gap-1 p-1 rounded-2xl glass bg-white/[0.02] border border-white/5 text-xs font-medium">
          <button
            class="px-3 py-1.5 rounded-xl text-gray-400 hover:text-white hover:bg-white/5 transition-all"
            @click="scrollToSection('org-hero')"
          >
            {{ $t('tenant.nav_home') }}
          </button>
          <button
            class="px-3 py-1.5 rounded-xl text-gray-400 hover:text-white hover:bg-white/5 transition-all flex items-center gap-1.5"
            @click="scrollToSection('org-series')"
          >
            <span>{{ $t('tenant.series_title') }}</span>
            <span class="text-[10px] font-mono px-1.5 py-0.2 rounded-full bg-white/5 text-gray-400">{{ seriesList.length }}</span>
          </button>
          <button
            class="px-3 py-1.5 rounded-xl text-gray-400 hover:text-white hover:bg-white/5 transition-all flex items-center gap-1.5"
            @click="scrollToSection('org-latest')"
          >
            <span>{{ $t('tenant.latest_title') }}</span>
            <span class="text-[10px] font-mono px-1.5 py-0.2 rounded-full bg-white/5 text-gray-400">{{ latestEntities.length }}</span>
          </button>
          <button
            class="px-3 py-1.5 rounded-xl text-gray-400 hover:text-white hover:bg-white/5 transition-all"
            @click="scrollToSection('about')"
          >
            {{ $t('tenant.nav_about') }}
          </button>
        </nav>

        <!-- End: Locale + Auth Actions -->
        <div class="flex items-center gap-2 sm:gap-3 shrink-0">
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
            <template v-if="isAuthenticated">
              <NuxtLink to="/dashboard">
                <Button variant="outline" size="sm" class="text-xs h-9 border-white/15 hover:border-gold/40">
                  {{ $t('nav.dashboard') }}
                </Button>
              </NuxtLink>
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
        </div>
      </div>
    </header>

    <!-- ===== Backdrop for Quick Panel ===== -->
    <Transition name="fade">
      <div
        v-if="speedDialOpen && org"
        class="fixed inset-0 z-40 bg-black/40 backdrop-blur-sm"
        @click="speedDialOpen = false"
      />
    </Transition>

    <!-- ===== Modern Floating Command Dock ===== -->
    <div
      v-if="org"
      class="fixed bottom-4 sm:bottom-6 z-50 flex flex-col"
      :class="currentLocale === 'ar' ? 'right-4 sm:right-6 items-end' : 'left-4 sm:left-6 items-start'"
    >
      <!-- Sleek Glass Command Panel -->
      <Transition name="panel-pop">
        <div
          v-if="speedDialOpen"
          class="mb-2.5 sm:mb-3 w-72 sm:w-80 max-w-[calc(100vw-2rem)] glass backdrop-blur-2xl bg-onyx/90 border border-white/10 rounded-2xl sm:rounded-3xl p-3 sm:p-4 shadow-2xl shadow-black/80 ring-1 ring-white/5 flex flex-col gap-2.5 sm:gap-3.5"
        >
          <!-- Org / User Header -->
          <div class="flex items-center justify-between pb-2 sm:pb-3 border-b border-white/5 px-1">
            <div class="flex items-center gap-2 sm:gap-2.5 min-w-0">
              <div class="w-7 h-7 sm:w-8 sm:h-8 rounded-lg sm:rounded-xl bg-gold/10 border border-gold/20 flex items-center justify-center shrink-0 text-gold text-[11px] sm:text-xs font-bold overflow-hidden">
                <img v-if="orgLogo()" :src="orgLogo()!" :alt="displayOrgName" class="w-full h-full object-cover" />
                <span v-else>{{ orgInitial() }}</span>
              </div>
              <div class="min-w-0 flex-1">
                <p class="text-[11px] sm:text-xs font-medium text-white truncate">
                  {{ displayOrgName }}
                </p>
                <p class="text-[9px] sm:text-[10px] text-gray-400 truncate">
                  {{ isAuthenticated ? (user?.email || profile?.role || 'Member') : (getTagline() || orgSlug) }}
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

          <!-- Section: Quick Navigation inside Org -->
          <div class="space-y-0.5 sm:space-y-1">
            <p class="text-[9px] sm:text-[10px] font-semibold text-gray-500 uppercase tracking-wider px-2 mb-0.5 sm:mb-1">
              {{ currentLocale === 'ar' ? 'أقسام المنظمة' : 'Sections' }}
            </p>

            <button
              class="w-full flex items-center gap-2.5 sm:gap-3 px-2.5 sm:px-3 py-1.5 sm:py-2 rounded-lg sm:rounded-xl text-[11px] sm:text-xs font-medium text-gray-300 hover:text-white hover:bg-white/5 transition-all text-start group"
              @click="speedDialOpen = false; scrollToSection('org-hero')"
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
              @click="speedDialOpen = false; scrollToSection('org-series')"
            >
              <div class="w-6 h-6 sm:w-7 sm:h-7 rounded-md sm:rounded-lg bg-white/5 flex items-center justify-center text-gray-400 group-hover:text-gold group-hover:bg-gold/10 transition-colors">
                <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
              </div>
              <span class="flex-1">{{ $t('tenant.series_title') }}</span>
              <span class="text-[9px] sm:text-[10px] text-gray-500 bg-white/5 px-1.5 sm:px-2 py-0.5 rounded-full">{{ seriesList?.length || 0 }}</span>
            </button>

            <button
              class="w-full flex items-center gap-2.5 sm:gap-3 px-2.5 sm:px-3 py-1.5 sm:py-2 rounded-lg sm:rounded-xl text-[11px] sm:text-xs font-medium text-gray-300 hover:text-white hover:bg-white/5 transition-all text-start group"
              @click="speedDialOpen = false; scrollToSection('org-latest')"
            >
              <div class="w-6 h-6 sm:w-7 sm:h-7 rounded-md sm:rounded-lg bg-white/5 flex items-center justify-center text-gray-400 group-hover:text-gold group-hover:bg-gold/10 transition-colors">
                <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                </svg>
              </div>
              <span class="flex-1">{{ $t('tenant.latest_title') }}</span>
              <span class="text-[9px] sm:text-[10px] text-gray-500 bg-white/5 px-1.5 sm:px-2 py-0.5 rounded-full">{{ entities?.length || 0 }}</span>
            </button>

            <button
              class="w-full flex items-center gap-2.5 sm:gap-3 px-2.5 sm:px-3 py-1.5 sm:py-2 rounded-lg sm:rounded-xl text-[11px] sm:text-xs font-medium text-gray-300 hover:text-white hover:bg-white/5 transition-all text-start group"
              @click="speedDialOpen = false; scrollToSection('about')"
            >
              <div class="w-6 h-6 sm:w-7 sm:h-7 rounded-md sm:rounded-lg bg-white/5 flex items-center justify-center text-gray-400 group-hover:text-gold group-hover:bg-gold/10 transition-colors">
                <svg class="w-3 h-3 sm:w-3.5 sm:h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <span class="flex-1">{{ $t('tenant.nav_about') }}</span>
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

          <!-- Section: Footer / Locale & Hub Link -->
          <div class="pt-1.5 sm:pt-2 border-t border-white/5 flex items-center justify-between px-1">
            <NuxtLink
              to="/"
              class="inline-flex items-center gap-1 text-[10px] sm:text-[11px] text-gray-500 hover:text-gold transition-colors"
              @click="speedDialOpen = false"
            >
              <span>←</span>
              <span>{{ $t('tenant.back_to_org') ? $t('hub.title') : 'الرئيسية' }}</span>
            </NuxtLink>

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

    <!-- ===== Loading state ===== -->
    <div v-if="!org && orgLoading" class="min-h-[70vh] flex items-center justify-center">
      <div class="text-center">
        <div class="w-12 h-12 border-2 border-gold/30 border-t-gold rounded-full animate-spin mx-auto mb-4" />
        <p class="text-gray-500">{{ $t('tenant.loading_org') }}</p>
      </div>
    </div>

    <!-- ===== Error state ===== -->
    <div v-else-if="orgError" class="min-h-[60vh] flex items-center justify-center">
      <GlassCard class="text-center max-w-md mx-auto">
        <div class="py-10 px-4">
          <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-red-500/10 flex items-center justify-center">
            <svg class="w-8 h-8 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
          </div>
          <h2 class="text-xl font-bold text-white mb-2">{{ $t('tenant.org_not_found_title') }}</h2>
          <p class="text-sm text-gray-400 mb-6">{{ $t('tenant.org_not_found_desc') }}</p>
          <NuxtLink to="/">
            <Button>{{ $t('common.back_home') }}</Button>
          </NuxtLink>
        </div>
      </GlassCard>
    </div>

    <!-- ===== Main content ===== -->
    <main v-else-if="org" id="main-content" class="flex-1">
      <!-- ===== Cinematic Sovereign Institutional Hero ===== -->
      <section id="org-hero" class="relative overflow-hidden pt-6 pb-12 sm:pt-10 sm:pb-16 md:pt-12 md:pb-20">
        <!-- Ambient Backdrops & Geometric Mesh -->
        <div class="absolute inset-0 pointer-events-none overflow-hidden">
          <div class="absolute top-1/4 -right-40 w-[600px] h-[600px] bg-gold/10 rounded-full blur-[140px]" />
          <div class="absolute bottom-1/4 -left-40 w-[500px] h-[500px] bg-gold/5 rounded-full blur-[140px]" />
          <div class="absolute inset-0 bg-[linear-gradient(to_right,#ffffff03_1px,transparent_1px),linear-gradient(to_bottom,#ffffff03_1px,transparent_1px)] bg-[size:4rem_4rem] [mask-image:radial-gradient(ellipse_60%_50%_at_50%_50%,#000_70%,transparent_100%)]" />
        </div>

        <div class="relative z-10 max-w-5xl mx-auto px-4 sm:px-6">
          
          <!-- Panoramic Cover Card with Overlapping Avatar -->
          <div class="relative rounded-3xl overflow-hidden border border-white/10 bg-white/[0.02] shadow-2xl mb-8">
            <!-- Cover Header Banner -->
            <div class="h-36 sm:h-48 md:h-56 relative overflow-hidden bg-gradient-to-r from-onyx via-[#19150E] to-[#12100A] flex items-center justify-center">
              <div class="absolute inset-0 bg-[linear-gradient(to_right,#d4af370a_1px,transparent_1px),linear-gradient(to_bottom,#d4af370a_1px,transparent_1px)] bg-[size:2rem_2rem]" />
              <div class="absolute -right-10 -bottom-10 w-64 h-64 bg-gold/15 rounded-full blur-3xl" />
              <div class="absolute -left-10 -top-10 w-64 h-64 bg-gold/10 rounded-full blur-3xl" />
              
              <!-- Subtle Watermark in Cover -->
              <span class="text-[120px] sm:text-[180px] md:text-[220px] font-black text-white/[0.03] select-none pointer-events-none font-mono">
                {{ orgInitial() }}
              </span>

              <!-- Live Sovereign Status Tag on Top Corner -->
              <div class="absolute top-4 end-4 flex items-center gap-2 px-3 py-1.5 rounded-full glass bg-black/40 border border-white/10 text-[11px] text-gray-300">
                <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                <span class="font-mono text-gold font-medium">{{ currentLocale === 'ar' ? 'جهة معرفية معتمدة' : 'Verified Tenant' }}</span>
              </div>
            </div>

            <!-- Profile Info Section with Avatar Overlap -->
            <div class="relative px-6 pb-8 pt-0 sm:px-10 text-center sm:text-start flex flex-col sm:flex-row items-center sm:items-end justify-between gap-6">
              
              <!-- Left: Avatar + Names -->
              <div class="flex flex-col sm:flex-row items-center gap-5 -mt-16 sm:-mt-20">
                <!-- Large Sovereign Avatar -->
                <div class="relative w-28 h-28 sm:w-32 sm:h-32 rounded-3xl p-1 bg-gradient-to-br from-gold/50 via-white/20 to-black/80 border-2 border-gold/40 shadow-2xl shadow-black/80 flex items-center justify-center overflow-hidden bg-onyx shrink-0">
                  <img v-if="orgLogo()" :src="orgLogo()!" :alt="displayOrgName" class="w-full h-full object-contain p-2 rounded-2xl" />
                  <span v-else class="text-4xl sm:text-5xl font-black text-gold font-mono">{{ orgInitial() }}</span>
                </div>

                <!-- Text Headings -->
                <div class="space-y-1 text-center sm:text-start">
                  <div class="flex flex-wrap items-center justify-center sm:justify-start gap-2">
                    <h1 class="text-2xl sm:text-3xl md:text-4xl font-black text-white tracking-tight">
                      {{ displayOrgName }}
                    </h1>
                    <span class="inline-flex items-center text-gold" :title="currentLocale === 'ar' ? 'موثق' : 'Verified'">
                      <svg class="w-5 h-5 fill-gold" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                    </span>
                  </div>

                  <p v-if="displayOrgNameEn && displayOrgNameEn !== displayOrgName" class="text-sm sm:text-base text-gray-400 font-light">
                    {{ displayOrgNameEn }}
                  </p>

                  <div class="flex items-center justify-center sm:justify-start gap-2 pt-1 font-mono text-xs text-gray-500" dir="ltr">
                    <span>https://burhan.ainux.online/{{ orgSlug }}</span>
                  </div>
                </div>
              </div>

              <!-- Right: Quick Hero CTAs -->
              <div class="flex items-center gap-3 shrink-0">
                <button
                  class="cta-glow inline-flex items-center justify-center font-bold transition-all duration-300 rounded-xl px-6 py-3 text-sm bg-gold text-onyx hover:bg-gold-500 active:bg-gold-600 shadow-lg shadow-gold/20 cursor-pointer"
                  @click="scrollToSection('org-series')"
                >
                  {{ $t('tenant.hero_cta') }}
                </button>
                <button
                  class="inline-flex items-center justify-center font-medium transition-all duration-200 rounded-xl px-5 py-3 text-sm glass bg-white/5 hover:bg-white/10 text-gray-300 hover:text-white border border-white/10 cursor-pointer"
                  @click="scrollToSection('about')"
                >
                  {{ $t('tenant.about_org') }}
                </button>
              </div>
            </div>

            <!-- Tagline / Bio Strip -->
            <div v-if="getTagline()" class="px-6 sm:px-10 pb-6 pt-2 border-t border-white/5">
              <p class="text-sm text-gray-300 leading-relaxed max-w-3xl">
                {{ getTagline() }}
              </p>
            </div>
          </div>

          <!-- Live Tenant 4-Pillar Metrics Ribbon -->
          <div class="grid grid-cols-2 md:grid-cols-4 gap-3 sm:gap-4">
            <div class="p-4 rounded-2xl glass bg-white/[0.02] border border-white/5 text-center sm:text-start flex items-center gap-3.5">
              <div class="w-10 h-10 rounded-xl bg-gold/10 border border-gold/20 flex items-center justify-center shrink-0 text-gold text-base">
                📚
              </div>
              <div>
                <p class="text-lg sm:text-xl font-black text-white font-mono leading-none">{{ seriesList.length }}</p>
                <p class="text-[11px] text-gray-400 mt-1">{{ $t('tenant.series_title') }}</p>
              </div>
            </div>

            <div class="p-4 rounded-2xl glass bg-white/[0.02] border border-white/5 text-center sm:text-start flex items-center gap-3.5">
              <div class="w-10 h-10 rounded-xl bg-gold/10 border border-gold/20 flex items-center justify-center shrink-0 text-gold text-base">
                📄
              </div>
              <div>
                <p class="text-lg sm:text-xl font-black text-white font-mono leading-none">{{ latestEntities.length }}</p>
                <p class="text-[11px] text-gray-400 mt-1">{{ $t('tenant.latest_title') }}</p>
              </div>
            </div>

            <div class="p-4 rounded-2xl glass bg-white/[0.02] border border-white/5 text-center sm:text-start flex items-center gap-3.5">
              <div class="w-10 h-10 rounded-xl bg-gold/10 border border-gold/20 flex items-center justify-center shrink-0 text-gold text-base">
                🏛️
              </div>
              <div>
                <p class="text-lg sm:text-xl font-black text-white font-mono leading-none">{{ branches.length }}</p>
                <p class="text-[11px] text-gray-400 mt-1">{{ currentLocale === 'ar' ? 'فروع علمية' : 'Branches' }}</p>
              </div>
            </div>

            <div class="p-4 rounded-2xl glass bg-white/[0.02] border border-white/5 text-center sm:text-start flex items-center gap-3.5">
              <div class="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center shrink-0 text-emerald-400 text-base">
                🛡️
              </div>
              <div>
                <p class="text-xs sm:text-sm font-bold text-emerald-400 leading-tight">100%</p>
                <p class="text-[11px] text-gray-400 mt-0.5">{{ currentLocale === 'ar' ? 'عزل سيادي مستقل' : 'Sovereign Isolation' }}</p>
              </div>
            </div>
          </div>

        </div>
      </section>

      <!-- ===== Sub-Navigation Strip ===== -->
      <div class="sticky top-0 z-30 py-4 px-6 glass backdrop-blur-xl border-b border-white/5">
        <div class="max-w-7xl mx-auto flex items-center gap-1 overflow-x-auto">
          <button
            class="px-4 py-2 text-sm font-medium rounded-xl transition-all duration-200 whitespace-nowrap text-gray-300 hover:text-gold hover:bg-gold/10"
            @click="scrollToSection('org-series')"
          >
            <span class="flex items-center gap-2">
              <svg class="w-4 h-4 text-gold/70" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
              {{ $t('tenant.series_title') }}
            </span>
          </button>
          <button
            class="px-4 py-2 text-sm font-medium rounded-xl transition-all duration-200 whitespace-nowrap text-gray-300 hover:text-gold hover:bg-gold/10"
            @click="scrollToSection('org-latest')"
          >
            <span class="flex items-center gap-2">
              <svg class="w-4 h-4 text-gold/70" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
              {{ $t('tenant.latest_title') }}
            </span>
          </button>
          <button
            class="px-4 py-2 text-sm font-medium rounded-xl transition-all duration-200 whitespace-nowrap text-gray-300 hover:text-gold hover:bg-gold/10"
            @click="scrollToSection('org-about'); showAbout = true"
          >
            <span class="flex items-center gap-2">
              <svg class="w-4 h-4 text-gold/70" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              {{ $t('tenant.about_org') }}
            </span>
          </button>
        </div>
      </div>

      <!-- ===== Production Content Grid (8/4) ===== -->
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 px-6 max-w-7xl mx-auto py-8 pb-16">
        <!-- ===== Main (8 cols) — Series / Courses ===== -->
        <div id="org-series" class="lg:col-span-8 space-y-8 scroll-mt-20">
          <div>
            <div class="flex items-center gap-3 mb-6">
              <div class="w-10 h-10 rounded-xl bg-gold/20 flex items-center justify-center shrink-0">
                <svg class="w-5 h-5 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
              </div>
              <div>
                <h2 class="text-2xl md:text-3xl font-bold text-white">{{ $t('tenant.series_title') }}</h2>
                <p class="text-sm text-gray-500">{{ seriesList.length }} {{ $t('tenant.org_entities_count', { count: seriesList.length }) }}</p>
              </div>
            </div>

            <!-- Series loading -->
            <div v-if="seriesLoading" class="grid grid-cols-1 sm:grid-cols-2 gap-6">
              <div v-for="i in 4" :key="i">
                <GlassCard padding="sm">
                  <div class="animate-pulse space-y-3">
                    <div class="aspect-video bg-white/5 rounded-xl" />
                    <div class="h-4 bg-white/5 rounded w-3/4" />
                    <div class="h-9 bg-white/5 rounded-xl" />
                  </div>
                </GlassCard>
              </div>
            </div>

            <!-- Series grid -->
            <div v-else-if="seriesList.length > 0" class="grid grid-cols-1 sm:grid-cols-2 gap-6">
              <div
                v-for="s in seriesList"
                :key="s.id"
                class="group glass backdrop-blur-md rounded-2xl overflow-hidden border border-white/5 hover:border-gold/30 transition-all duration-500 hover:shadow-glow"
              >
                <div class="relative aspect-video overflow-hidden bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
                  <img
                    v-if="s.cover_url"
                    :src="s.cover_url"
                    :alt="seriesTitle(s)"
                    class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
                    loading="lazy"
                  />
                  <div v-else class="w-full h-full bg-gradient-to-br from-gold/10 via-gray-800 to-gold/5 flex items-center justify-center">
                    <svg class="w-16 h-16 text-gold/30" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                    </svg>
                  </div>
                  <div class="absolute top-3 right-3">
                    <Badge variant="premium" size="sm">
                      {{ $t('tenant.series_badge') }}
                    </Badge>
                  </div>
                  <div v-if="seriesBranchName(s)" class="absolute top-3 left-3">
                    <span class="px-2.5 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wider bg-black/60 backdrop-blur-md border border-white/10 text-white shadow-lg">
                      {{ seriesBranchName(s) }}
                    </span>
                  </div>
                </div>
                <div class="p-5 space-y-3">
                  <h3 class="font-bold text-white text-sm leading-snug line-clamp-2 min-h-[2.5rem]">
                    {{ seriesTitle(s) }}
                  </h3>
                  <p v-if="seriesDescription(s)" class="text-xs text-gray-500 line-clamp-2 leading-relaxed">
                    {{ seriesDescription(s) }}
                  </p>
                  <NuxtLink :to="`/${orgSlug}/series/${s.id}`">
                    <button
                      class="w-full inline-flex items-center justify-center font-medium transition-all duration-300 rounded-xl px-5 py-2.5 text-sm bg-gold text-onyx hover:bg-gold-500 active:bg-gold-600 shadow-lg shadow-gold/20"
                    >
                      {{ $t('tenant.series_cta') }}
                    </button>
                  </NuxtLink>
                </div>
              </div>
            </div>

            <!-- Series empty -->
            <div v-else-if="!seriesLoading" class="text-center py-12">
              <GlassCard>
                <div class="py-6">
                  <svg class="w-10 h-10 text-gray-600 mx-auto mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                  </svg>
                  <p class="text-gray-500">{{ $t('empty.org_desc') }}</p>
                </div>
              </GlassCard>
            </div>
          </div>
        </div>

        <!-- ===== Sidebar (4 cols) — Latest Activity ===== -->
        <aside id="org-latest" class="lg:col-span-4 space-y-6 scroll-mt-20">
          <div class="flex items-center gap-3 mb-2">
            <div class="w-10 h-10 rounded-xl bg-gold/20 flex items-center justify-center shrink-0">
              <svg class="w-5 h-5 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <div>
              <h2 class="text-xl font-bold text-white">{{ $t('tenant.latest_title') }}</h2>
              <p class="text-xs text-gray-500">{{ $t('hub.orgs_count', { count: latestEntities.length }) }}</p>
            </div>
          </div>

          <!-- Latest loading -->
          <div v-if="latestLoading" class="space-y-4">
            <div v-for="i in 4" :key="i">
              <GlassCard padding="sm">
                <div class="animate-pulse flex gap-3">
                  <div class="w-24 shrink-0 aspect-video bg-white/5 rounded-lg" />
                  <div class="flex-1 space-y-2">
                    <div class="h-3 bg-white/5 rounded w-3/4" />
                    <div class="h-3 bg-white/5 rounded w-1/2" />
                  </div>
                </div>
              </GlassCard>
            </div>
          </div>

          <!-- Latest list -->
          <div v-else-if="latestEntities.length > 0" class="space-y-4">
            <NuxtLink
              v-for="entity in latestEntities"
              :key="entity.id"
              :to="`/${orgSlug}/content/${entity.id}`"
              class="group glass backdrop-blur-md rounded-2xl overflow-hidden border border-white/5 hover:border-gold/30 transition-all duration-500 hover:shadow-glow block"
            >
              <div class="flex gap-3 p-3">
                <div class="w-24 shrink-0 relative aspect-video overflow-hidden rounded-xl bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
                  <img
                    v-if="entityThumbnail(entity)"
                    :src="entityThumbnail(entity)!"
                    :alt="entityTitle(entity)"
                    class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                    loading="lazy"
                  />
                  <div
                    v-else-if="entity.content_type === 'audio'"
                    class="w-full h-full bg-gradient-to-br from-purple-900/40 via-gray-800 to-indigo-900/40 flex items-center justify-center p-1"
                  >
                    <svg class="w-full h-full text-purple-400/30" viewBox="0 0 200 80" fill="none">
                      <rect x="10" y="30" width="6" height="20" rx="3" fill="currentColor" class="animate-pulse" style="animation-delay:0s" />
                      <rect x="22" y="20" width="6" height="40" rx="3" fill="currentColor" class="animate-pulse" style="animation-delay:0.1s" />
                      <rect x="34" y="10" width="6" height="60" rx="3" fill="currentColor" class="animate-pulse" style="animation-delay:0.2s" />
                      <rect x="46" y="15" width="6" height="50" rx="3" fill="currentColor" class="animate-pulse" style="animation-delay:0.3s" />
                      <rect x="58" y="25" width="6" height="30" rx="3" fill="currentColor" class="animate-pulse" style="animation-delay:0.15s" />
                      <rect x="70" y="8" width="6" height="64" rx="3" fill="currentColor" class="animate-pulse" style="animation-delay:0.25s" />
                      <rect x="82" y="18" width="6" height="44" rx="3" fill="currentColor" class="animate-pulse" style="animation-delay:0.05s" />
                      <rect x="94" y="28" width="6" height="24" rx="3" fill="currentColor" class="animate-pulse" style="animation-delay:0.35s" />
                    </svg>
                  </div>
                  <div
                    v-else
                    class="w-full h-full bg-gradient-to-br from-gold/5 via-gray-800 to-blue-900/30 flex items-center justify-center"
                  >
                    <svg class="w-5 h-5 text-white/15" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
                    </svg>
                  </div>
                  <div v-if="entity.is_premium" class="absolute top-1 left-1">
                    <span class="px-1.5 py-0.5 rounded text-[8px] font-bold bg-gold/90 text-onyx">PRO</span>
                  </div>
                </div>
                <div class="flex-1 min-w-0 flex flex-col justify-between">
                  <div>
                    <h3 class="text-sm font-semibold text-white leading-snug line-clamp-2 group-hover:text-gold transition-colors">
                      {{ entityTitle(entity) }}
                    </h3>
                    <div class="mt-1.5 flex items-center gap-1.5 flex-wrap">
                      <Badge :variant="contentTypeBadgeVariant(entity)" size="sm">
                        <span class="flex items-center gap-0.5">
                          <span>{{ contentTypeIcon(entity) }}</span>
                          <span>{{ contentTypeLabel(entity) }}</span>
                        </span>
                      </Badge>
                    </div>
                  </div>
                  <div class="flex items-center justify-between text-[11px] text-gray-500 mt-2">
                    <span>{{ entityDate(entity) }}</span>
                    <span class="flex items-center gap-1 text-gray-600">
                      <span class="w-3.5 h-3.5 rounded-full bg-gold/20 flex items-center justify-center text-[7px] font-bold text-gold">{{ orgInitial() }}</span>
                      <span>برهان</span>
                    </span>
                  </div>
                </div>
              </div>
            </NuxtLink>
          </div>

          <!-- Latest empty -->
          <div v-else-if="!latestLoading" class="text-center py-8">
            <GlassCard>
              <div class="py-4">
                <p class="text-sm text-gray-500">{{ $t('empty.org_desc') }}</p>
              </div>
            </GlassCard>
          </div>
        </aside>
      </div>

      <!-- ===== About Section (hidden until menu triggers it) ===== -->
      <div
        v-if="showAbout"
        id="org-about"
        class="relative overflow-hidden mb-16 scroll-mt-20"
      >
        <div class="max-w-5xl mx-auto px-6">
          <div class="flex items-center gap-3 mb-6">
            <div class="w-10 h-10 rounded-xl bg-gold/20 flex items-center justify-center shrink-0">
              <svg class="w-5 h-5 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <h2 class="text-2xl font-bold text-white">{{ $t('tenant.about_org') }}</h2>
          </div>
          <GlassCard class="relative overflow-hidden">
            <div class="absolute inset-0 bg-gradient-to-br from-gold/3 to-transparent pointer-events-none" />
            <div class="relative z-10 p-8 md:p-10">
              <div class="flex flex-col sm:flex-row items-start gap-6">
                <div class="w-16 h-16 rounded-2xl overflow-hidden shrink-0 bg-gold/20 flex items-center justify-center">
                  <img
                    v-if="orgLogo()"
                    :src="orgLogo()!"
                    :alt="displayOrgName"
                    class="w-full h-full object-contain"
                  />
                  <span v-else class="text-2xl font-bold text-gold">{{ orgInitial() }}</span>
                </div>
                <div class="space-y-3">
                  <h3 class="text-2xl font-bold text-white">{{ displayOrgName }}</h3>
                  <p v-if="displayOrgNameEn !== displayOrgName.value" class="text-sm text-gray-500">
                    {{ displayOrgNameEn }}
                  </p>
                  <p v-if="getTagline()" class="text-gray-400 leading-relaxed">
                    {{ getTagline() }}
                  </p>
                  <div class="flex items-center gap-2 pt-2">
                    <span class="text-xs text-gray-600 font-mono">/{{ orgSlug }}</span>
                    <Badge variant="info" size="sm">
                      {{ branches.length }} {{ $t('org_header.branch_count', { count: branches.length }) }}
                    </Badge>
                  </div>
                </div>
              </div>
            </div>
          </GlassCard>
        </div>
      </div>
    </main>

    <!-- ===== Sovereign Tenant 4-Column Foundation Footer ===== -->
    <footer class="border-t border-white/10 glass bg-gradient-to-b from-onyx/80 via-[#0B0B0B] to-[#070707] mt-auto">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 py-12 sm:py-16">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-12 gap-10 lg:gap-8 pb-12">
          
          <!-- Column 1: Tenant Identity & Cloud Platform (5 cols) -->
          <div class="lg:col-span-5 space-y-4">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-2xl p-0.5 bg-gradient-to-br from-gold/30 via-white/10 to-transparent border border-white/10 flex items-center justify-center overflow-hidden shadow-md">
                <img v-if="orgLogo()" :src="orgLogo()!" :alt="displayOrgName" class="w-full h-full object-contain" />
                <span v-else class="text-sm font-black text-gold">{{ orgInitial() }}</span>
              </div>
              <div>
                <span class="text-lg font-black tracking-tight text-white">{{ displayOrgName }}</span>
                <p class="text-xs text-gray-500">{{ getTagline() || $t('brand.tagline') }}</p>
              </div>
            </div>

            <p class="text-xs text-gray-400 leading-relaxed max-w-sm">
              {{ currentLocale === 'ar'
                ? 'بوابة علمية معرفية مستقلة، تدار ضمن البنية التحتية السيادية لمنصة برهان مع ضمان العزل التام للبيانات وأعلى معايير الأمان المؤسسي.'
                : 'A sovereign intellectual portal operating within Burhan Cloud infrastructure, guaranteeing isolated tenancy and cryptographic privacy.'
              }}
            </p>

            <!-- Operational Status Indicator -->
            <div class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/[0.03] border border-white/10 text-xs text-gray-400">
              <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
              <span class="text-[11px] font-mono text-emerald-400/90">{{ currentLocale === 'ar' ? 'المنظومة السحابية تعمل بكفاءة' : 'Cloud Node Operational' }}</span>
            </div>
          </div>

          <!-- Column 2: Organization Sections (2 cols) -->
          <div class="lg:col-span-2 space-y-3">
            <p class="text-xs font-bold text-white uppercase tracking-wider">
              {{ currentLocale === 'ar' ? 'أقسام المنظمة' : 'Sections' }}
            </p>
            <ul class="space-y-2.5 text-xs text-gray-400">
              <li>
                <button class="hover:text-gold transition-colors text-start" @click="scrollToSection('org-hero')">
                  {{ $t('tenant.nav_home') }}
                </button>
              </li>
              <li>
                <button class="hover:text-gold transition-colors text-start" @click="scrollToSection('org-series')">
                  {{ $t('tenant.series_title') }}
                </button>
              </li>
              <li>
                <button class="hover:text-gold transition-colors text-start" @click="scrollToSection('org-latest')">
                  {{ $t('tenant.latest_title') }}
                </button>
              </li>
              <li>
                <button class="hover:text-gold transition-colors text-start" @click="scrollToSection('about')">
                  {{ $t('tenant.about_org') }}
                </button>
              </li>
            </ul>
          </div>

          <!-- Column 3: Burhan Network & Governance (2 cols) -->
          <div class="lg:col-span-2 space-y-3">
            <p class="text-xs font-bold text-white uppercase tracking-wider">
              {{ currentLocale === 'ar' ? 'شبكة برهان' : 'Burhan Network' }}
            </p>
            <ul class="space-y-2.5 text-xs text-gray-400">
              <li>
                <NuxtLink to="/" class="hover:text-gold transition-colors">
                  {{ currentLocale === 'ar' ? 'المركز الرئيسي' : 'Main Hub' }}
                </NuxtLink>
              </li>
              <li>
                <NuxtLink to="/observatory" class="hover:text-gold transition-colors">
                  {{ $t('observatory.nav') }}
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
            <span>&copy; {{ new Date().getFullYear() }} {{ displayOrgName }} &bull; {{ $t('brand.name') }}</span>
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
            Powered by Burhan Cloud v2.0 &bull; 100% Isolated Sovereign Node
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
