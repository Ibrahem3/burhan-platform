<script setup lang="ts">
definePageMeta({
  title: 'About',
})

const { t, locale } = useI18n()
const head = useLocaleHead({ addSeoAttributes: true })

useHead({
  title: t('legal.about.meta_title'),
  meta: [
    { name: 'description', content: t('legal.about.meta_description') },
    { property: 'og:title', content: t('legal.about.meta_title') },
    { property: 'og:description', content: t('legal.about.meta_description') },
  ],
})

// Dynamically splits i18n values at the colon to style titles and descriptions separately
const getValueParts = (key: string) => {
  const val = t(key)
  const parts = val.split(/:|：/)
  if (parts.length > 1) {
    return {
      title: parts[0]?.trim() || '',
      desc: parts.slice(1).join(':').trim(),
    }
  }
  return { title: '', desc: val }
}

const valueIcons = [
  // Objectivity: Balance/Scale icon
  'M9 12h6m-6 0a3 3 0 110-6 3 3 0 010 6zm6 0a3 3 0 110-6 3 3 0 010 6zm-3 8v-8m0 8a2 2 0 100-4 2 2 0 000 4z',
  // Quality: Shield/Badge icon
  'M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z',
  // Openness: Handshake/Global network icon
  'M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9',
  // Innovation: Lightbulb/Rocket icon
  'M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z',
  // Transparency: Prism/Shield outline icon
  'M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z',
]
</script>

