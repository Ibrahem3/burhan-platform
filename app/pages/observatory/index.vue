<script setup lang="ts">
import type { Database } from '~/types/database'

definePageMeta({
  title: 'Digital Observatory',
})

const { t, locale } = useI18n()
const supabase = useSupabaseClient<Database>()
const config = useRuntimeConfig()
const turnstileSiteKey = config.public.turnstile?.siteKey || ''

useHead({
  script: [
    { src: 'https://challenges.cloudflare.com/turnstile/v0/api.js', async: true, defer: true }
  ]
})

const title = ref('')
const sourceUrl = ref('')
const submitting = ref(false)
const submitted = ref(false)
const submitError = ref('')
const turnstileWidgetId = ref<string | null>(null)

// New UI state (additive, doesn't touch existing submission logic)
const dangerLevel = ref<'Low' | 'Medium' | 'High'>('Medium')
const threatType = ref('')
const spreadLevel = ref(3)

const spreadLabels = [
  { value: 1, label: 'شفتها بالصدفة', en: 'Stumbled upon it' },
  { value: 2, label: 'قليلة', en: 'Rarely seen' },
  { value: 3, label: 'متوسطة', en: 'Moderate spread' },
  { value: 4, label: 'منتشرة', en: 'Widespread' },
  { value: 5, label: 'تريند - الكل بيتكلم عنها', en: 'Trending — everywhere' },
]

