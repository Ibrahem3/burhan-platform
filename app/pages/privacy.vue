<script setup lang="ts">
definePageMeta({
  title: 'Privacy',
})

const { t, locale } = useI18n()

useHead({
  title: t('legal.privacy.meta_title'),
  meta: [
    { name: 'description', content: t('legal.privacy.meta_description') },
    { property: 'og:title', content: t('legal.privacy.meta_title') },
    { property: 'og:description', content: t('legal.privacy.meta_description') },
  ],
})
</script>

<template>
  <div class="min-h-[calc(100vh-4rem)] relative" :dir="locale === 'ar' ? 'rtl' : 'ltr'">
    <div class="absolute inset-0 overflow-hidden pointer-events-none">
      <div class="absolute top-1/3 right-0 w-[500px] h-[500px] bg-gold/5 rounded-full blur-3xl" />
      <div class="absolute bottom-1/3 left-0 w-[400px] h-[400px] bg-gold/3 rounded-full blur-3xl" />
    </div>

    <div class="relative max-w-3xl mx-auto px-4 py-16 sm:py-24">
      <h1 class="text-3xl sm:text-4xl lg:text-5xl font-bold gradient-gold mb-2 text-balance">
        {{ t('legal.privacy.title') }}
      </h1>
      <p class="text-sm text-gray-500 mb-8">
        {{ t('legal.privacy.last_updated') }}
      </p>

      <div class="prose-gold max-w-none space-y-8">
        <p class="text-base sm:text-lg text-gray-300 leading-relaxed">
          {{ t('legal.privacy.intro') }}
        </p>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.privacy.s1_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.privacy.s1_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.privacy.s2_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.privacy.s2_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.privacy.s3_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.privacy.s3_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.privacy.s4_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.privacy.s4_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.privacy.s5_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.privacy.s5_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.privacy.s6_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.privacy.s6_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.privacy.s7_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.privacy.s7_body') }}</p>
        </section>
      </div>
    </div>
  </div>
</template>