<template>
  <div class="min-h-[calc(100vh-4rem)] relative overflow-hidden" :dir="locale === 'ar' ? 'rtl' : 'ltr'">
    <!-- === Background Glows & Grid Pattern === -->
    <div class="absolute inset-0 pointer-events-none overflow-hidden">
      <!-- Subtle scan-lines -->
      <div class="absolute inset-0 opacity-[0.015]" style="background-image: repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(255,255,255,0.03) 2px, rgba(255,255,255,0.03) 4px);" />
      
      <!-- Tech Grid overlay -->
      <svg class="absolute inset-0 w-full h-full opacity-[0.03]" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="about-grid" width="60" height="60" patternUnits="userSpaceOnUse">
            <path d="M 60 0 L 0 0 0 60" fill="none" stroke="currentColor" stroke-width="0.4" class="text-gold" />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#about-grid)" />
      </svg>

      <!-- Glowing Orbs -->
      <div class="absolute top-1/4 -left-40 w-[600px] h-[600px] bg-gold/5 rounded-full blur-3xl animate-pulse-slow" />
      <div class="absolute bottom-1/4 -right-40 w-[500px] h-[500px] bg-gold/3 rounded-full blur-3xl animate-pulse-slower" />
    </div>

    <div class="relative max-w-5xl mx-auto px-4 py-16 sm:py-24">
      <!-- === Hero Header === -->
      <div class="text-center mb-16 max-w-3xl mx-auto">
        <div class="inline-flex items-center gap-1.5 px-3 py-1 mb-4 border border-gold/25 rounded-full bg-gold/5 text-[10px] font-mono text-gold/80 uppercase tracking-widest">
          <span class="w-1 h-1 rounded-full bg-gold animate-ping" />
          {{ t('brand.name') }} — {{ t('footer.about_platform') }}
        </div>
        <h1 class="text-3xl sm:text-4xl lg:text-5xl font-bold gradient-gold mb-6 tracking-tight leading-tight text-balance">
          {{ t('legal.about.title') }}
        </h1>
        <p class="text-base sm:text-lg text-gray-400 leading-relaxed font-light">
          {{ t('legal.about.intro') }}
        </p>
      </div>

      <!-- === Mission & Vision Split Layout === -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 lg:gap-8 mb-20">
        <!-- Mission Card -->
        <div
          class="group relative rounded-2xl border border-white/[0.05] p-6 sm:p-8 transition-all duration-300 hover:border-gold/30 hover:shadow-glow hover:-translate-y-0.5"
          style="background: rgba(10, 10, 10, 0.7); backdrop-filter: blur(16px); box-shadow: inset 0 1px 0 rgba(255,255,255,0.02);"
        >
          <div class="absolute inset-x-0 top-0 h-[2px] bg-gradient-to-r from-gold/0 via-gold/30 to-gold/0 opacity-50 group-hover:opacity-100 transition-opacity" />
          
          <div class="flex items-center gap-4 mb-5">
            <div class="w-12 h-12 rounded-xl bg-gold/10 border border-gold/25 flex items-center justify-center shrink-0 shadow-inner group-hover:bg-gold/15 transition-colors">
              <!-- Target SVG icon -->
              <svg class="w-6 h-6 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9 9 0 100-18 9 9 0 000 18zm0 0V12m0 0h9m-9 0L3 12m9 0v9m9-9A9 9 0 0112 3" />
              </svg>
            </div>
            <h2 class="text-xl sm:text-2xl font-bold text-white group-hover:text-gold transition-colors leading-none">
              {{ t('legal.about.mission_heading') }}
            </h2>
          </div>
          <p class="text-sm sm:text-base text-gray-400 leading-relaxed">
            {{ t('legal.about.mission_body') }}
          </p>
        </div>

        <!-- Vision Card -->
        <div
          class="group relative rounded-2xl border border-white/[0.05] p-6 sm:p-8 transition-all duration-300 hover:border-gold/30 hover:shadow-glow hover:-translate-y-0.5"
          style="background: rgba(10, 10, 10, 0.7); backdrop-filter: blur(16px); box-shadow: inset 0 1px 0 rgba(255,255,255,0.02);"
        >
          <div class="absolute inset-x-0 top-0 h-[2px] bg-gradient-to-r from-gold/0 via-gold/30 to-gold/0 opacity-50 group-hover:opacity-100 transition-opacity" />

          <div class="flex items-center gap-4 mb-5">
            <div class="w-12 h-12 rounded-xl bg-gold/10 border border-gold/25 flex items-center justify-center shrink-0 shadow-inner group-hover:bg-gold/15 transition-colors">
              <!-- Telescope/Binoculars SVG icon -->
              <svg class="w-6 h-6 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
              </svg>
            </div>
            <h2 class="text-xl sm:text-2xl font-bold text-white group-hover:text-gold transition-colors leading-none">
              {{ t('legal.about.vision_heading') }}
            </h2>
          </div>
          <p class="text-sm sm:text-base text-gray-400 leading-relaxed">
            {{ t('legal.about.vision_body') }}
          </p>
        </div>
      </div>

      <!-- === Core Values Section === -->
      <div>
        <div class="text-center mb-10">
          <h2 class="text-2xl sm:text-3xl font-bold text-white mb-2 font-mono tracking-tight">
            {{ t('legal.about.values_heading') }}
          </h2>
          <div class="w-12 h-[2px] bg-gold/30 mx-auto rounded-full" />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
          <!-- Card for Value 1 to 5 -->
          <div
            v-for="i in 5"
            :key="i"
            class="group relative rounded-xl border border-white/[0.04] p-5 sm:p-6 transition-all duration-300 hover:border-gold/20 hover:shadow-glow hover:-translate-y-1"
            style="background: rgba(10, 10, 10, 0.5); backdrop-filter: blur(12px);"
          >
            <div class="flex items-center gap-3.5 mb-4">
              <div class="w-10 h-10 rounded-lg bg-gold/[0.06] border border-gold/15 flex items-center justify-center shrink-0 group-hover:bg-gold/10 transition-colors">
                <svg class="w-5 h-5 text-gold/90" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8">
                  <path stroke-linecap="round" stroke-linejoin="round" :d="valueIcons[i - 1]" />
                </svg>
              </div>
              <h3 class="text-base font-bold text-white group-hover:text-gold transition-colors">
                {{ getValueParts(`legal.about.values_${i}`).title }}
              </h3>
            </div>
            <p class="text-xs sm:text-sm text-gray-500 leading-relaxed">
              {{ getValueParts(`legal.about.values_${i}`).desc }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.animate-pulse-slow {
  animation: pulse-glow 5s ease-in-out infinite;
}
.animate-pulse-slower {
  animation: pulse-glow 7s ease-in-out infinite;
}

@keyframes pulse-glow {
  0%, 100% { opacity: 0.8; transform: scale(1); }
  50% { opacity: 0.4; transform: scale(1.05); }
}
</style>
