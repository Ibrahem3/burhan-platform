<script setup lang="ts">
interface Props {
  videoId?: string | null
  primarySource?: string
  fallbackSource?: string | null
  fallbackUrl?: string | null
}

const props = withDefaults(defineProps<Props>(), {
  videoId: null,
  primarySource: 'youtube',
  fallbackSource: null,
  fallbackUrl: null,
})

const emit = defineEmits<{
  error: [source: string]
  fallback: []
}>()

type PlayState = 'loading' | 'playing' | 'primary_error' | 'loading_fallback' | 'fallback_error' | 'no_video'

const state = ref<PlayState>('loading')
const iframeKey = ref(0)
const loadTimer = ref<ReturnType<typeof setTimeout> | null>(null)
const FALLBACK_TIMEOUT_MS = 10000

const hasFallback = computed(() => {
  return !!props.fallbackSource || !!props.fallbackUrl
})

const hasVideo = computed(() => {
  return !!props.videoId || !!props.fallbackUrl
})

const youtubeEmbedUrl = computed(() => {
  if (props.primarySource === 'youtube' && props.videoId) {
    return `https://www.youtube.com/embed/${props.videoId}?autoplay=1&rel=0&playsinline=1`
  }
  return null
})

const cloudflareEmbedUrl = computed(() => {
  if (props.fallbackSource === 'cloudflare_stream' && props.videoId) {
    return `https://iframe.videodelivery.net/${props.videoId}?autoplay=true`
  }
  return null
})

const activeUrl = computed(() => {
  if (state.value === 'loading' || state.value === 'playing' || state.value === 'primary_error') {
    return youtubeEmbedUrl.value
  }
  if (state.value === 'loading_fallback') {
    return cloudflareEmbedUrl.value || props.fallbackUrl || null
  }
  return null
})

function startLoadTimer() {
  stopLoadTimer()
  loadTimer.value = setTimeout(() => {
    if (state.value === 'loading') {
      handlePrimaryError()
    }
  }, FALLBACK_TIMEOUT_MS)
}

function stopLoadTimer() {
  if (loadTimer.value) {
    clearTimeout(loadTimer.value)
    loadTimer.value = null
  }
}

function onIframeLoad() {
  stopLoadTimer()
  if (state.value === 'loading') {
    state.value = 'playing'
  } else if (state.value === 'loading_fallback') {
    state.value = 'playing'
  }
}

function handlePrimaryError() {
  stopLoadTimer()
  if (hasFallback.value) {
    state.value = 'loading_fallback'
    emit('error', props.primarySource)
    emit('fallback')
    iframeKey.value++
    startLoadTimer()
  } else {
    state.value = 'primary_error'
    emit('error', props.primarySource)
  }
}

function handleFallbackError() {
  stopLoadTimer()
  state.value = 'fallback_error'
  emit('error', props.fallbackSource || 'fallback')
}

function retryPrimary() {
  state.value = 'loading'
  iframeKey.value++
  startLoadTimer()
}

function switchToFallback() {
  if (hasFallback.value) {
    state.value = 'loading_fallback'
    iframeKey.value++
    startLoadTimer()
    emit('fallback')
  }
}

onMounted(() => {
  if (hasVideo.value) {
    startLoadTimer()
  } else {
    state.value = 'no_video'
  }
})

onUnmounted(() => {
  stopLoadTimer()
})
</script>

<template>
  <div
    class="relative w-full aspect-video rounded-2xl overflow-hidden glass group"
    role="region"
    :aria-label="$t('entities.video')"
  >
    <!-- No video state -->
    <div v-if="state === 'no_video'" class="absolute inset-0 flex flex-col items-center justify-center gap-3 p-8">
      <svg class="w-12 h-12 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
      </svg>
      <p class="text-gray-500 text-sm">{{ $t('video.no_video_title') }}</p>
    </div>

    <!-- Iframe embed -->
    <template v-if="hasVideo && activeUrl">
      <iframe
        :key="iframeKey"
        :src="activeUrl"
        class="absolute inset-0 w-full h-full"
        allow="autoplay; fullscreen; picture-in-picture"
        allowfullscreen
        @load="onIframeLoad"
        @error="state === 'loading_fallback' ? handleFallbackError() : handlePrimaryError()"
      />
    </template>

    <!-- Loading overlay (primary) -->
    <Transition name="fade">
      <div
        v-if="state === 'loading'"
        class="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-onyx/90"
      >
        <div class="w-10 h-10 border-2 border-gold border-t-transparent rounded-full animate-spin" />
        <p class="text-sm text-gray-400">{{ $t('video.loading') }}</p>
      </div>
    </Transition>

    <!-- Primary error: has fallback -->
    <Transition name="fade">
      <div
        v-if="state === 'primary_error'"
        class="absolute inset-0 flex flex-col items-center justify-center gap-4 p-6 bg-onyx/90 text-center"
      >
        <div class="w-14 h-14 rounded-full bg-red-500/10 flex items-center justify-center">
          <svg class="w-6 h-6 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
          </svg>
        </div>
        <div>
          <p class="text-sm text-gray-300 mb-1">{{ $t('video.error_primary') }}</p>
          <p class="text-xs text-gray-500">{{ $t('video.player_fallback_activated') }}</p>
        </div>
        <div class="flex gap-2">
          <Button variant="ghost" size="sm" @click="retryPrimary">
            {{ $t('video.retry') }}
          </Button>
          <Button v-if="hasFallback" variant="outline" size="sm" @click="switchToFallback">
            {{ $t('video.switch_source') }}
          </Button>
        </div>
      </div>
    </Transition>

    <!-- Loading fallback -->
    <Transition name="fade">
      <div
        v-if="state === 'loading_fallback'"
        class="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-onyx/90"
      >
        <div class="w-10 h-10 border-2 border-gold border-t-transparent rounded-full animate-spin" />
        <p class="text-sm text-gray-400">{{ $t('video.loading_fallback') }}</p>
      </div>
    </Transition>

    <!-- All sources exhausted -->
    <Transition name="fade">
      <div
        v-if="state === 'fallback_error'"
        class="absolute inset-0 flex flex-col items-center justify-center gap-4 p-6 bg-onyx/90 text-center"
      >
        <div class="w-14 h-14 rounded-full bg-red-500/10 flex items-center justify-center">
          <svg class="w-6 h-6 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
        <div>
          <p class="text-sm text-gray-300 mb-1">{{ $t('video.error_fallback') }}</p>
          <p class="text-xs text-gray-500">{{ $t('video.player_error') }}</p>
        </div>
        <Button variant="ghost" size="sm" @click="retryPrimary">
          {{ $t('video.retry') }}
        </Button>
      </div>
    </Transition>

    <!-- Top-right status badge -->
    <div
      v-if="state === 'loading_fallback' || state === 'fallback_error'"
      class="absolute top-3 left-3 z-10"
    >
      <Badge variant="warning" size="sm">
        {{ $t('video.switch_source') }}
      </Badge>
    </div>
  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
