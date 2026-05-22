<script setup lang="ts">
interface Props {
  title: string
  entities: any[]
  loading?: boolean
}

withDefaults(defineProps<Props>(), {
  loading: false,
})
</script>

<template>
  <section class="space-y-6">
    <div class="flex items-center justify-between">
      <h2 class="text-2xl font-bold text-white">
        {{ title }}
      </h2>
      <NuxtLink
        to="/"
        class="text-sm text-gold hover:text-gold-300 transition-colors"
      >
        {{ $t('hub.view_all') }}
      </NuxtLink>
    </div>

    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <div v-for="i in 6" :key="i">
        <GlassCard>
          <div class="animate-pulse space-y-3">
            <div class="h-4 bg-white/10 rounded w-1/3" />
            <div class="h-5 bg-white/10 rounded w-3/4" />
            <div class="h-4 bg-white/10 rounded w-full" />
            <div class="h-4 bg-white/10 rounded w-2/3" />
          </div>
        </GlassCard>
      </div>
    </div>

    <div
      v-else-if="entities.length === 0"
      class="text-center py-12"
    >
      <p class="text-gray-500">
        {{ $t('hub.no_public_entities') }}
      </p>
    </div>

    <div
      v-else
      class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
    >
      <EntityCard
        v-for="entity in entities"
        :key="entity.id"
        :entity="entity"
      />
    </div>
  </section>
</template>
