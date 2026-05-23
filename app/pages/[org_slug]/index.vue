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
const { user, signOut, isAuthenticated } = useUser()

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

    <!-- ===== Backdrop for speed dial ===== -->
    <Transition name="fade">
      <div
        v-if="speedDialOpen && org"
        class="fixed inset-0 z-40 bg-black/30"
        @click="speedDialOpen = false"
      />
    </Transition>

    <!-- ===== Speed Dial Wrapper ===== -->
    <div
      v-if="org"
      class="fixed bottom-6 z-50 flex flex-col items-center"
      :class="currentLocale === 'ar' ? 'right-6' : 'left-6'"
    >
      <!-- Speed Dial Items -->
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
      <!-- ===== Immersive Hero ===== -->
      <section id="org-hero" class="relative overflow-hidden py-20 md:py-28 lg:py-36">
        <div class="absolute top-1/4 -left-40 w-[500px] h-[500px] bg-gold/5 rounded-full blur-3xl" />
        <div class="absolute top-1/3 -right-40 w-[400px] h-[400px] bg-gold/3 rounded-full blur-3xl" />
        <div class="absolute bottom-0 left-1/2 -translate-x-1/2 w-[600px] h-[300px] bg-gold/3 rounded-full blur-3xl" />
        <div class="absolute inset-0 bg-gradient-to-b from-gold/5 via-transparent to-transparent pointer-events-none" />

        <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-[200px] md:text-[320px] font-black text-white/3 pointer-events-none select-none leading-none">
          {{ orgInitial() }}
        </div>

        <div class="relative z-10 max-w-4xl mx-auto px-6 text-center">
          <div class="animate-fade-in">
            <h1 class="text-4xl sm:text-5xl md:text-6xl lg:text-7xl font-bold leading-tight mb-4">
              <span class="gradient-gold">{{ $t('tenant.welcome', { name: displayOrgName }) }}</span>
            </h1>
            <p v-if="displayOrgNameEn" class="text-xl sm:text-2xl md:text-3xl text-gray-500 font-light tracking-wide mb-5">
              {{ displayOrgNameEn }}
            </p>
            <p v-if="getTagline()" class="text-base md:text-lg text-gray-400 max-w-2xl mx-auto mb-10 leading-relaxed">
              {{ getTagline() }}
            </p>
            <div class="flex flex-wrap items-center justify-center gap-4">
              <button
                class="cta-glow inline-flex items-center justify-center font-medium transition-all duration-300 rounded-xl px-8 py-3.5 md:px-10 md:py-4 text-base md:text-lg bg-gold text-onyx hover:bg-gold-500 active:bg-gold-600 shadow-lg shadow-gold/20"
                @click="scrollToSection('org-series')"
              >
                {{ $t('tenant.hero_cta') }}
              </button>
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
