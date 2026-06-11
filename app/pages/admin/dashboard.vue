<script setup lang="ts">
definePageMeta({
  layout: 'dashboard',
  middleware: 'super-admin-only',
  title: 'Admin Dashboard',
})

const { t, locale } = useI18n()

const stats = ref({ totalOrgs: 0, totalBranches: 0, totalUsers: 0 })
const organizations = ref<any[]>([])
const loading = ref(true)

async function loadStats() {
  loading.value = true
  try {
    const data = await $fetch<{ stats: typeof stats.value; organizations: any[] }>('/api/admin/stats')
    stats.value = data.stats
    organizations.value = data.organizations.map(org => ({
      ...org,
      _name: localizedValue(org.name as any, locale.value) || org.name?.en || org.name?.ar || '—',
    }))
  } catch (err) {
    console.error('[admin] Load error:', err)
  } finally {
    loading.value = false
  }
}

function formatDate(iso: string) {
  const d = new Date(iso)
  return d.toLocaleDateString(locale.value === 'ar' ? 'ar-EG' : 'en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  })
}

onMounted(loadStats)
</script>

<template>
  <div class="max-w-7xl mx-auto p-4 sm:p-6 lg:p-8">
    <div class="mb-8">
      <h1 class="text-2xl font-bold gradient-gold mb-1">Global Control Panel</h1>
      <p class="text-sm text-gray-500">لوحة التحكم الرئيسية — إدارة المنصة بالكامل</p>
    </div>

    <div v-if="loading" class="text-center py-20">
      <p class="text-gray-500">{{ $t('common.loading') }}</p>
    </div>

    <template v-else>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 sm:gap-6 mb-10">
        <GlassCard>
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl bg-gold/10 flex items-center justify-center shrink-0">
              <svg class="w-6 h-6 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
              </svg>
            </div>
            <div>
              <p class="text-3xl font-bold text-white">{{ stats.totalOrgs }}</p>
              <p class="text-sm text-gray-500">Registered Organizations</p>
            </div>
          </div>
        </GlassCard>

        <GlassCard>
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl bg-blue-500/10 flex items-center justify-center shrink-0">
              <svg class="w-6 h-6 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01" />
              </svg>
            </div>
            <div>
              <p class="text-3xl font-bold text-white">{{ stats.totalBranches }}</p>
              <p class="text-sm text-gray-500">Active Branches</p>
            </div>
          </div>
        </GlassCard>

        <GlassCard>
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl bg-emerald-500/10 flex items-center justify-center shrink-0">
              <svg class="w-6 h-6 text-emerald-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
            </div>
            <div>
              <p class="text-3xl font-bold text-white">{{ stats.totalUsers }}</p>
              <p class="text-sm text-gray-500">System Users</p>
            </div>
          </div>
        </GlassCard>
      </div>

      <GlassCard>
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-lg font-bold text-white">Registered Tenants</h2>
          <span class="text-xs text-gray-500">{{ organizations.length }} organizations</span>
        </div>

        <div v-if="!organizations.length" class="text-center py-12">
          <p class="text-gray-500">No organizations registered yet</p>
        </div>

        <div v-else class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-white/5">
                <th class="text-left py-3 px-4 text-gray-500 font-medium text-xs uppercase tracking-wider">Name</th>
                <th class="text-left py-3 px-4 text-gray-500 font-medium text-xs uppercase tracking-wider">Slug</th>
                <th class="text-center py-3 px-4 text-gray-500 font-medium text-xs uppercase tracking-wider">Branches</th>
                <th class="text-right py-3 px-4 text-gray-500 font-medium text-xs uppercase tracking-wider">Created</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="org in organizations"
                :key="org.id"
                class="border-b border-white/[0.02] hover:bg-white/[0.02] transition-colors"
              >
                <td class="py-3 px-4">
                  <NuxtLink
                    :to="`/${org.org_slug}`"
                    class="text-white hover:text-gold transition-colors font-medium"
                  >
                    {{ org._name }}
                  </NuxtLink>
                </td>
                <td class="py-3 px-4">
                  <code class="text-xs text-gray-500 bg-white/5 px-2 py-0.5 rounded">{{ org.org_slug }}</code>
                </td>
                <td class="py-3 px-4 text-center">
                  <Badge variant="info" size="sm">{{ org.branch_count }}</Badge>
                </td>
                <td class="py-3 px-4 text-right text-gray-400 text-xs">
                  {{ formatDate(org.created_at) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </GlassCard>
    </template>
  </div>
</template>
