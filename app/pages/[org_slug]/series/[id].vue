<script setup lang="ts">
import type { Database, Json } from '~/types/database'

definePageMeta({
  layout: false,
})

const supabase = useSupabaseClient<Database>()
const route = useRoute()
const { locale, t } = useI18n()
const { currentLocale, extractLocalized, toggleLocale } = useLocale()
const { org, orgName, fetchOrg } = useOrg()

const menuOpen = ref(false)

const seriesId = route.params.id as string
const orgSlugParam = route.params.org_slug as string

const series = ref<any>(null)
const lessons = ref<any[]>([])
const branch = ref<any>(null)
const loading = ref(true)
const notFound = ref(false)

const pageTitle = computed(() => {
  if (!series.value) return ''
  const title = series.value.title as Record<string, string>
  return title[locale.value] || title.ar || title.en || ''
})

useHead({
  title: pageTitle,
})

async function fetchData() {
  loading.value = true
  notFound.value = false

  await fetchOrg(orgSlugParam)

  const { data: sData } = await supabase
    .from('series')
    .select('*')
    .eq('id', seriesId)
    .single()

  if (!sData) {
    notFound.value = true
    loading.value = false
    return
  }

  series.value = sData

  if (sData.branch_id) {
    const { data: bData } = await supabase
      .from('branches')
      .select('*')
      .eq('id', sData.branch_id)
      .single()
    if (bData) branch.value = bData
  }

  const { data: eData } = await supabase
    .from('entities')
    .select('*')
    .eq('series_id', seriesId)
    .order('sort_order', { ascending: true })
    .order('created_at', { ascending: true })

  lessons.value = eData ?? []
  loading.value = false
}

watch(() => route.params.id, fetchData, { immediate: true })

function localizedTitle(obj: Json): string {
  const t = obj as Record<string, string>
  return t[locale.value] || t.ar || t.en || ''
}

function localizedDescription(obj: Json | undefined): string {
  if (!obj) return ''
  const d = obj as Record<string, string>
  return d[locale.value] || d.ar || d.en || ''
}

function branchName(): string {
  if (!branch.value) return ''
  const name = branch.value.name as Record<string, string>
  return name[locale.value] || name.ar || name.en || ''
}

function contentTypeIcon(type: string | null): string {
  if (type === 'video') return '🎥'
  if (type === 'audio') return '🎙️'
  return '📝'
}

function contentTypeLabel(type: string | null): string {
  if (type === 'video') return t('entities.video')
  if (type === 'audio') return t('dashboard.type_audio')
  return t('entities.article')
}

function lessonDate(lesson: any): string {
  return new Date(lesson.created_at).toLocaleDateString(
    currentLocale.value === 'ar' ? 'ar-SA' : 'en-US',
    { year: 'numeric', month: 'short', day: 'numeric' },
  )
}

function paddedIndex(i: number): string {
  return String(i + 1).padStart(2, '0')
}

const displayOrgName = computed(() => localizedValue(orgName.value, currentLocale.value))

function orgLogo(): string | null {
  if (!org.value?.settings) return null
  const s = typeof org.value.settings === 'string' ? JSON.parse(org.value.settings) : org.value.settings
  return s?.logos?.dark || s?.logos?.light || null
}

function orgInitial(): string {
  return displayOrgName.value ? displayOrgName.value.charAt(0) : '?'
}

