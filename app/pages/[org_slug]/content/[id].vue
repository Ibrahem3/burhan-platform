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

const entityId = route.params.id as string
const orgSlugParam = route.params.org_slug as string

const entity = ref<any>(null)
const series = ref<any>(null)
const loading = ref(true)
const notFound = ref(false)

const pageTitle = computed(() => {
  if (!entity.value) return ''
  const title = entity.value.title as Record<string, string>
  return title[locale.value] || title.ar || title.en || ''
})

useHead({
  title: pageTitle,
})

async function fetchData() {
  loading.value = true
  notFound.value = false

  await fetchOrg(orgSlugParam)

  const { data: eData } = await supabase
    .from('entities')
    .select('*')
    .eq('id', entityId)
    .single()

  if (!eData) {
    notFound.value = true
    loading.value = false
    return
  }

  entity.value = eData

  if (eData.series_id) {
    const { data: sData } = await supabase
      .from('series')
      .select('*')
      .eq('id', eData.series_id)
      .single()
    if (sData) series.value = sData
  }

  loading.value = false
}

watch(() => route.params.id, fetchData, { immediate: true })

function localizedTitle(obj: Json): string {
  const t = obj as Record<string, string>
  return t[locale.value] || t.ar || t.en || ''
}

function localizedContent(obj: Json): string {
  const c = obj as Record<string, string>
  return c[locale.value] || c.ar || c.en || ''
}

function seriesTitle(): string {
  if (!series.value) return ''
  const t = series.value.title as Record<string, string>
  return t[locale.value] || t.ar || t.en || ''
}

function orgDisplayName(): string {
  if (!org.value?.name) return ''
  const name = org.value.name as Record<string, string>
  return name[locale.value] || name.ar || name.en || ''
}

function readingTime(): string {
  if (!entity.value) return ''
  const content = localizedContent(entity.value!.title as Json) + ' ' + localizedContent(entity.value!.content as Json)
  const wordCount = content.split(/\s+/).filter(Boolean).length
  const minutes = Math.max(1, Math.ceil(wordCount / 200))
  return t('entities.reading_time', { minutes })
}

function formattedDate(): string {
  if (!entity.value) return ''
  return new Date(entity.value.created_at).toLocaleDateString(
    currentLocale === 'ar' ? 'ar-SA' : 'en-US',
    { year: 'numeric', month: 'long', day: 'numeric' },
  )
}

function contentTypeBadgeVariant(): string {
  if (!entity.value) return 'default'
  if (entity.value.content_type === 'video') return 'info'
  if (entity.value.content_type === 'audio') return 'warning'
  return 'default'
}

function contentTypeIcon(): string {
  if (!entity.value) return '📄'
  if (entity.value.content_type === 'video') return '🎥'
  if (entity.value.content_type === 'audio') return '🎙️'
  return '📝'
}

