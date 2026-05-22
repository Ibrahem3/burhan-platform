<script setup lang="ts">
import type { Database } from '~/types/database'

const route = useRoute()
const branchId = computed(() => route.params.branch_id as string)
const { org } = useOrg()
const { entities, fetchOrgEntities, loading } = useEntities()

const branch = computed(() => {
  return org.value?.branches?.find((b) => b.id === branchId.value) ?? null
})

const { locale } = useI18n()
const currentLocale = computed(() => locale.value as 'ar' | 'en')
const localizedBranchName = computed(() => {
  if (!branch.value) return ''
  const name = branch.value.name as Record<string, string>
  return name[currentLocale.value] || name.en || ''
})
const localizedOrgName = computed(() => {
  if (!org.value?.name) return ''
  const name = org.value.name as Record<string, string>
  return name[currentLocale.value] || name.ar || ''
})

watch(
  [() => org.value?.id, branchId],
  ([orgId]) => {
    if (orgId) {
      fetchOrgEntities(orgId, branchId.value)
    }
  },
  { immediate: true },
)

const featuredEntity = computed(() => {
  const video = entities.value.find((e) => e.video_id)
  return video ?? entities.value[0] ?? null
})

const listEntities = computed(() => {
  if (!featuredEntity.value) return entities.value
  return entities.value.filter((e) => e.id !== featuredEntity.value.id)
})
</script>

<template>
  <div v-if="org && branch" class="min-h-screen py-8">
    <!-- Branch Header -->
    <div class="max-w-7xl mx-auto px-4 mb-8">
      <NuxtLink
        :to="`/${org.org_slug}`"
        class="inline-flex items-center gap-2 text-sm text-gray-400 hover:text-gold transition-colors mb-4"
      >
        &larr; {{ localizedOrgName }}
      </NuxtLink>

      <h1 class="text-3xl md:text-4xl font-bold text-white">
        {{ localizedBranchName }}
      </h1>
    </div>

    <!-- Featured Video -->
    <div v-if="featuredEntity" class="max-w-5xl mx-auto px-4 mb-12">
      <div class="mb-4">
        <h2 class="text-xl font-semibold text-white mb-2">
          {{ (featuredEntity.title as Record<string, string>)[currentLocale] || (featuredEntity.title as Record<string, string>).en }}
        </h2>
      </div>

      <PremiumGate
        :is-premium="featuredEntity.is_premium"
        :price="featuredEntity.price"
      >
        <VideoPlayer
          :video-id="featuredEntity.video_id"
          :primary-source="featuredEntity.primary_source"
          :fallback-source="featuredEntity.fallback_source"
          :fallback-url="featuredEntity.fallback_url"
        />
      </PremiumGate>
    </div>

    <!-- Entity List -->
    <div class="max-w-7xl mx-auto px-4">
      <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div v-for="i in 6" :key="i">
          <GlassCard>
            <div class="animate-pulse space-y-3">
              <div class="h-4 bg-white/10 rounded w-1/3" />
              <div class="h-5 bg-white/10 rounded w-3/4" />
              <div class="h-4 bg-white/10 rounded w-full" />
            </div>
          </GlassCard>
        </div>
      </div>

      <div v-else-if="listEntities.length === 0 && !featuredEntity" class="text-center py-16">
        <p class="text-gray-500">{{ $t('tenant.no_entities') }}</p>
      </div>

      <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <EntityCard
          v-for="entity in listEntities"
          :key="entity.id"
          :entity="entity"
        />
      </div>
    </div>
  </div>
</template>
