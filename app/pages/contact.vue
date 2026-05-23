<script setup lang="ts">
definePageMeta({
  title: 'Contact',
})

const { t, locale } = useI18n()

useHead({
  title: t('legal.contact.meta_title'),
  meta: [
    { name: 'description', content: t('legal.contact.meta_description') },
    { property: 'og:title', content: t('legal.contact.meta_title') },
    { property: 'og:description', content: t('legal.contact.meta_description') },
  ],
})

const sent = ref(false)
</script>

<template>
  <div class="min-h-[calc(100vh-4rem)] relative" :dir="locale === 'ar' ? 'rtl' : 'ltr'">
    <div class="absolute inset-0 overflow-hidden pointer-events-none">
      <div class="absolute top-1/3 -left-40 w-[500px] h-[500px] bg-gold/5 rounded-full blur-3xl" />
      <div class="absolute bottom-1/3 -right-40 w-[400px] h-[400px] bg-gold/3 rounded-full blur-3xl" />
    </div>

    <div class="relative max-w-3xl mx-auto px-4 py-16 sm:py-24">
      <h1 class="text-3xl sm:text-4xl lg:text-5xl font-bold gradient-gold mb-3 text-balance">
        {{ t('legal.contact.title') }}
      </h1>
      <p class="text-base sm:text-lg text-gray-400 mb-10">
        {{ t('legal.contact.subtitle') }}
      </p>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-10">
        <div class="md:col-span-2">
          <h3 class="text-lg font-semibold text-gray-300 mb-4">
            {{ t('legal.contact.form_heading') }}
          </h3>

          <form v-if="!sent" novalidate @submit.prevent="sent = true" class="space-y-4">
            <div>
              <input
                :placeholder="t('legal.contact.form_placeholder_name')"
                class="w-full px-4 py-2.5 rounded-lg bg-white/5 border border-white/10 text-gray-200 placeholder-gray-600 focus:outline-none focus:border-gold/50 transition-colors text-sm"
                required
              />
            </div>
            <div>
              <input
                type="email"
                :placeholder="t('legal.contact.form_placeholder_email')"
                class="w-full px-4 py-2.5 rounded-lg bg-white/5 border border-white/10 text-gray-200 placeholder-gray-600 focus:outline-none focus:border-gold/50 transition-colors text-sm"
                required
              />
            </div>
            <div>
              <input
                :placeholder="t('legal.contact.form_placeholder_subject')"
                class="w-full px-4 py-2.5 rounded-lg bg-white/5 border border-white/10 text-gray-200 placeholder-gray-600 focus:outline-none focus:border-gold/50 transition-colors text-sm"
                required
              />
            </div>
            <div>
              <textarea
                rows="5"
                :placeholder="t('legal.contact.form_placeholder_message')"
                class="w-full px-4 py-2.5 rounded-lg bg-white/5 border border-white/10 text-gray-200 placeholder-gray-600 focus:outline-none focus:border-gold/50 transition-colors text-sm resize-none"
                required
              />
            </div>
            <Button type="submit" class="w-full">
              {{ t('legal.contact.form_submit') }}
            </Button>
          </form>

          <div v-else class="p-6 rounded-xl border border-green-500/20 bg-green-500/5 text-center">
            <p class="text-green-400 font-medium text-lg mb-1">✓</p>
            <p class="text-gray-300">{{ locale === 'ar' ? 'تم إرسال رسالتك بنجاح' : 'Your message has been sent successfully' }}</p>
          </div>
        </div>

        <div class="space-y-6">
          <div class="p-6 rounded-xl border border-white/5 bg-white/[0.02]">
            <h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-2">
              {{ t('legal.contact.email_label') }}
            </h3>
            <a
              href="mailto:hello@ainux.online"
              class="text-gold hover:text-gold/80 transition-colors break-all"
            >
              hello@ainux.online
            </a>
            <p class="text-xs text-gray-600 mt-2">
              {{ t('legal.contact.response_time') }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