function contentTypeLabel(): string {
  if (!entity.value) return ''
  if (entity.value.content_type === 'video') return t('entities.video')
  if (entity.value.content_type === 'audio') return t('dashboard.type_audio')
  return t('entities.article')
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

    <!-- Loading -->
    <div v-if="loading" class="min-h-[70vh] flex items-center justify-center">
      <div class="text-center">
        <div class="w-12 h-12 border-2 border-gold/30 border-t-gold rounded-full animate-spin mx-auto mb-4" />
        <p class="text-gray-500">{{ $t('tenant.loading_org') }}</p>
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

    <!-- Main content -->
    <main v-else-if="entity" id="main-content" class="flex-1">
      <!-- ===== Video Player ===== -->
      <div v-if="entity.content_type === 'video'" class="max-w-5xl mx-auto px-6 pt-10 pb-8">
        <div class="aspect-video rounded-2xl overflow-hidden glass border border-white/5 shadow-xl">
          <iframe
            v-if="entity.video_id"
            :src="`https://www.youtube.com/embed/${entity.video_id}?autoplay=1&rel=0`"
            class="w-full h-full"
            frameborder="0"
            allow="autoplay; encrypted-media; fullscreen"
            allowfullscreen
          />
          <div v-else class="w-full h-full flex items-center justify-center bg-white/5">
            <p class="text-gray-500">{{ $t('video.no_video') }}</p>
          </div>
        </div>
      </div>

      <!-- ===== Audio Player ===== -->
      <div v-else-if="entity.content_type === 'audio'" class="max-w-5xl mx-auto px-6 pt-10 pb-8">
        <GlassCard>
          <div class="p-8">
            <div class="flex flex-col items-center gap-6">
              <div class="w-24 h-24 rounded-full bg-gradient-to-br from-purple-900/40 via-gray-800 to-indigo-900/40 flex items-center justify-center">
                <svg class="w-12 h-12 text-purple-400" viewBox="0 0 200 80" fill="none">
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
              <div class="text-center">
                <p class="text-sm text-gray-400 mb-1">{{ contentTypeLabel() }}</p>
                <p v-if="entity.audio_url" class="text-xs text-gray-500">
                  <a :href="entity.audio_url" target="_blank" rel="noopener" class="text-gold hover:underline">
                    {{ $t('video.listen_external') || 'External Link' }}
                  </a>
                </p>
                <p v-else-if="entity.audio_file" class="text-xs text-gray-500">
                  <a :href="entity.audio_file" target="_blank" rel="noopener" class="text-gold hover:underline">
                    {{ $t('video.download_audio') || 'Download Audio' }}
                  </a>
                </p>
              </div>
            </div>
          </div>
        </GlassCard>
      </div>

      <!-- ===== Article: Focused Reader Mode ===== -->
      <article class="max-w-3xl mx-auto px-6 py-12">
        <!-- Back link -->
        <div class="mb-8">
          <NuxtLink
            :to="series ? `/${orgSlugParam}/series/${entity.series_id}` : `/${orgSlugParam}`"
            class="inline-flex items-center gap-2 px-4 py-2 glass backdrop-blur-xl rounded-xl border border-white/5 text-sm text-gray-400 hover:text-gold hover:border-gold/30 transition-all duration-300"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
            {{ series ? seriesTitle() : $t('tenant.back_to_org') }}
          </NuxtLink>
        </div>

        <!-- Header -->
        <header class="text-center mb-10">
          <div class="flex items-center justify-center gap-2 mb-4">
            <Badge :variant="contentTypeBadgeVariant()" size="sm">
              <span class="flex items-center gap-1">
                <span>{{ contentTypeIcon() }}</span>
                <span>{{ contentTypeLabel() }}</span>
              </span>
            </Badge>
            <Badge v-if="entity.is_premium" variant="premium" size="sm">
              {{ $t('entities.premium') }}
            </Badge>
          </div>

          <h1 class="text-2xl sm:text-3xl lg:text-4xl font-bold text-white leading-tight mb-5 text-balance">
            <span class="gradient-gold">{{ localizedTitle(entity.title) }}</span>
          </h1>

          <div class="flex items-center justify-center gap-2 text-xs text-gray-500 flex-wrap">
            <span>📅 {{ formattedDate() }}</span>
            <span class="text-gold/40">•</span>
            <span>⏱️ {{ readingTime() }}</span>
            <span v-if="orgDisplayName()" class="text-gold/40">•</span>
            <span v-if="orgDisplayName()">✍️ {{ orgDisplayName() }}</span>
          </div>

          <div class="mt-8 w-24 h-0.5 mx-auto bg-gradient-to-r from-transparent via-gold/50 to-transparent rounded-full" />
        </header>

        <!-- Article body -->
        <div
          v-if="entity.content_type === 'article' && entity.content"
          class="prose-gold max-w-none"
          :class="currentLocale === 'ar' ? 'text-right' : 'text-left'"
          v-html="localizedContent(entity.content)"
        />

        <!-- Video description -->
        <div v-else-if="entity.content && localizedContent(entity.content)" class="text-gray-400 leading-relaxed text-sm space-y-4 text-center">
          <div class="w-24 h-0.5 mx-auto bg-gradient-to-r from-transparent via-gold/30 to-transparent rounded-full" />
          <p class="max-w-xl mx-auto">{{ localizedContent(entity.content) }}</p>
        </div>

        <!-- Footer action -->
        <div v-if="series" class="mt-16 text-center">
          <NuxtLink :to="`/${orgSlugParam}/series/${entity.series_id}`">
            <button
              class="inline-flex items-center justify-center font-medium transition-all duration-300 rounded-xl px-8 py-3.5 text-base bg-gold text-onyx hover:bg-gold-500 active:bg-gold-600 shadow-lg shadow-gold/20 gap-2"
            >
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
              {{ $t('tenant.back_to_course') }}
            </button>
          </NuxtLink>
        </div>
      </article>
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

<style>
.prose-gold {
  font-size: 1.125rem;
  line-height: 1.9;
  color: #d1d5db;
}
.prose-gold div,
.prose-gold p {
  margin-bottom: 1.5rem;
  line-height: 1.9;
  color: #d1d5db;
}
.prose-gold h2 {
  @apply text-white font-bold text-2xl mt-12 mb-4;
}
.prose-gold h3 {
  @apply text-white font-bold text-xl mt-10 mb-3;
}
.prose-gold a {
  @apply text-gold underline decoration-gold/30 underline-offset-4 transition-all duration-200;
}
.prose-gold a:hover {
  @apply decoration-gold/70;
}
.prose-gold ul {
  list-style: disc;
  padding-left: 1.5rem;
  margin-bottom: 1.5rem;
  color: #d1d5db;
}
.prose-gold ul li {
  margin-bottom: 0.375rem;
}
.prose-gold ol {
  list-style: decimal;
  padding-left: 1.5rem;
  margin-bottom: 1.5rem;
  color: #d1d5db;
}
.prose-gold ol li {
  margin-bottom: 0.375rem;
}
.prose-gold blockquote {
  border-inline-start: 3px solid rgba(212, 175, 55, 0.3);
  padding-inline-start: 1.25rem;
  margin: 1.5rem 0;
  font-style: italic;
  font-size: 1rem;
  color: #9ca3af;
}
.prose-gold img {
  @apply rounded-2xl my-10 mx-auto max-w-full h-auto;
}
.prose-gold hr {
  @apply border-white/5 my-12;
}
.prose-gold strong {
  @apply text-white font-semibold;
}
.prose-gold em {
  font-style: italic;
}
.prose-gold u {
  text-decoration: underline;
}
.prose-gold s {
  text-decoration: line-through;
}
.prose-gold code {
  @apply bg-white/5 px-2 py-0.5 rounded text-sm;
  color: #fcd34d;
}
.prose-gold pre {
  @apply bg-white/5 rounded-2xl p-5 overflow-x-auto border border-white/5 my-6;
  font-size: 0.875rem;
  line-height: 1.7;
}
.prose-gold pre code {
  background: none;
  padding: 0;
  color: inherit;
}
.prose-gold table {
  @apply w-full border-collapse my-8;
}
.prose-gold th {
  @apply border border-white/10 px-4 py-2 text-white font-semibold text-sm;
  background: rgba(255, 255, 255, 0.03);
}
.prose-gold td {
  @apply border border-white/10 px-4 py-2 text-sm;
  color: #d1d5db;
}
.prose-gold iframe {
  @apply rounded-2xl my-8 mx-auto max-w-full;
}

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
