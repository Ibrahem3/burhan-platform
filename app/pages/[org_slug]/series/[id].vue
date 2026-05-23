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
    currentLocale === 'ar' ? 'ar-SA' : 'en-US',
    { year: 'numeric', month: 'short', day: 'numeric' },
  )
}

function paddedIndex(i: number): string {
  return String(i + 1).padStart(2, '0')
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

    <!-- Navbar -->
    <header class="sticky top-0 z-50 glass border-b border-white/5">
      <div class="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
        <div class="flex items-center gap-3 min-w-0">
          <NuxtLink
            to="/"
            class="text-xl font-bold gradient-gold whitespace-nowrap hover:opacity-80 transition-opacity shrink-0"
          >
            بُرهان
          </NuxtLink>
          <svg class="w-4 h-4 text-gray-600 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path v-if="currentLocale === 'ar'" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            <path v-else stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
          <NuxtLink :to="`/${orgSlugParam}`" class="flex items-center gap-2 min-w-0 hover:opacity-80 transition-opacity">
            <span class="text-sm font-semibold text-white truncate hover:text-gold transition-colors">
              {{ localizedValue(orgName, currentLocale) }}
            </span>
          </NuxtLink>
        </div>

        <nav class="hidden md:flex items-center gap-1">
          <button
            class="px-3 py-2 text-xs font-medium text-gray-400 hover:text-gold transition-colors rounded-lg hover:bg-white/5 tracking-wider"
            @click="toggleLocale()"
          >
            {{ currentLocale === 'ar' ? 'EN' : 'AR' }}
          </button>
        </nav>

        <button
          class="md:hidden p-2 text-gray-400 hover:text-white transition-colors rounded-lg hover:bg-white/5"
          @click="menuOpen = !menuOpen"
        >
          <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path v-if="!menuOpen" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
            <path v-else stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    </header>

    <!-- Mobile menu -->
    <Transition name="slide-down">
      <div v-if="menuOpen" class="md:hidden border-b border-white/5 glass">
        <nav class="px-4 py-4 space-y-1">
          <NuxtLink
            to="/"
            class="block px-3 py-2.5 text-sm rounded-lg hover:bg-white/5 transition-colors"
            :class="route.path === '/' ? 'text-gold bg-gold/5' : 'text-gray-400 hover:text-white'"
            @click="menuOpen = false"
          >
            {{ $t('nav.home') }}
          </NuxtLink>
          <button
            class="w-full text-right px-3 py-2.5 text-sm rounded-lg text-gray-400 hover:text-white hover:bg-white/5 transition-colors"
            @click="toggleLocale(); menuOpen = false"
          >
            {{ currentLocale === 'ar' ? 'English' : 'العربية' }}
          </button>
        </nav>
      </div>
    </Transition>

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
      <!-- Back -->
      <div class="max-w-7xl mx-auto px-6 pt-8 pb-2">
        <NuxtLink
          :to="`/${orgSlugParam}`"
          class="inline-flex items-center gap-2 text-sm text-gray-500 hover:text-gold transition-colors"
        >
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
          {{ $t('tenant.back_to_org') }}
        </NuxtLink>
      </div>

      <!-- Two-Column Layout -->
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 max-w-7xl mx-auto px-6 py-8 pb-20">
        <!-- ===== Sidebar (4 cols) ===== -->
        <aside class="lg:col-span-4 lg:sticky lg:top-8 lg:self-start space-y-6">
          <div class="aspect-video lg:aspect-[4/3] rounded-2xl overflow-hidden bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 border border-white/5 shadow-xl">
            <img
              v-if="series.cover_url"
              :src="series.cover_url"
              :alt="pageTitle"
              class="w-full h-full object-cover"
            />
            <div v-else class="w-full h-full flex items-center justify-center">
              <svg class="w-20 h-20 text-gold/30" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
            </div>
          </div>

          <div class="glass rounded-2xl p-6 border border-white/5 space-y-5">
            <div>
              <h1 class="text-2xl lg:text-3xl font-bold text-white leading-tight">
                <span class="gradient-gold">{{ pageTitle }}</span>
              </h1>
              <p v-if="series.description && localizedDescription(series.description)" class="text-sm text-gray-400 mt-3 leading-relaxed">
                {{ localizedDescription(series.description) }}
              </p>
            </div>

            <div class="flex flex-wrap items-center gap-2">
              <Badge v-if="branchName()" variant="info" size="sm">
                {{ branchName() }}
              </Badge>
              <Badge variant="premium" size="sm">
                {{ $t('tenant.series_badge') }}
              </Badge>
              <span class="text-xs text-gray-600 font-mono">
                {{ lessons.length }} {{ $t('tenant.org_entities_count', { count: lessons.length }) }}
              </span>
            </div>

            <div v-if="lessons.length > 0">
              <a :href="`#lesson-${lessons[0].id}`">
                <button
                  class="w-full inline-flex items-center justify-center font-medium transition-all duration-300 rounded-xl px-6 py-3.5 text-base bg-gold text-onyx hover:bg-gold-500 active:bg-gold-600 shadow-lg shadow-gold/20 gap-2"
                >
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  {{ $t('tenant.hero_cta') }}
                </button>
              </a>
            </div>
          </div>
        </aside>

        <!-- ===== Main Content (8 cols) ===== -->
        <div class="lg:col-span-8 space-y-6">
          <!-- Section header -->
          <div class="flex items-center gap-3 mb-2">
            <div class="w-10 h-10 rounded-xl bg-gold/20 flex items-center justify-center shrink-0">
              <svg class="w-5 h-5 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
            </div>
            <div>
              <h2 class="text-xl lg:text-2xl font-bold text-white">{{ $t('tenant.series_title') }}</h2>
              <p class="text-xs text-gray-500">{{ $t('tenant.index_title') }}</p>
            </div>
          </div>

          <!-- Empty -->
          <div v-if="lessons.length === 0" class="text-center py-12">
            <GlassCard>
              <div class="py-6">
                <svg class="w-10 h-10 text-gray-600 mx-auto mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                </svg>
                <p class="text-gray-500 text-sm">{{ $t('empty.org_desc') }}</p>
              </div>
            </GlassCard>
          </div>

          <!-- Lesson rows -->
          <div v-else class="space-y-4">
            <div
              v-for="(lesson, i) in lessons"
              :key="lesson.id"
              :id="`lesson-${lesson.id}`"
              class="scroll-mt-24"
            >
              <NuxtLink
                :to="`/${orgSlugParam}/content/${lesson.id}`"
                class="group flex items-center gap-4 glass backdrop-blur-md rounded-2xl p-5 border border-white/5 hover:border-gold/30 transition-all duration-500 hover:shadow-glow hover:scale-[1.01]"
              >
                <!-- Number badge -->
                <div class="w-12 h-12 rounded-xl bg-gold/10 flex items-center justify-center shrink-0 group-hover:bg-gold/20 group-hover:scale-110 transition-all duration-300">
                  <span class="text-base font-bold text-gold/80 group-hover:text-gold transition-colors">
                    {{ paddedIndex(i) }}
                  </span>
                </div>

                <!-- Content -->
                <div class="flex-1 min-w-0 space-y-1">
                  <h3 class="text-sm font-semibold text-white group-hover:text-gold transition-colors line-clamp-1">
                    {{ localizedTitle(lesson.title) }}
                  </h3>
                  <div class="flex items-center gap-2 text-xs text-gray-500">
                    <Badge
                      :variant="lesson.content_type === 'video' ? 'info' : lesson.content_type === 'audio' ? 'warning' : 'default'"
                      size="sm"
                    >
                      <span class="flex items-center gap-1">
                        <span>{{ contentTypeIcon(lesson.content_type) }}</span>
                        <span>{{ contentTypeLabel(lesson.content_type) }}</span>
                      </span>
                    </Badge>
                    <span class="text-gray-600">•</span>
                    <span>{{ lessonDate(lesson) }}</span>
                  </div>
                </div>

                <!-- Arrow -->
                <div class="w-10 h-10 rounded-xl bg-gold/5 flex items-center justify-center shrink-0 group-hover:bg-gold/20 group-hover:scale-110 transition-all duration-300">
                  <svg class="w-5 h-5 text-gray-500 group-hover:text-gold transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                  </svg>
                </div>
              </NuxtLink>
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- Footer -->
    <footer class="border-t border-white/5 glass mt-auto">
      <div class="max-w-7xl mx-auto px-4 py-8">
        <div class="text-center">
          <span class="text-lg font-bold gradient-gold">{{ $t('brand.name') }}</span>
          <p class="text-xs text-gray-600 mt-2">
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
