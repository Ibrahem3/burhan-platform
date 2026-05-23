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
</script>

<template>
  <div class="min-h-[calc(100vh-4rem)] relative" :dir="locale === 'ar' ? 'rtl' : 'ltr'">
    <div class="absolute inset-0 overflow-hidden pointer-events-none">
      <div class="absolute top-1/4 left-1/4 w-[600px] h-[600px] bg-gold/5 rounded-full blur-3xl" />
      <div class="absolute bottom-1/4 right-1/4 w-[400px] h-[400px] bg-gold/3 rounded-full blur-3xl" />
    </div>

    <div class="relative max-w-3xl mx-auto px-4 py-16 sm:py-24">
      <h1 class="text-3xl sm:text-4xl lg:text-5xl font-bold gradient-gold mb-8 text-balance">
        {{ t('legal.about.title') }}
      </h1>

      <div class="prose-gold max-w-none">
        <p class="text-base sm:text-lg text-gray-300 leading-relaxed mb-10">
          {{ t('legal.about.intro') }}
        </p>

        <section class="mb-10">
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-4">
            {{ t('legal.about.mission_heading') }}
          </h2>
          <p class="text-base text-gray-400 leading-relaxed">
            {{ t('legal.about.mission_body') }}
          </p>
        </section>

        <section class="mb-10">
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-4">
            {{ t('legal.about.vision_heading') }}
          </h2>
          <p class="text-base text-gray-400 leading-relaxed">
            {{ t('legal.about.vision_body') }}
          </p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-4">
            {{ t('legal.about.values_heading') }}
          </h2>
          <ul class="space-y-3 text-gray-400">
            <li class="flex items-start gap-3">
              <span class="text-gold mt-1 shrink-0">✦</span>
              <span>{{ t('legal.about.values_1') }}</span>
            </li>
            <li class="flex items-start gap-3">
              <span class="text-gold mt-1 shrink-0">✦</span>
              <span>{{ t('legal.about.values_2') }}</span>
            </li>
            <li class="flex items-start gap-3">
              <span class="text-gold mt-1 shrink-0">✦</span>
              <span>{{ t('legal.about.values_3') }}</span>
            </li>
            <li class="flex items-start gap-3">
              <span class="text-gold mt-1 shrink-0">✦</span>
              <span>{{ t('legal.about.values_4') }}</span>
            </li>
            <li class="flex items-start gap-3">
              <span class="text-gold mt-1 shrink-0">✦</span>
              <span>{{ t('legal.about.values_5') }}</span>
            </li>
          </ul>
        </section>
      </div>
    </div>
  </div>
</template>

<style scoped>
.prose-gold h2 {
  font-weight: 700;
}
</style>