function scrollToCurriculum() {
  const target = document.getElementById('curriculum-section')
  if (target) {
    target.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
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

    <!-- ===== Sovereign Series Top Navbar ===== -->
    <header class="sticky top-0 z-50 glass backdrop-blur-xl bg-onyx/85 border-b border-white/10">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 h-16 sm:h-20 flex items-center justify-between gap-4">
        <!-- Brand & Breadcrumb lockup -->
        <div class="flex items-center gap-2.5 sm:gap-3 min-w-0">
          <NuxtLink
            to="/"
            class="flex items-center gap-2 text-lg sm:text-xl font-black text-white hover:text-gold transition-colors shrink-0 group"
          >
            <div class="w-8 h-8 rounded-xl bg-gold/10 border border-gold/30 flex items-center justify-center text-gold group-hover:scale-105 transition-transform">
              <span class="font-mono font-bold text-sm">بُ</span>
            </div>
            <span class="hidden sm:inline font-mono tracking-tight">{{ $t('brand.name') }}</span>
          </NuxtLink>

          <span class="text-gray-600 select-none text-sm">/</span>

          <!-- Organization Profile Link -->
          <NuxtLink
            :to="`/${orgSlugParam}`"
            class="flex items-center gap-2 min-w-0 px-2.5 py-1 rounded-xl bg-white/[0.03] hover:bg-white/[0.07] border border-white/10 hover:border-gold/30 transition-all text-xs sm:text-sm font-semibold text-gray-200 hover:text-gold truncate"
          >
            <span class="w-2 h-2 rounded-full bg-gold shrink-0" />
            <span class="truncate">{{ displayOrgName }}</span>
          </NuxtLink>

          <span class="text-gray-600 select-none text-sm hidden md:inline">/</span>

          <!-- Current Series Title Capsule -->
          <span class="hidden md:inline-flex items-center gap-1.5 text-xs text-gold bg-gold/10 px-3 py-1 rounded-xl border border-gold/20 font-bold truncate max-w-[220px] lg:max-w-[320px]">
            <span>✦</span>
            <span class="truncate">{{ pageTitle }}</span>
          </span>
        </div>

        <!-- End actions -->
        <div class="flex items-center gap-2.5 sm:gap-3 shrink-0">
          <NuxtLink
            :to="`/${orgSlugParam}`"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold text-gray-300 hover:text-white bg-white/[0.04] hover:bg-white/[0.08] border border-white/10 hover:border-white/20 transition-all"
          >
            <span>{{ currentLocale.value === 'ar' ? '←' : '→' }}</span>
            <span class="hidden sm:inline">{{ $t('tenant.back_to_org') }}</span>
            <span class="sm:hidden">{{ currentLocale.value === 'ar' ? 'رجوع' : 'Back' }}</span>
          </NuxtLink>

          <button
            class="px-3 py-1.5 text-xs font-mono font-bold text-gold hover:text-gold-300 bg-gold/10 hover:bg-gold/20 border border-gold/30 rounded-xl transition-all cursor-pointer"
            @click="toggleLocale()"
          >
            {{ currentLocale.value === 'ar' ? 'EN' : 'عربي' }}
          </button>
        </div>
      </div>
    </header>

    <!-- Loading skeleton -->
    <div v-if="loading" class="min-h-screen flex items-center justify-center p-6">
      <div class="w-full max-w-7xl grid grid-cols-1 lg:grid-cols-12 gap-8">
        <div class="lg:col-span-4 space-y-6">
          <div class="aspect-video lg:aspect-[4/3] rounded-2xl bg-white/5 animate-pulse" />
          <div class="space-y-3">
            <div class="h-6 bg-white/5 rounded w-3/4 animate-pulse" />
            <div class="h-4 bg-white/5 rounded w-full animate-pulse" />
            <div class="h-4 bg-white/5 rounded w-2/3 animate-pulse" />
            <div class="h-12 bg-white/5 rounded-xl animate-pulse mt-6" />
          </div>
        </div>
        <div class="lg:col-span-8 space-y-4">
          <div v-for="i in 5" :key="i" class="h-20 bg-white/5 rounded-2xl animate-pulse" />
        </div>
      </div>
    </div>

    <!-- Not found -->
    <div v-else-if="notFound" class="min-h-[60vh] flex items-center justify-center">
      <GlassCard class="text-center max-w-md mx-auto">
        <div class="py-10 px-4">
          <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-red-500/10 flex items-center justify-center">
            <svg class="w-8 h-8 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
          </div>
          <h2 class="text-xl font-bold text-white mb-2">{{ $t('tenant.org_not_found_title') }}</h2>
          <p class="text-sm text-gray-400 mb-6">{{ $t('tenant.org_not_found_desc') }}</p>
          <NuxtLink :to="`/${orgSlugParam}`">
            <Button>{{ $t('common.back_home') }}</Button>
          </NuxtLink>
        </div>
      </GlassCard>
    </div>

    <!-- ===== Main ===== -->
    <main v-else-if="series" id="main-content" class="flex-1">
      <!-- Ambient Background Glows -->
      <div class="fixed inset-0 pointer-events-none overflow-hidden z-0">
        <div class="absolute top-1/4 -right-40 w-[500px] h-[500px] bg-gold/5 rounded-full blur-[140px]" />
        <div class="absolute bottom-1/4 -left-40 w-[500px] h-[500px] bg-gold/5 rounded-full blur-[140px]" />
      </div>

      <!-- Top Navigation & Institutional Breadcrumb Banner -->
      <div class="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 pt-6 pb-2">
        <div class="flex flex-wrap items-center justify-between gap-3 text-xs sm:text-sm">
          <NuxtLink
            :to="`/${orgSlugParam}`"
            class="inline-flex items-center gap-2 text-gray-400 hover:text-gold transition-colors font-medium group"
          >
            <span class="w-7 h-7 rounded-xl bg-white/5 border border-white/10 group-hover:border-gold/30 flex items-center justify-center transition-colors">
              <span class="text-xs">{{ currentLocale.value === 'ar' ? '→' : '←' }}</span>
            </span>
            <span>{{ $t('tenant.back_to_org') }}</span>
          </NuxtLink>

          <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/[0.03] border border-white/10 text-xs text-gray-400">
            <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
            <span class="font-mono text-gold">{{ currentLocale.value === 'ar' ? 'مسار تعليمي معتمد' : 'Verified Academic Track' }}</span>
          </div>
        </div>
      </div>

      <!-- Two-Column Sovereign Layout (Sidebar 4 / Curriculum 8) -->
      <div class="relative z-10 grid grid-cols-1 lg:grid-cols-12 gap-8 max-w-7xl mx-auto px-4 sm:px-6 py-6 pb-20">
        
        <!-- ===== Course Overview Sidebar (4 cols) ===== -->
        <aside class="lg:col-span-4 lg:sticky lg:top-24 lg:self-start space-y-6">
          
          <!-- Sovereign Cover Container -->
          <div class="group relative rounded-3xl overflow-hidden border border-white/10 hover:border-gold/40 bg-[#0E0E0E]/90 backdrop-blur-xl shadow-2xl transition-all duration-500">
            <!-- Top Gold Ambient Glow Line on Hover -->
            <div class="absolute top-0 inset-x-0 h-1 bg-gradient-to-r from-transparent via-gold to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500 z-20" />

            <div class="relative aspect-[16/10] sm:aspect-[4/3] overflow-hidden bg-gradient-to-br from-[#161616] via-[#121212] to-black">
              <img
                v-if="series.cover_url"
                :src="series.cover_url"
                :alt="pageTitle"
                class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
              />
              
              <!-- Fallback Cover: Academic Geometric Pattern -->
              <div v-else class="w-full h-full bg-gradient-to-br from-gold/15 via-[#141414] to-[#0A0A0A] flex flex-col items-center justify-center relative p-6">
                <div class="absolute inset-0 bg-[linear-gradient(to_right,#ffffff05_1px,transparent_1px),linear-gradient(to_bottom,#ffffff05_1px,transparent_1px)] bg-[size:1.5rem_1.5rem]" />
                <div class="w-16 h-16 rounded-2xl bg-gold/10 border border-gold/20 flex items-center justify-center text-gold shadow-lg group-hover:scale-110 transition-transform duration-500">
                  <svg class="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                  </svg>
                </div>
                <span class="text-xs font-bold text-gray-500 mt-2.5 font-mono uppercase tracking-widest">{{ $t('tenant.series_title') }}</span>
              </div>

              <!-- Vignette Shadow at bottom of cover -->
              <div class="absolute inset-0 bg-gradient-to-t from-[#0E0E0E] via-black/20 to-transparent pointer-events-none" />

              <!-- Top Left / Start: Branch Badge -->
              <div v-if="branchName()" class="absolute top-3.5 start-3.5 z-10">
                <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-xl text-[11px] font-bold bg-black/75 backdrop-blur-md border border-white/15 text-white shadow-lg">
                  <span class="text-gold text-[10px]">🏛️</span>
                  <span>{{ branchName() }}</span>
                </span>
              </div>

              <!-- Top Right / End: Series Badge -->
              <div class="absolute top-3.5 end-3.5 z-10">
                <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-xl text-[10px] font-mono font-bold uppercase tracking-wider bg-gold text-onyx shadow-lg shadow-gold/20">
                  <span>✦</span>
                  <span>{{ $t('tenant.series_badge') }}</span>
                </span>
              </div>

              <!-- Bottom Tag inside Cover -->
              <div class="absolute bottom-3 start-4 end-4 z-10 flex items-center justify-between text-[11px] text-gray-300">
                <span class="inline-flex items-center gap-1.5 font-mono text-gray-300 bg-black/65 backdrop-blur-sm px-2.5 py-1 rounded-lg border border-white/10">
                  <span class="w-1.5 h-1.5 rounded-full bg-emerald-400" />
                  <span>{{ currentLocale.value === 'ar' ? 'سلسلة علمية متكاملة' : 'Curated Curriculum Track' }}</span>
                </span>
              </div>
            </div>
          </div>

          <!-- Course Info & Primary Actions Card -->
          <div class="rounded-3xl p-6 bg-[#0E0E0E]/90 border border-white/10 shadow-2xl backdrop-blur-xl space-y-5">
            <div>
              <div class="inline-flex items-center gap-2 mb-2">
                <span class="w-2 h-2 rounded-full bg-gold" />
                <span class="text-xs font-mono uppercase tracking-wider text-gray-400">{{ localizedValue(orgName, currentLocale) }}</span>
              </div>
              <h1 class="text-2xl sm:text-3xl font-black text-white leading-snug tracking-tight">
                <span class="gradient-gold">{{ pageTitle }}</span>
              </h1>
              <p v-if="series.description && localizedDescription(series.description)" class="text-xs sm:text-sm text-gray-300 mt-3 leading-relaxed">
                {{ localizedDescription(series.description) }}
              </p>
              <p v-else class="text-xs text-gray-500 mt-3 italic">
                {{ currentLocale.value === 'ar' ? 'مسار أكاديمي علمي متخصص تشرف عليه المنظمة.' : 'Specialized institutional academic curriculum.' }}
              </p>
            </div>

            <!-- Stats Ribbon -->
            <div class="flex flex-wrap items-center gap-2 pt-1 border-t border-white/5">
              <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-xl text-xs font-semibold bg-white/5 border border-white/10 text-gray-200">
                <span class="text-gold">📚</span>
                <span>{{ lessons.length }} {{ $t('tenant.org_entities_count', { count: lessons.length }) }}</span>
              </span>

              <span v-if="branchName()" class="inline-flex items-center gap-1.5 px-3 py-1 rounded-xl text-xs font-medium bg-white/5 border border-white/10 text-gray-300">
                <span>🏛️</span>
                <span>{{ branchName() }}</span>
              </span>
            </div>

            <!-- Action Buttons Area -->
            <div v-if="lessons.length > 0" class="space-y-3 pt-2">
              <!-- Primary CTA: Direct Navigate to First Lesson -->
              <NuxtLink
                :to="`/${orgSlugParam}/content/${lessons[0].id}`"
                class="block w-full group/btn"
              >
                <button
                  type="button"
                  class="w-full inline-flex items-center justify-between font-bold transition-all duration-300 rounded-2xl px-5 py-3.5 text-sm sm:text-base bg-gradient-to-r from-gold via-gold-400 to-gold text-onyx hover:from-gold-400 hover:to-gold-300 shadow-xl shadow-gold/20 hover:shadow-gold/30 hover:scale-[1.01] active:scale-[0.99] cursor-pointer"
                >
                  <span class="flex items-center gap-2.5">
                    <div class="w-7 h-7 rounded-xl bg-onyx/15 flex items-center justify-center">
                      <svg class="w-4 h-4 text-onyx" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M8 5v14l11-7z" />
                      </svg>
                    </div>
                    <span>{{ $t('tenant.hero_cta') }}</span>
                  </span>

                  <div class="w-7 h-7 rounded-xl bg-onyx/10 flex items-center justify-center group-hover/btn:translate-x-1 rtl:group-hover/btn:-translate-x-1 transition-transform">
                    <span class="text-xs font-black">{{ currentLocale.value === 'ar' ? '←' : '→' }}</span>
                  </div>
                </button>
              </NuxtLink>

              <!-- Secondary CTA: Smooth Scroll to Curriculum Section -->
              <button
                type="button"
                @click="scrollToCurriculum"
                class="w-full inline-flex items-center justify-center gap-2 font-semibold transition-all duration-300 rounded-2xl px-4 py-3 text-xs sm:text-sm bg-white/[0.04] hover:bg-white/[0.08] text-gray-300 hover:text-white border border-white/10 hover:border-white/20 cursor-pointer group/scroll"
              >
                <svg class="w-4 h-4 text-gold/80 group-hover/scroll:translate-y-0.5 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                </svg>
                <span>{{ currentLocale.value === 'ar' ? `استعراض الفهرس (${lessons.length} محاضرات)` : `Browse Syllabus (${lessons.length} lectures)` }}</span>
              </button>
            </div>
          </div>
        </aside>

        <!-- ===== Main Content: Curriculum & Lessons (8 cols) ===== -->
        <div id="curriculum-section" class="lg:col-span-8 space-y-6 scroll-mt-24">
          
          <!-- Section Header -->
          <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-white/10">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-2xl bg-gold/20 border border-gold/30 flex items-center justify-center shrink-0">
                <svg class="w-5 h-5 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
              </div>
              <div>
                <h2 class="text-xl sm:text-2xl font-black text-white">{{ $t('tenant.series_title') }}</h2>
                <p class="text-xs text-gray-400">{{ $t('tenant.index_title') }}</p>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <span class="text-xs font-mono text-gold bg-gold/10 px-3 py-1 rounded-xl border border-gold/20 font-bold">
                {{ lessons.length }} {{ $t('tenant.org_entities_count', { count: lessons.length }) }}
              </span>
            </div>
          </div>

          <!-- Empty State -->
          <div v-if="lessons.length === 0" class="text-center py-12">
            <GlassCard>
              <div class="py-8">
                <svg class="w-12 h-12 text-gray-600 mx-auto mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
                <p class="text-gray-400 text-sm">{{ $t('empty.org_desc') }}</p>
              </div>
            </GlassCard>
          </div>

          <!-- High-Impact Sovereign Lesson Modules -->
          <div v-else class="space-y-3.5">
            <div
              v-for="(lesson, i) in lessons"
              :key="lesson.id"
              :id="`lesson-${lesson.id}`"
              class="scroll-mt-28"
            >
              <NuxtLink
                :to="`/${orgSlugParam}/content/${lesson.id}`"
                class="group relative flex flex-col sm:flex-row sm:items-center justify-between gap-4 rounded-2xl sm:rounded-3xl p-4 sm:p-5 bg-white/[0.02] hover:bg-white/[0.05] border border-white/10 hover:border-gold/40 backdrop-blur-xl transition-all duration-300 hover:-translate-y-0.5 hover:shadow-xl hover:shadow-black/60 cursor-pointer"
              >
                <!-- Hover gold glow on start border -->
                <div class="absolute inset-y-0 start-0 w-1 bg-gold rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-300" />

                <!-- Left / Start: Index + Title + Metadata -->
                <div class="flex items-start sm:items-center gap-3.5 sm:gap-4.5 min-w-0">
                  <!-- Number Badge -->
                  <div class="w-12 h-12 rounded-2xl bg-gold/10 border border-gold/20 flex items-center justify-center shrink-0 group-hover:bg-gold group-hover:border-gold transition-all duration-300 shadow-md shadow-black/40">
                    <span class="text-sm sm:text-base font-black font-mono text-gold group-hover:text-onyx transition-colors">
                      {{ paddedIndex(i) }}
                    </span>
                  </div>

                  <!-- Text Details -->
                  <div class="space-y-1.5 min-w-0">
                    <div class="flex items-center gap-2">
                      <span v-if="i === 0" class="inline-flex items-center px-2 py-0.5 rounded-md text-[10px] font-bold font-mono uppercase bg-gold/15 text-gold border border-gold/30 shrink-0">
                        {{ currentLocale.value === 'ar' ? 'البداية' : 'Start Here' }}
                      </span>
                      <h3 class="text-sm sm:text-base font-bold text-white group-hover:text-gold transition-colors duration-200 line-clamp-1">
                        {{ localizedTitle(lesson.title) }}
                      </h3>
                    </div>

                    <div class="flex flex-wrap items-center gap-2 text-xs text-gray-400">
                      <span class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-lg text-[11px] font-medium bg-black/40 border border-white/10">
                        <span>{{ contentTypeIcon(lesson.content_type) }}</span>
                        <span>{{ contentTypeLabel(lesson.content_type) }}</span>
                      </span>
                      <span class="text-gray-600">•</span>
                      <span class="font-mono text-[11px] text-gray-500">{{ lessonDate(lesson) }}</span>
                    </div>
                  </div>
                </div>

                <!-- Right / End: Play Action Capsule -->
                <div class="flex items-center justify-end sm:justify-center shrink-0 pt-2 sm:pt-0 border-t sm:border-t-0 border-white/5">
                  <div class="inline-flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold text-gray-300 group-hover:text-onyx bg-white/5 group-hover:bg-gold border border-white/10 group-hover:border-gold shadow-md transition-all duration-300">
                    <span>{{ currentLocale.value === 'ar' ? 'بدء المحاضرة' : 'Play Lecture' }}</span>
                    <span class="text-xs transition-transform duration-300 group-hover:translate-x-0.5 rtl:group-hover:-translate-x-0.5">
                      {{ currentLocale.value === 'ar' ? '←' : '→' }}
                    </span>
                  </div>
                </div>
              </NuxtLink>
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- ===== Sovereign 4-Column Foundation Footer ===== -->
    <footer class="relative mt-auto border-t border-white/10 bg-[#0A0A0A]/95 backdrop-blur-2xl text-gray-400 overflow-hidden z-20">
      <div class="absolute inset-0 bg-[linear-gradient(to_right,#ffffff03_1px,transparent_1px),linear-gradient(to_bottom,#ffffff03_1px,transparent_1px)] bg-[size:4rem_4rem] pointer-events-none" />

      <div class="relative max-w-7xl mx-auto px-4 sm:px-6 py-12 lg:py-16">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-12 gap-8 lg:gap-12 pb-12 border-b border-white/10">
          
          <!-- Column 1: Organization Identity & Mission (5 cols) -->
          <div class="lg:col-span-5 space-y-4">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-2xl bg-gold/10 border border-gold/30 flex items-center justify-center text-gold font-mono font-black text-lg">
                بُ
              </div>
              <span class="text-xl font-black text-white font-mono tracking-tight">{{ $t('brand.name') }}</span>
              <span class="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold bg-gold/10 text-gold border border-gold/20 uppercase tracking-widest">
                v2.0
              </span>
            </div>

            <p class="text-xs sm:text-sm text-gray-400 max-w-sm leading-relaxed">
              {{ $t('tenant.footer_desc') || $t('brand.tagline') }}
            </p>

            <div class="flex items-center gap-2 pt-2">
              <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
              <span class="text-xs font-mono text-gray-400">
                Burhan Cloud Node • <span class="text-emerald-400 font-semibold">Active & Sovereign</span>
              </span>
            </div>
          </div>

          <!-- Column 2: Navigation & Hub (2 cols) -->
          <div class="lg:col-span-2 space-y-3">
            <h4 class="text-xs font-mono font-bold text-gold uppercase tracking-wider">
              {{ $t('tenant.nav_home') || 'المنصة' }}
            </h4>
            <ul class="space-y-2 text-xs">
              <li>
                <NuxtLink to="/" class="hover:text-gold transition-colors">{{ $t('hub.title') || 'الرئيسية' }}</NuxtLink>
              </li>
              <li>
                <NuxtLink :to="`/${orgSlugParam}`" class="hover:text-gold transition-colors">{{ displayOrgName }}</NuxtLink>
              </li>
              <li>
                <NuxtLink to="/about" class="hover:text-gold transition-colors">{{ $t('nav.about') || 'عن بُرهان' }}</NuxtLink>
              </li>
              <li>
                <NuxtLink to="/observatory" class="hover:text-gold transition-colors">{{ $t('observatory.title') || 'مرصد السيادة' }}</NuxtLink>
              </li>
            </ul>
          </div>

          <!-- Column 3: Legal & Governance (2 cols) -->
          <div class="lg:col-span-2 space-y-3">
            <h4 class="text-xs font-mono font-bold text-gold uppercase tracking-wider">
              {{ $t('footer.charter') || 'السيادة والامتثال' }}
            </h4>
            <ul class="space-y-2 text-xs">
              <li>
                <NuxtLink to="/terms" class="hover:text-gold transition-colors">{{ $t('legal.terms_title') || 'ميثاق الاستخدام' }}</NuxtLink>
              </li>
              <li>
                <NuxtLink to="/privacy" class="hover:text-gold transition-colors">{{ $t('legal.privacy_title') || 'سياسة الخصوصية' }}</NuxtLink>
              </li>
              <li>
                <NuxtLink to="/about" class="hover:text-gold transition-colors">{{ $t('legal.security_title') || 'معايير العزل والمعرفة' }}</NuxtLink>
              </li>
            </ul>
          </div>

          <!-- Column 4: Ecosystem & Connect (3 cols) -->
          <div class="lg:col-span-3 space-y-3">
            <h4 class="text-xs font-mono font-bold text-gold uppercase tracking-wider">
              {{ $t('common.connect') || 'المنظومة والتطوير' }}
            </h4>
            <ul class="space-y-2.5 text-xs">
              <li>
                <a
                  href="https://tools.ainux.online/"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-2 text-gray-300 hover:text-gold transition-colors group"
                >
                  <span class="text-gold">⚡</span>
                  <span class="font-medium">أدوات آينوكس (57 أداة سحابية حرة)</span>
                </a>
              </li>
              <li>
                <a
                  href="https://github.com/Ibrahem3/burhan-platform"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-2 text-gray-300 hover:text-gold transition-colors group"
                >
                  <svg class="w-4 h-4 text-gray-400 group-hover:text-gold transition-colors" fill="currentColor" viewBox="0 0 24 24">
                    <path fill-rule="evenodd" clip-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" />
                  </svg>
                  <span class="font-mono">GitHub Repository</span>
                </a>
              </li>
              <li>
                <button
                  class="inline-flex items-center gap-1.5 text-xs text-gold hover:text-gold-300 bg-gold/5 hover:bg-gold/10 border border-gold/20 px-2.5 py-1 rounded-lg transition-all"
                  @click="toggleLocale()"
                >
                  <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m0 4h.01M21 12l-4 4m0 0l-4-4m4 4V8" />
                  </svg>
                  <span>{{ currentLocale.value === 'ar' ? 'English Language' : 'اللغة العربية' }}</span>
                </button>
              </li>
            </ul>
          </div>
        </div>

        <!-- Centered Sub-Footer Bar -->
        <div class="pt-8 flex flex-col items-center justify-center gap-2 text-center text-xs text-gray-500">
          <div class="flex flex-wrap items-center justify-center gap-x-2 gap-y-1">
            <span>&copy; {{ new Date().getFullYear() }} {{ $t('footer.rights') }}</span>
            <span class="text-gray-700 hidden sm:inline">•</span>
            <span dir="ltr" class="inline-flex items-center gap-1">
              <span>Powered by</span>
              <a
                href="https://ainux.online"
                target="_blank"
                rel="noopener noreferrer"
                class="text-gold hover:underline font-medium"
              >Ainux</a>
            </span>
          </div>

          <p class="text-[11px] text-gray-600 font-mono">
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