const threatTypes = [
  { id: 'تشكيك في الثوابت', en: 'Doubting fundamentals', icon: 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z' },
  { id: 'طعن في السنة', en: 'Attack on Sunnah', icon: 'M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z' },
  { id: 'تحريف معاني', en: 'Distortion of meanings', icon: 'M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01' },
  { id: 'حملة مموهة', en: 'Covert campaign', icon: 'M13 10V3L4 14h7v7l9-11h-7z' },
]

const platformIcon = computed(() => {
  if (!sourceUrl.value) return ''
  const url = sourceUrl.value.toLowerCase()
  if (url.includes('tiktok')) return 'M4.869 0h.088l4.52 2.668-4.52 2.664h-.088L0 2.668 4.869 0z'
  if (url.includes('youtube') || url.includes('youtu.be')) return 'M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z'
  if (url.includes('facebook')) return 'M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z'
  if (url.includes('x.com') || url.includes('twitter')) return 'M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z'
  if (url.includes('instagram')) return 'M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 1 0 0 12.324 6.162 6.162 0 0 0 0-12.324zM12 16a4 4 0 1 1 0-8 4 4 0 0 1 0 8zm6.406-11.845a1.44 1.44 0 1 0 0 2.881 1.44 1.44 0 0 0 0-2.881z'
  if (url.includes('telegram')) return 'M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z'
  return ''
})

const platformName = computed(() => {
  const url = sourceUrl.value.toLowerCase()
  if (url.includes('tiktok')) return t('observatory.platform_tiktok')
  if (url.includes('youtube') || url.includes('youtu.be')) return t('observatory.platform_youtube')
  if (url.includes('facebook')) return t('observatory.platform_facebook')
  if (url.includes('x.com') || url.includes('twitter')) return t('observatory.platform_x')
  if (url.includes('instagram')) return t('observatory.platform_instagram')
  if (url.includes('telegram')) return t('observatory.platform_telegram')
  return ''
})

const isTikTok = computed(() => sourceUrl.value.toLowerCase().includes('tiktok'))

const neutralizedThreats = ref<any[]>([])
const loadingFeed = ref(true)

async function fetchDefenseFeed() {
  loadingFeed.value = true
  try {
    const { data } = await supabase
      .from('observatory_threats')
      .select('id, title, source_url, platform, danger_level, response_url, created_at')
      .eq('status', 'neutralized')
      .order('created_at', { ascending: false })
      .limit(20)

    neutralizedThreats.value = data || []
  } finally {
    loadingFeed.value = false
  }
}

async function handleSubmit() {
  if (!title.value || !sourceUrl.value) return

  submitting.value = true
  submitError.value = ''

  let token = ''
  if (process.client) {
    const turnstile = (window as any).turnstile
    if (turnstile) {
      token = turnstile.getResponse() || ''
    }
    if (!token) {
      const input = document.querySelector('[name="cf-turnstile-response"]') as HTMLInputElement
      if (input) token = input.value
    }
  }

  try {
    const result = await $fetch<{ success: boolean; threat: any }>('/api/observatory/report', {
      method: 'POST',
      body: {
        title: title.value,
        sourceUrl: sourceUrl.value,
        turnstileToken: token,
      },
    })

    if (!result?.success) {
      submitError.value = t('observatory.form_error')
      return
    }

    submitted.value = true
    title.value = ''
    sourceUrl.value = ''
    dangerLevel.value = 'Medium'
    threatType.value = ''
    spreadLevel.value = 3
  } catch (err: any) {
    if (err.statusCode === 429) {
      submitError.value = t('observatory.form_rate_limit')
    } else {
      submitError.value = t('observatory.form_error')
    }
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  fetchDefenseFeed()
})

const dangerBadge = (level: string) => {
  const map: Record<string, string> = {
    Low: 'bg-green-500/20 text-green-400 border-green-500/30',
    Medium: 'bg-amber-500/20 text-amber-400 border-amber-500/30',
    High: 'bg-red-500/20 text-red-400 border-red-500/30',
  }
  return map[level] || map.Medium
}

const dangerLabel = (level: string) => {
  const map: Record<string, string> = {
    Low: t('observatory.danger_low'),
    Medium: t('observatory.danger_medium'),
    High: t('observatory.danger_high'),
  }
  return map[level] || level
}

const platformBadgeClass = (platform: string) => {
  const map: Record<string, string> = {
    tiktok: 'bg-pink-500/20 text-pink-400 border-pink-500/30',
    youtube: 'bg-red-500/20 text-red-400 border-red-500/30',
    facebook: 'bg-blue-500/20 text-blue-400 border-blue-500/30',
    x: 'bg-gray-400/20 text-gray-300 border-gray-400/30',
    instagram: 'bg-purple-500/20 text-purple-400 border-purple-500/30',
    telegram: 'bg-sky-500/20 text-sky-400 border-sky-500/30',
    other: 'bg-white/10 text-gray-300 border-white/10',
  }
  return map[platform] || map.other
}
</script>

<template>
  <div class="min-h-[calc(100vh-4rem)] relative overflow-hidden" :dir="locale === 'ar' ? 'rtl' : 'ltr'">
    <!-- Radar / Network Grid Overlay -->
    <div class="absolute inset-0 pointer-events-none overflow-hidden">
      <!-- Subtle scan-line effect -->
      <div class="absolute inset-0 opacity-[0.015]" style="background-image: repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(255,255,255,0.03) 2px, rgba(255,255,255,0.03) 4px);" />

      <!-- Grid pattern -->
      <svg class="absolute inset-0 w-full h-full opacity-[0.04]" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="intel-grid" width="60" height="60" patternUnits="userSpaceOnUse">
            <path d="M 60 0 L 0 0 0 60" fill="none" stroke="currentColor" stroke-width="0.4" class="text-gold" />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#intel-grid)" />
      </svg>

      <!-- Radar pulse ring -->
      <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2">
        <div class="w-[600px] h-[600px] rounded-full border border-gold/5 animate-ping-slow" />
        <div class="w-[400px] h-[400px] rounded-full border border-gold/10 animate-ping-slower absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2" />
        <div class="w-[200px] h-[200px] rounded-full border border-gold/20 animate-ping-slowest absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2" />
      </div>

      <!-- Ambient glows -->
      <div class="absolute top-1/4 -left-40 w-[500px] h-[500px] bg-red-500/5 rounded-full blur-3xl" />
      <div class="absolute bottom-1/3 -right-40 w-[400px] h-[400px] bg-gold/3 rounded-full blur-3xl" />
    </div>

    <div class="relative max-w-4xl mx-auto px-4 py-8 sm:py-14">
      <!-- Header: Military / War-Room Branding -->
      <div class="text-center mb-10">
        <div class="inline-flex items-center gap-2 px-4 py-1.5 mb-4 border border-gold/20 rounded-full bg-gold/5 text-xs text-gold/70 font-mono tracking-widest uppercase">
          <span class="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse" />
          {{ $t('observatory.classification') || 'FIELD REPORT — PRIORITY INTAKE' }}
        </div>
        <h1 class="text-2xl sm:text-3xl lg:text-4xl font-bold text-white mb-3 leading-tight">
          <span class="text-gold">منظومة رصد الشبهات</span><br />
          <span class="text-sm sm:text-base lg:text-lg text-gray-400 font-normal tracking-wider">والتهديدات الفكرية</span>
        </h1>
        <p class="text-sm sm:text-base text-gray-500 max-w-xl mx-auto leading-relaxed">
          ارفع بلاغك الميداني فوراً لغرفة العمليات المركزية. ساهم في سد الثغر.
        </p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 lg:gap-8">
        <!-- === Intake Form (left / top) === -->
        <section>
          <div
            class="rounded-2xl border border-white/[0.06] p-6 sm:p-8"
            style="background: rgba(10, 10, 10, 0.85); backdrop-filter: blur(24px); box-shadow: inset 0 1px 0 rgba(255,255,255,0.03), 0 8px 32px rgba(0,0,0,0.4);"
          >
            <!-- Section label -->
            <div class="flex items-center gap-2 mb-6 pb-4 border-b border-white/5">
              <div class="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
              <span class="text-[10px] font-mono text-gray-500 uppercase tracking-[0.2em]">Digital Intake Grid — نموذج البلاغ</span>
            </div>

            <form v-if="!submitted" novalidate @submit.prevent="handleSubmit" class="space-y-6">

              <!-- === Link Input (source_url) with Platform Badge === -->
              <div>
                <label class="block text-xs font-mono text-gray-500 uppercase tracking-wider mb-2">
                  {{ $t('observatory.form_url') }} <span class="text-red-400">*</span>
                </label>
                <div class="relative">
                  <input
                    v-model="sourceUrl"
                    type="url"
                    placeholder="https://www.tiktok.com/@..."
                    class="w-full px-4 py-3 bg-black/40 border rounded-xl text-white placeholder-gray-700 focus:outline-none focus:border-red-500/50 focus:ring-1 focus:ring-red-500/20 transition-all duration-200 font-mono text-sm tracking-wide"
                    :class="isTikTok ? 'border-red-500/40 ring-1 ring-red-500/20' : 'border-white/10'"
                    :disabled="submitting"
                    required
                  />

                  <!-- Platform detection badge inside input -->
                  <div
                    v-if="platformName"
                    class="absolute inset-y-0 inline-flex items-center gap-1.5 px-2.5 text-[11px] font-mono font-medium rounded-lg"
                    :class="[
                      isTikTok ? 'bg-red-500/15 text-red-400 border border-red-500/30' : 'bg-white/5 text-gray-400 border border-white/10',
                      locale === 'ar' ? 'left-2' : 'right-2',
                    ]"
                    style="top: 50%; transform: translateY(-50%); pointer-events: none;"
                  >
                    <svg v-if="platformIcon" class="w-3.5 h-3.5" :class="isTikTok ? 'text-red-400' : ''" fill="currentColor" viewBox="0 0 24 24">
                      <path :d="platformIcon" />
                    </svg>
                    {{ platformName }}
                    <span v-if="isTikTok" class="text-[9px] text-red-400 font-bold tracking-wider">HIGH ALERT</span>
                  </div>
                </div>
              </div>

              <!-- === Threat Classification (Danger Level) === -->
              <div>
                <label class="block text-xs font-mono text-gray-500 uppercase tracking-wider mb-2">
                  تصنيف التهديد الفكري <span class="text-red-400">*</span>
                </label>
                <div class="flex gap-2">
                  <button
                    v-for="level in ['Low', 'Medium', 'High'] as const"
                    :key="level"
                    type="button"
                    class="flex-1 py-2.5 rounded-xl text-xs font-mono font-bold tracking-wider border transition-all duration-200"
                    :class="dangerLevel === level
                      ? level === 'Low' ? 'bg-green-500/20 text-green-400 border-green-500/50 shadow-lg shadow-green-500/10'
                        : level === 'Medium' ? 'bg-amber-500/20 text-amber-400 border-amber-500/50 shadow-lg shadow-amber-500/10'
                        : 'bg-red-500/20 text-red-400 border-red-500/50 shadow-lg shadow-red-500/10'
                      : 'bg-black/40 text-gray-600 border-white/5 hover:border-white/20 hover:text-gray-400'"
                    @click="dangerLevel = level"
                  >
                    <span v-if="level === 'Low'">● LOW</span>
                    <span v-else-if="level === 'Medium'">●● MEDIUM</span>
                    <span v-else>●●● HIGH</span>
                  </button>
                </div>
              </div>

              <!-- === Threat Type Tags === -->
              <div>
                <label class="block text-xs font-mono text-gray-500 uppercase tracking-wider mb-2">
                  نوع التهديد <span class="text-red-400">*</span>
                </label>
                <div class="grid grid-cols-2 gap-2">
                  <button
                    v-for="type in threatTypes"
                    :key="type.id"
                    type="button"
                    class="flex items-center gap-2 px-3 py-2.5 rounded-xl text-xs font-medium border transition-all duration-200 text-left"
                    :class="threatType === type.id
                      ? 'bg-red-500/15 text-red-300 border-red-500/40 shadow-sm shadow-red-500/10'
                      : 'bg-black/40 text-gray-500 border-white/5 hover:border-white/20 hover:text-gray-300'"
                    @click="threatType = type.id"
                  >
                    <svg class="w-3.5 h-3.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path :d="type.icon" stroke-linecap="round" stroke-linejoin="round" />
                    </svg>
                    <span class="leading-tight">{{ type.id }}</span>
                  </button>
                </div>
              </div>

              <!-- === Context / Description (existing title field) === -->
              <div>
                <label class="block text-xs font-mono text-gray-500 uppercase tracking-wider mb-2">
                  {{ $t('observatory.form_title') }} <span class="text-red-400">*</span>
                </label>
                <textarea
                  v-model="title"
                  rows="3"
                  :placeholder="$t('observatory.form_title_placeholder')"
                  class="w-full px-4 py-3 bg-black/40 border border-white/10 rounded-xl text-white placeholder-gray-700 focus:outline-none focus:border-red-500/50 focus:ring-1 focus:ring-red-500/20 transition-all duration-200 resize-none text-sm"
                  :disabled="submitting"
                  required
                />
              </div>

              <!-- === Spread Range Slider (NEW) === -->
              <div>
                <label class="block text-xs font-mono text-gray-500 uppercase tracking-wider mb-3">
                  مدى انتشار الشبهة بصرياً
                </label>
                <div class="px-1">
                  <input
                    v-model.number="spreadLevel"
                    type="range"
                    min="1"
                    max="5"
                    step="1"
                    class="w-full h-1.5 rounded-full appearance-none cursor-pointer"
                    :style="{
                      background: `linear-gradient(to right, rgba(239,68,68,0.3) 0%, rgba(239,68,68,0.8) ${(spreadLevel-1)*25}%, rgba(255,255,255,0.08) ${(spreadLevel-1)*25}%, rgba(255,255,255,0.08) 100%)`,
                      accentColor: '#ef4444',
                    }"
                  />
                  <div class="flex justify-between mt-2">
                    <span class="text-[10px] font-mono text-gray-600">1 — {{ locale === 'ar' ? spreadLabels[0].label : spreadLabels[0].en }}</span>
                    <span class="text-[10px] font-mono text-gray-600">5 — {{ locale === 'ar' ? spreadLabels[4].label : spreadLabels[4].en }}</span>
                  </div>
                  <div class="mt-3 text-center">
                    <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-mono font-bold"
                      :class="spreadLevel <= 2 ? 'bg-green-500/10 text-green-400' : spreadLevel <= 3 ? 'bg-amber-500/10 text-amber-400' : 'bg-red-500/15 text-red-400'"
                    >
                      <span class="w-1.5 h-1.5 rounded-full" :class="spreadLevel <= 2 ? 'bg-green-500' : spreadLevel <= 3 ? 'bg-amber-500' : 'bg-red-500'" />
                      المستوى {{ spreadLevel }} — {{ (locale === 'ar' ? spreadLabels[spreadLevel - 1].label : spreadLabels[spreadLevel - 1].en) }}
                    </span>
                  </div>
                </div>
              </div>

              <!-- === Error === -->
              <div v-if="submitError" class="text-red-400 text-xs font-mono text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
                {{ submitError }}
              </div>

              <!-- === Turnstile === -->
              <div v-if="turnstileSiteKey" class="flex justify-center">
                <div class="cf-turnstile" :data-sitekey="turnstileSiteKey" />
              </div>

              <!-- === Submit Button (Red, Glowing) === -->
              <div class="relative group">
                <div class="absolute -inset-1 bg-gradient-to-r from-red-600/0 via-red-600/20 to-red-600/0 rounded-2xl blur-xl opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
                <button
                  type="submit"
                  :disabled="submitting"
                  class="relative w-full py-3.5 rounded-xl font-bold text-sm tracking-wider border transition-all duration-300"
                  :class="submitting
                    ? 'bg-red-500/50 text-red-200 border-red-500/30 cursor-not-allowed'
                    : 'bg-red-600 text-white border-red-500/50 hover:bg-red-500 hover:shadow-lg hover:shadow-red-500/25 active:scale-[0.98]'"
                >
                  <span v-if="submitting" class="inline-flex items-center gap-2">
                    <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                    </svg>
                    {{ $t('common.loading') }}
                  </span>
                  <span v-else class="inline-flex items-center gap-2">
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                    </svg>
                    إرسال لغرفة العمليات الفكرية — Submit Field Report
                  </span>
                </button>
              </div>
            </form>

            <!-- === Success Toast (Military Tick) === -->
            <div v-else class="text-center py-12">
              <div class="w-16 h-16 mx-auto mb-5 rounded-full border-2 border-green-500/50 bg-green-500/10 flex items-center justify-center">
                <svg class="w-8 h-8 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <p class="text-green-400 font-bold text-lg mb-1 font-mono">تم استلام البلاغ الميداني</p>
              <p class="text-gray-500 text-sm font-mono">
                تمت إحالته إلى غرفة العمليات — رقم العملية: <span class="text-gray-400">#OB-{{ Date.now().toString(36).toUpperCase() }}</span>
              </p>
              <button
                type="button"
                class="mt-6 px-6 py-2 rounded-xl text-xs font-mono font-bold border border-white/10 text-gray-400 hover:text-white hover:border-white/30 transition-all duration-200 bg-black/40"
                @click="submitted = false"
              >
                ↑ {{ $t('observatory.form_submit_another') || 'إرسال بلاغ آخر' }}
              </button>
            </div>
          </div>
        </section>

        <!-- === Defense Feed (right / bottom) === -->
        <section>
          <div class="flex items-center justify-between mb-6">
            <h2 class="text-lg font-bold text-white flex items-center gap-2">
              <svg class="w-4 h-4 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
              </svg>
              {{ $t('observatory.defense_feed') }}
            </h2>
            <Badge v-if="neutralizedThreats.length" variant="success" size="md">
              {{ neutralizedThreats.length }}
            </Badge>
          </div>

          <div v-if="loadingFeed" class="text-center py-12">
            <p class="text-gray-500 text-sm font-mono">{{ $t('common.loading') }}</p>
          </div>

          <div v-else-if="!neutralizedThreats.length" class="text-center py-12">
            <div class="rounded-2xl border border-white/5 p-8" style="background: rgba(10, 10, 10, 0.6);">
              <p class="text-gray-600 text-sm font-mono">— {{ $t('observatory.defense_empty') }} —</p>
            </div>
          </div>

          <div v-else class="space-y-3">
            <div
              v-for="threat in neutralizedThreats"
              :key="threat.id"
              class="rounded-2xl p-4 border border-white/5 hover:border-green-500/20 transition-all duration-300"
              style="background: rgba(10, 10, 10, 0.7); backdrop-filter: blur(12px);"
            >
              <div class="flex flex-wrap items-start gap-2 mb-2">
                <h3 class="text-sm font-medium text-gray-200 min-w-0 break-words flex-1 leading-snug">
                  {{ threat.title }}
                </h3>
                <div class="flex shrink-0 gap-1.5 flex-wrap">
                  <Badge :class="platformBadgeClass(threat.platform)" size="sm">
                    {{ $t(`observatory.platform_${threat.platform}`, threat.platform) }}
                  </Badge>
                  <Badge :class="dangerBadge(threat.danger_level)" size="sm">
                    {{ dangerLabel(threat.danger_level) }}
                  </Badge>
                </div>
              </div>

              <div v-if="threat.response_url" class="mt-3">
                <a
                  :href="threat.response_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-2 text-xs font-mono text-green-400/70 hover:text-green-300 transition-colors"
                >
                  <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                  </svg>
                  {{ $t('observatory.defense_view_response') }}
                </a>
              </div>
            </div>
          </div>
        </section>
      </div>
    </div>
  </div>
