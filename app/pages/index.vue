<script setup lang="ts">
definePageMeta({
  title: 'Main Hub',
})

const { entities, fetchPublicEntities, loading } = useEntities()

const { t } = useI18n()

useHead({
  meta: [
    { name: 'description', content: t('seo.hub_description') },
    { property: 'og:title', content: t('seo.hub_title') },
    { property: 'og:description', content: t('seo.hub_description') },
  ],
})

onMounted(() => {
  fetchPublicEntities()
})

const featuredEntities = computed(() => entities.value.slice(0, 3))
const latestEntities = computed(() => entities.value.slice(3))

function scrollToFeed() {
  const el = document.getElementById('public-feed')
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
}
</script>

<template>
  <div class="min-h-screen">
    <!-- Hero Section -->
    <section class="relative overflow-hidden py-24 md:py-36">
      <!-- Ambient glow orbs -->
      <div class="absolute top-1/4 -left-40 w-[500px] h-[500px] bg-gold/5 rounded-full blur-3xl" />
      <div class="absolute top-1/3 -right-40 w-[400px] h-[400px] bg-gold/3 rounded-full blur-3xl" />
      <div class="absolute bottom-1/4 left-1/2 -translate-x-1/2 w-[600px] h-[300px] bg-gold/3 rounded-full blur-3xl" />

      <!-- Gradient overlay -->
      <div class="absolute inset-0 bg-gradient-to-b from-gold/5 via-transparent to-transparent pointer-events-none" />

      <div class="relative z-10 text-center max-w-4xl mx-auto px-4">
        <div class="animate-fade-in">
          <h1 class="text-5xl md:text-7xl lg:text-8xl font-bold mb-6 tracking-tight">
            <span class="gradient-gold">{{ $t('hub.title') }}</span>
          </h1>

          <p class="text-lg md:text-xl lg:text-2xl text-gray-400 mb-8 max-w-2xl mx-auto leading-relaxed">
            {{ $t('hub.hero_description') }}
          </p>

          <div class="flex flex-wrap items-center justify-center gap-4">
            <Button size="lg" @click="scrollToFeed">
              {{ $t('hub.cta_browse') }}
            </Button>
            <Button variant="outline" size="lg">
              {{ $t('hub.cta_learn') }}
            </Button>
          </div>
        </div>
      </div>
    </section>

    <!-- Featured entities -->
    <section v-if="featuredEntities.length > 0" class="max-w-7xl mx-auto px-4 pb-16">
      <div class="mb-8">
        <h2 class="text-2xl font-bold text-white mb-1">{{ $t('hub.featured') }}</h2>
        <p class="text-sm text-gray-500">{{ $t('hub.subtitle') }}</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <EntityCard
          v-for="entity in featuredEntities"
          :key="entity.id"
          :entity="entity"
        />
      </div>
    </section>

    <!-- Public Entities Feed -->
    <section id="public-feed" class="max-w-7xl mx-auto px-4 pb-24">
      <CategorySection
        :title="$t('hub.latest')"
        :entities="latestEntities"
        :loading="loading"
      />
    </section>
  </div>
</template>
