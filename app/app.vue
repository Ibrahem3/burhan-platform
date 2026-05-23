<script setup lang="ts">
const { locale } = useI18n()
const route = useRoute()

useHead({
  htmlAttrs: {
    dir: computed(() => (locale.value === 'ar' ? 'rtl' : 'ltr')),
    lang: locale,
  },
  titleTemplate: (titleChunk) => {
    return titleChunk ? `${titleChunk} | بُرهان` : 'بُرهان — Intellectual Refutations Platform'
  },
  meta: [
    { name: 'description', content: 'Multi-tenant platform for intellectual refutations, scholarly dialogues, and media archive' },
    { name: 'theme-color', content: '#0a0a0a' },
    { property: 'og:site_name', content: 'بُرهان' },
    { property: 'og:type', content: 'website' },
  ],
  link: [
    { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
    { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: 'anonymous' },
    { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Noto+Naskh+Arabic:wght@400;500;600;700&family=Tajawal:wght@400;500;700&display=swap' },
    { rel: 'icon', type: 'image/webp', href: '/favicon.webp' },
    { rel: 'apple-touch-icon', href: '/favicon.webp' },
  ],
})

watch(
  () => route.path,
  () => {
    const html = document.documentElement
    html.dir = locale.value === 'ar' ? 'rtl' : 'ltr'
    html.lang = locale.value
  },
)
</script>

<template>
   <NuxtLayout>
    <SplashScreen />
    <NuxtPage keepalive />
  </NuxtLayout>
</template>

<style>
select, select option {
  background-color: #1a1a1a;
  color: #fff;
}
select option:hover,
select option:focus {
  background-color: #d4af37;
  color: #0a0a0a;
}
</style>