</template>

<style scoped>
@keyframes ping-slow {
  0%, 100% { transform: scale(1); opacity: 0.8; }
  50% { transform: scale(1.05); opacity: 0.2; }
}
@keyframes ping-slower {
  0%, 100% { transform: translate(-50%, -50%) scale(1); opacity: 0.6; }
  50% { transform: translate(-50%, -50%) scale(1.08); opacity: 0.15; }
}
@keyframes ping-slowest {
  0%, 100% { transform: translate(-50%, -50%) scale(1); opacity: 0.4; }
  50% { transform: translate(-50%, -50%) scale(1.12); opacity: 0.1; }
}
.animate-ping-slow {
  animation: ping-slow 4s ease-in-out infinite;
}
.animate-ping-slower {
  animation: ping-slower 6s ease-in-out infinite;
}
.animate-ping-slowest {
  animation: ping-slowest 8s ease-in-out infinite;
}

/* Range slider styling */
input[type='range']::-webkit-slider-thumb {
  -webkit-appearance: none;
  appearance: none;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #ef4444;
  border: 2px solid rgba(255,255,255,0.2);
  cursor: pointer;
  box-shadow: 0 0 12px rgba(239,68,68,0.4);
}
input[type='range']::-moz-range-thumb {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #ef4444;
  border: 2px solid rgba(255,255,255,0.2);
  cursor: pointer;
  box-shadow: 0 0 12px rgba(239,68,68,0.4);
}
</style>
