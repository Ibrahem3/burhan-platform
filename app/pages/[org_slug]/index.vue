<script setup lang="ts">
import type { Database } from '~/types/database'

definePageMeta({
  title: '',
})

const route = useRoute()
const { org, orgName, orgSlug, branches, loading: orgLoading, error: orgError } = useOrg()
const { entities, fetchOrgEntities, loading: entitiesLoading } = useEntities()
const { currentLocale, extractLocalized } = useLocale()
const { t } = useI18n()

const displayOrgName = computed(() => localizedValue(orgName.value, currentLocale.value))

const activeBranchId = ref<string | undefined>()

useHead({
  title: computed(() => displayOrgName.value || ''),
  meta: computed(() => {
    if (!org.value) return []
    return [
      { name: 'description', content: t('seo.org_description', { name: displayOrgName.value }) },
      { property: 'og:title', content: t('seo.org_title', { name: displayOrgName.value }) },
      { property: 'og:description', content: t('seo.org_description', { name: displayOrgName.value }) },
    ]
  }),
})

watch(
  () => org.value?.id,
  (orgId) => {
    if (orgId) {
      fetchOrgEntities(orgId, activeBranchId.value)
    }
  },
  { immediate: true },
)

watch(activeBranchId, (branchId) => {
  if (org.value?.id) {
    fetchOrgEntities(org.value.id, branchId)
  }
})

const filteredEntities = computed(() => {
  if (!activeBranchId.value) return entities.value
  return entities.value.filter((e) => e.branch_id === activeBranchId.value)
})

const loading = computed(() => orgLoading.value || entitiesLoading.value)

const localizedBranchName = (branch: Database['public']['Tables']['branches']['Row']): string => {
  return extractLocalized<string>(branch.name) ?? ''
}

const hasBranches = computed(() => branches.value.length > 0)

const isEmpty = computed(() => !loading.value && filteredEntities.value.length === 0)
</script>

<template>
  <div v-if="org && !orgError" class="min-h-screen">
    <div class="py-10 md:py-12">
      <!-- Org Header -->
      <OrgHeader :org="org" />

      <div class="max-w-7xl mx-auto px-4 mt-10">
        <!-- Branches filter -->
        <div v-if="hasBranches" class="mb-10">
          <div class="flex items-center gap-3 mb-4">
            <svg class="w-5 h-5 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
            </svg>
            <h2 class="text-sm font-medium text-gray-400 uppercase tracking-wider">
              {{ $t('tenant.branches') }}
            </h2>
          </div>

          <BranchNav
            :branches="branches"
            :active-branch-id="activeBranchId"
            @select="activeBranchId = $event"
          />

          <!-- Active branch title -->
          <div v-if="activeBranchId" class="mb-6">
            <h3 class="text-2xl font-bold text-white">
              {{ localizedBranchName(branches.find(b => b.id === activeBranchId)!) }}
            </h3>
          </div>
        </div>

        <!-- No branches state -->
        <div v-else-if="!loading" class="text-center py-16 mb-8">
          <GlassCard>
            <div class="py-8">
              <svg class="w-12 h-12 text-gray-600 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
              </svg>
              <p class="text-gray-500">{{ $t('tenant.no_branches') }}</p>
            </div>
          </GlassCard>
        </div>

        <!-- Loading skeleton -->
        <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div v-for="i in 6" :key="i">
            <GlassCard>
              <div class="animate-pulse space-y-4">
                <div class="flex items-center justify-between">
                  <div class="h-4 bg-white/5 rounded w-16" />
                  <div class="h-3 bg-white/5 rounded w-20" />
                </div>
                <div class="h-5 bg-white/5 rounded w-3/4" />
                <div class="space-y-2">
                  <div class="h-3 bg-white/5 rounded w-full" />
                  <div class="h-3 bg-white/5 rounded w-2/3" />
                </div>
                <div class="h-px bg-white/5" />
                <div class="h-3 bg-white/5 rounded w-24" />
              </div>
            </GlassCard>
          </div>
        </div>

        <!-- Empty state -->
        <div v-else-if="isEmpty" class="text-center py-16">
          <GlassCard>
            <div class="py-8">
              <svg class="w-12 h-12 text-gray-600 mx-auto mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
              </svg>
              <p class="text-gray-500 mb-1">
                {{ activeBranchId ? $t('entities.no_entities_in_branch') : $t('empty.org_desc') }}
              </p>
              <p class="text-xs text-gray-600">
                {{ $t('common.no_results') }}
              </p>
            </div>
          </GlassCard>
        </div>

        <!-- Entity grid -->
        <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <EntityCard
            v-for="entity in filteredEntities"
            :key="entity.id"
            :entity="entity"
          />
        </div>
      </div>
    </div>
  </div>

  <!-- Error state -->
  <div v-else class="min-h-[60vh] flex items-center justify-center">
    <GlassCard class="text-center max-w-md mx-auto">
      <div class="py-10 px-4">
        <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-red-500/10 flex items-center justify-center">
          <svg class="w-8 h-8 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
          </svg>
        </div>
        <h2 class="text-xl font-bold text-white mb-2">{{ $t('tenant.org_not_found_title') }}</h2>
        <p class="text-sm text-gray-400 mb-6">{{ $t('tenant.org_not_found_desc') }}</p>
        <NuxtLink to="/">
          <Button>{{ $t('common.back_home') }}</Button>
        </NuxtLink>
      </div>
    </GlassCard>
  </div>
</template>
