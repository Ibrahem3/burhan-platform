<script setup lang="ts">
definePageMeta({
  layout: 'dashboard',
  middleware: 'dashboard-auth',
  title: 'Dashboard',
})

const { t } = useI18n()

const stats = ref([
  {
    key: 'total_videos',
    descKey: 'stat_videos_desc',
    value: '0',
    change: '—',
    positive: true,
  },
  {
    key: 'active_branches',
    descKey: 'stat_branches_desc',
    value: '0',
    change: '—',
    positive: true,
  },
  {
    key: 'premium_revenue',
    descKey: 'stat_revenue_desc',
    value: '$0',
    change: '—',
    positive: true,
  },
  {
    key: 'total_subscribers',
    descKey: 'stat_subscribers_desc',
    value: '0',
    change: '—',
    positive: true,
  },
])

const statIcon = (key: string) => {
  const icons: Record<string, string> = {
    total_videos: 'M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z',
    active_branches: 'M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z',
    premium_revenue: 'M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
    total_subscribers: 'M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z',
  }
  return icons[key] || ''
}
</script>

<template>
  <div>
    <div class="mb-8">
      <h1 class="text-xl font-bold text-white">{{ $t('dashboard.greeting') }}</h1>
    </div>

    <div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-3 sm:gap-4 lg:gap-6">
      <div
        v-for="stat in stats"
        :key="stat.key"
        class="glass rounded-2xl p-4 sm:p-5 lg:p-6 border border-white/5 hover:border-gold/20 transition-all duration-300"
      >
        <div class="flex items-start justify-between mb-3 sm:mb-4">
          <div class="w-9 h-9 sm:w-10 sm:h-10 rounded-xl bg-gold/10 flex items-center justify-center">
            <svg class="w-4 h-4 sm:w-5 sm:h-5 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" :d="statIcon(stat.key)" />
            </svg>
          </div>
          <span
            class="text-[10px] sm:text-xs font-medium px-1.5 sm:px-2 py-0.5 rounded-full"
            :class="stat.positive ? 'text-green-400 bg-green-500/10' : 'text-red-400 bg-red-500/10'"
          >
            {{ stat.change }}
          </span>
        </div>

        <p class="text-xl sm:text-2xl font-bold text-white mb-1">{{ stat.value }}</p>
        <p class="text-[11px] sm:text-xs text-gray-500">{{ $t(`dashboard.${stat.key}`) }}</p>
        <p class="text-[11px] sm:text-xs text-gray-600 mt-1">{{ $t(`dashboard.${stat.descKey}`) }}</p>
      </div>
    </div>
  </div>
</template>
