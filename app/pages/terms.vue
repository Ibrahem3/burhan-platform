<script setup lang="ts">
definePageMeta({
  title: 'Terms',
})

const { t, locale } = useI18n()

useHead({
  title: t('legal.terms.meta_title'),
  meta: [
    { name: 'description', content: t('legal.terms.meta_description') },
    { property: 'og:title', content: t('legal.terms.meta_title') },
    { property: 'og:description', content: t('legal.terms.meta_description') },
  ],
})
</script>

<template>
  <div class="min-h-[calc(100vh-4rem)] relative" :dir="locale === 'ar' ? 'rtl' : 'ltr'">
    <div class="absolute inset-0 overflow-hidden pointer-events-none">
      <div class="absolute top-1/4 right-1/4 w-[500px] h-[500px] bg-gold/5 rounded-full blur-3xl" />
      <div class="absolute bottom-1/4 left-1/4 w-[400px] h-[400px] bg-gold/3 rounded-full blur-3xl" />
    </div>

    <div class="relative max-w-3xl mx-auto px-4 py-16 sm:py-24">
      <h1 class="text-3xl sm:text-4xl lg:text-5xl font-bold gradient-gold mb-2 text-balance">
        {{ t('legal.terms.title') }}
      </h1>
      <p class="text-sm text-gray-500 mb-8">
        {{ t('legal.terms.last_updated') }}
      </p>

      <div class="prose-gold max-w-none space-y-8">
        <p class="text-base sm:text-lg text-gray-300 leading-relaxed">
          {{ t('legal.terms.intro') }}
        </p>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.terms.s1_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.terms.s1_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.terms.s2_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.terms.s2_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.terms.s3_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.terms.s3_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.terms.s4_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.terms.s4_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.terms.s5_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.terms.s5_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.terms.s6_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.terms.s6_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.terms.s7_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.terms.s7_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.terms.s8_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.terms.s8_body') }}</p>
        </section>

        <section>
          <h2 class="text-xl sm:text-2xl font-bold text-gold mb-3">{{ t('legal.terms.s9_heading') }}</h2>
          <p class="text-base text-gray-400 leading-relaxed">{{ t('legal.terms.s9_body') }}</p>
        </section>
      </div>
    </div>
  </div>
</template>
