<script setup lang="ts">
import type { Database } from '~/types/database'

definePageMeta({
  layout: 'dashboard',
  middleware: 'observatory-auth',
  title: 'Observatory Dashboard',
})

const { t, locale } = useI18n()
const supabase = useSupabaseClient<any>()
const user = useSupabaseUser()

const threats = ref<any[]>([])
const analysts = ref<any[]>([])
const loading = ref(true)
const updating = ref<string | null>(null)
const addAnalystEmail = ref('')
const addAnalystRole = ref<'observatory_manager' | 'observatory_analyst'>('observatory_analyst')
const addingAnalyst = ref(false)
const threatFilter = ref<'all' | 'pending' | 'under_review'>('all')

const counters = computed(() => ({
  total: threats.value.length,
  active: threats.value.filter(t => t.status === 'under_review').length,
  neutralized: threats.value.filter(t => t.status === 'neutralized').length,
}))

const filteredThreats = computed(() => {
  if (threatFilter.value === 'all') return threats.value
  return threats.value.filter(t => t.status === threatFilter.value)
})

const userRole = ref<'observatory_manager' | 'observatory_analyst' | null>(null)
const isSuperAdmin = ref(false)

async function loadData() {
  loading.value = true
  try {
    const [analystRes, profileRes, threatsRes, analystsRes] = await Promise.all([
      supabase
        .from('observatory_analysts')
        .select('role_type')
        .eq('id', user.value!.id)
        .maybeSingle(),
      supabase
        .from('profiles')
        .select('role')
        .eq('id', user.value!.id)
        .maybeSingle(),
      supabase
        .from('observatory_threats')
        .select('*')
        .order('created_at', { ascending: false }),
      supabase
        .from('observatory_analysts')
        .select('id, role_type, created_at'),
    ])

    userRole.value = analystRes.data?.role_type || null
    isSuperAdmin.value = profileRes.data?.role === 'super_admin'
    threats.value = threatsRes.data || []
    analysts.value = analystsRes.data || []
  } catch (err) {
    console.error('[observatory] Load error:', err)
  } finally {
    loading.value = false
  }
}

const canManage = computed(() => userRole.value === 'observatory_manager' || isSuperAdmin.value)
const canDelete = computed(() => userRole.value === 'observatory_manager' || isSuperAdmin.value)

async function updateThreat(id: string, updates: Record<string, any>) {
  updating.value = id
  try {
    const { error } = await supabase
      .from('observatory_threats')
      .update(updates)
      .eq('id', id)

    if (error) {
      console.error('[observatory] Update error:', error)
    } else {
      await loadData()
    }
  } finally {
    updating.value = null
  }
}

async function deleteThreat(id: string) {
  if (!confirm(t('observatory.delete_confirm'))) return
  updating.value = id
  try {
    await supabase
      .from('observatory_threats')
      .delete()
      .eq('id', id)

    await loadData()
  } finally {
    updating.value = null
  }
}

async function addAnalyst() {
  if (!addAnalystEmail.value) return
  addingAnalyst.value = true
  try {
    const { data: { session } } = await supabase.auth.getSession()
    if (!session?.access_token) return

    await $fetch('/api/observatory/analysts', {
      method: 'POST',
      body: {
        email: addAnalystEmail.value,
        roleType: addAnalystRole.value,
        accessToken: session.access_token,
      },
    })

    addAnalystEmail.value = ''
    await loadData()
  } catch (err: any) {
    console.error('[observatory] Add analyst error:', err)
  } finally {
    addingAnalyst.value = false
  }
}

async function removeAnalyst(id: string) {
  if (!confirm(t('observatory.analysts_remove_confirm'))) return
  try {
    await supabase
      .from('observatory_analysts')
      .delete()
      .eq('id', id)

    await loadData()
  } catch (err) {
    console.error('[observatory] Remove analyst error:', err)
  }
}

const statusBadge = (status: string) => {
  const map: Record<string, string> = {
    pending: 'bg-amber-500/20 text-amber-400 border-amber-500/30',
    under_review: 'bg-fuchsia-500/20 text-fuchsia-400 border-fuchsia-500/30',
    neutralized: 'bg-green-500/20 text-green-400 border-green-500/30',
  }
  return map[status] || map.pending
}

const dangerBadge = (level: string) => {
  const map: Record<string, string> = {
    Low: 'bg-green-500/20 text-green-400 border-green-500/30',
    Medium: 'bg-amber-500/20 text-amber-400 border-amber-500/30',
    High: 'bg-red-500/20 text-red-400 border-red-500/30',
  }
  return map[level] || map.Medium
}

const platformBadgeClass = (platform: string) => {
  const map: Record<string, string> = {
    tiktok: 'bg-pink-500/20 text-pink-400 border-pink-500/30',
    youtube: 'bg-red-500/20 text-red-400 border-red-500/30',
    facebook: 'bg-blue-500/20 text-blue-400 border-blue-500/30',
    x: 'bg-gray-400/20 text-gray-300 border-gray-400/30',
    instagram: 'bg-purple-500/20 text-purple-400 border-purple-500/30',
    telegram: 'bg-sky-500/20 text-sky-400 border-sky-500/30',
    other: 'bg-white/10 text-gray-300 border-white/10',
  }
  return map[platform] || map.other
}

const tagSource = (platform: string) => {
  return t(`observatory.platform_${platform}`, t('observatory.platform_other'))
}

const tagStatus = (status: string) => {
  const map: Record<string, string> = {
    pending: t('observatory.status_queue_pending'),
    under_review: t('observatory.status_queue_review'),
    neutralized: t('observatory.status_queue_neutralized'),
  }
  return map[status] || status
}

const tagTarget = (dangerLevel: string) => {
  const map: Record<string, string> = {
    Low: t('observatory.target_youth'),
    Medium: t('observatory.target_intellectuals'),
    High: t('observatory.target_special'),
  }
  return map[dangerLevel] || t('observatory.target_general')
}

const isUpdating = (id: string) => updating.value === id

onMounted(loadData)
</script>

<template>
  <div class="relative min-h-screen overflow-hidden" :dir="locale === 'ar' ? 'rtl' : 'ltr'">
    <!-- === Background: Radar / Grid overlay === -->
    <div class="absolute inset-0 pointer-events-none overflow-hidden">
      <div class="absolute inset-0 opacity-[0.015]" style="background-image: repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(255,255,255,0.03) 2px, rgba(255,255,255,0.03) 4px)" />
      <svg class="absolute inset-0 w-full h-full opacity-[0.04]" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <pattern id="war-grid" width="60" height="60" patternUnits="userSpaceOnUse">
            <path d="M 60 0 L 0 0 0 60" fill="none" stroke="currentColor" stroke-width="0.4" class="text-gold" />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#war-grid)" />
      </svg>
      <div class="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2">
        <div class="w-[800px] h-[800px] rounded-full border border-gold/5 animate-ping-slow" />
        <div class="w-[500px] h-[500px] rounded-full border border-fuchsia-500/10 animate-ping-slower absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2" />
      </div>
      <div class="absolute top-1/4 -left-40 w-[500px] h-[500px] bg-fuchsia-500/5 rounded-full blur-3xl" />
      <div class="absolute bottom-1/3 -right-40 w-[400px] h-[400px] bg-gold/3 rounded-full blur-3xl" />
    </div>

    <div class="relative max-w-7xl mx-auto p-4 sm:p-6 lg:p-8">
      <!-- === Header === -->
      <div class="mb-8">
        <div class="flex items-center gap-3 mb-2">
          <NuxtLink
            to="/observatory"
            class="inline-flex items-center gap-1.5 text-[10px] font-mono text-gray-600 hover:text-gold transition-colors uppercase tracking-wider"
          >
            <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            {{ $t('observatory.nav') }}
          </NuxtLink>
          <span class="text-[10px] font-mono text-gray-700">|</span>
          <span class="text-[10px] font-mono text-gray-600 uppercase tracking-wider">{{ $t('observatory.war_room') }}</span>
        </div>
        <div class="flex items-center gap-3">
          <div class="w-2 h-2 rounded-full bg-red-500 animate-pulse" />
          <h1 class="text-xl sm:text-2xl font-bold text-white font-mono tracking-tight">{{ $t('observatory.dashboard_title') }}</h1>
        </div>
      </div>

      <!-- === Live Reactive Counters === -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 sm:gap-6 mb-10">
        <div class="rounded-2xl border border-slate-800 p-6 transition-all duration-300" style="background: rgba(10,10,10,0.85); backdrop-filter: blur(24px); box-shadow: inset 0 1px 0 rgba(255,255,255,0.03);">
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center shrink-0">
              <svg class="w-6 h-6 text-amber-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4.5c-.77-.833-2.694-.833-3.464 0L3.34 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
            </div>
            <div>
              <p class="text-3xl font-bold font-mono text-white tabular-nums animate-pulse-counter">{{ counters.total }}</p>
              <p class="text-[11px] font-mono text-gray-500 uppercase tracking-wider mt-0.5">{{ $t('observatory.total_threats') }}</p>
            </div>
          </div>
        </div>

        <div class="rounded-2xl border border-slate-800 p-6 transition-all duration-300" style="background: rgba(10,10,10,0.85); backdrop-filter: blur(24px); box-shadow: inset 0 1px 0 rgba(255,255,255,0.03);">
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl bg-fuchsia-500/10 border border-fuchsia-500/20 flex items-center justify-center shrink-0">
              <svg class="w-6 h-6 text-fuchsia-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
              </svg>
            </div>
            <div>
              <p class="text-3xl font-bold font-mono text-fuchsia-400 tabular-nums animate-pulse-counter">{{ counters.active }}</p>
              <p class="text-[11px] font-mono text-gray-500 uppercase tracking-wider mt-0.5">{{ $t('observatory.active_reviews') }}</p>
            </div>
          </div>
        </div>

        <div class="rounded-2xl border border-slate-800 p-6 transition-all duration-300" style="background: rgba(10,10,10,0.85); backdrop-filter: blur(24px); box-shadow: inset 0 1px 0 rgba(255,255,255,0.03);">
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-xl bg-green-500/10 border border-green-500/20 flex items-center justify-center shrink-0">
              <svg class="w-6 h-6 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <p class="text-3xl font-bold font-mono text-green-400 tabular-nums animate-pulse-counter">{{ counters.neutralized }}</p>
              <p class="text-[11px] font-mono text-gray-500 uppercase tracking-wider mt-0.5">{{ $t('observatory.total_neutralized') }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- === Main Grid: Threat Cards (3-col) + Analyst Sidebar === -->
      <div class="grid grid-cols-1 lg:grid-cols-4 gap-6 lg:gap-8">
        <div class="lg:col-span-3">
          <!-- Filter tabs -->
          <div class="flex items-center gap-2 mb-6">
            <span class="text-[10px] font-mono text-gray-600 uppercase tracking-wider">{{ $t('observatory.filter_label') }}</span>
            <button
              v-for="f in ['all', 'pending', 'under_review']"
              :key="f"
              class="px-3 py-1.5 text-[11px] font-mono font-medium rounded-lg border transition-all duration-200"
              :class="threatFilter === f
                ? 'bg-gold/10 text-gold border-gold/30'
                : 'bg-black/40 text-gray-500 border-slate-800 hover:border-slate-600 hover:text-gray-300'"
              @click="threatFilter = f as any"
            >
              {{ $t(`observatory.status_${f}`) }}
            </button>
          </div>

          <div v-if="loading" class="text-center py-20">
            <div class="inline-flex items-center gap-3 px-6 py-3 rounded-xl border border-slate-800" style="background: rgba(10,10,10,0.85);">
              <svg class="w-4 h-4 animate-spin text-gold" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
              </svg>
              <span class="text-xs font-mono text-gray-500">{{ $t('common.loading') }}</span>
            </div>
          </div>

          <div v-else-if="!filteredThreats.length" class="text-center py-20">
            <div class="rounded-2xl border border-slate-800 p-8 max-w-sm mx-auto" style="background: rgba(10,10,10,0.7);">
              <p class="text-sm font-mono text-gray-600">— {{ $t('observatory.no_threats') }} —</p>
            </div>
          </div>

          <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div
              v-for="threat in filteredThreats"
              :key="threat.id"
              class="rounded-2xl border transition-all duration-500 overflow-hidden"
              :class="[
                threat.status === 'neutralized'
                  ? 'border-green-500/30 shadow-lg shadow-green-500/5'
                  : 'border-slate-800 hover:border-slate-700',
              ]"
              :style="{ background: 'rgba(10,10,10,0.92)', backdropFilter: 'blur(16px)', boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.03)' }"
            >
              <div class="p-4 sm:p-5 flex flex-col h-full">
                <!-- Status bar -->
                <div class="flex items-center gap-1.5 mb-3">
                  <span
                    class="w-1.5 h-1.5 rounded-full"
                    :class="threat.status === 'neutralized' ? 'bg-green-500' : threat.status === 'under_review' ? 'bg-fuchsia-500 animate-pulse' : 'bg-amber-500'"
                  />
                  <span class="text-[10px] font-mono uppercase tracking-widest"
                    :class="threat.status === 'neutralized' ? 'text-green-500' : threat.status === 'under_review' ? 'text-fuchsia-400' : 'text-amber-400'"
                  >
                    {{ $t(`observatory.status_${threat.status}`) }}
                  </span>
                  <span v-if="threat.status === 'neutralized'" class="text-[9px] font-mono text-green-500/60 mr-auto">[{{ $t('observatory.status_queue_neutralized') }}]</span>
                </div>

                <!-- Intelligence Tags -->
                <div class="flex flex-wrap gap-1.5 mb-3">
                  <span class="px-2 py-0.5 text-[9px] font-mono font-bold rounded-md bg-blue-500/10 text-blue-400 border border-blue-500/20">[{{ $t('observatory.target_label') }} {{ tagTarget(threat.danger_level) }}]</span>
                  <span class="px-2 py-0.5 text-[9px] font-mono font-bold rounded-md bg-purple-500/10 text-purple-400 border border-purple-500/20">[{{ $t('observatory.platform_label') }} {{ tagSource(threat.platform) }}]</span>
                  <span class="px-2 py-0.5 text-[9px] font-mono font-bold rounded-md bg-fuchsia-500/10 text-fuchsia-400 border border-fuchsia-500/20">[{{ $t('observatory.status_label') }} {{ tagStatus(threat.status) }}]</span>
                </div>

                <!-- Platform + Danger badges -->
                <div class="flex items-center gap-1.5 mb-2">
                  <Badge :class="platformBadgeClass(threat.platform)" size="sm">
                    {{ $t(`observatory.platform_${threat.platform}`, threat.platform) }}
                  </Badge>
                  <Badge :class="dangerBadge(threat.danger_level)" size="sm">
                    {{ $t(`observatory.danger_${threat.danger_level.toLowerCase()}`) }}
                  </Badge>
                </div>

                <!-- Title -->
                <p class="text-sm font-medium text-gray-200 mb-1 leading-snug">{{ threat.title }}</p>

                <!-- Source URL -->
                <a
                  :href="threat.source_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-[11px] text-gold/60 hover:text-gold transition-colors truncate inline-block max-w-full mb-3"
                >
                  {{ threat.source_url }}
                </a>

                <!-- Spacer -->
                <div class="flex-1" />

                <!-- Actions (only for managers / super_admin) -->
                <div v-if="canManage" class="border-t border-slate-800 pt-3 mt-2 space-y-2">
                  <template v-if="threat.status !== 'neutralized'">
                    <!-- Status selector -->
                    <select
                      v-model="threat.status"
                      class="w-full px-3 py-2 text-[11px] font-mono bg-black/60 border border-slate-700 rounded-lg text-gray-300 focus:outline-none focus:border-fuchsia-500/50 transition-colors cursor-pointer"
                      @change="updateThreat(threat.id, { status: threat.status })"
                    >
                      <option value="pending" class="bg-black">{{ $t('observatory.status_pending') }}</option>
                      <option value="under_review" class="bg-black">{{ $t('observatory.status_under_review') }}</option>
                    </select>

                    <!-- Response URL inject -->
                    <div>
                      <label class="block text-[9px] font-mono text-gray-600 uppercase tracking-wider mb-1.5">[{{ $t('observatory.inject_countermeasure') }}]</label>
                      <div class="flex gap-2">
                        <input
                          v-model="threat.response_url"
                          type="url"
                          :placeholder="$t('observatory.response_url_placeholder')"
                          class="flex-1 min-w-0 px-3 py-2 text-[11px] font-mono bg-black/60 border border-slate-700 rounded-lg text-white placeholder-gray-700 focus:outline-none focus:border-green-500/50 transition-colors"
                          @keyup.enter="threat.response_url && updateThreat(threat.id, { status: 'neutralized', response_url: threat.response_url })"
                        />
                      </div>
                      <button
                        class="mt-2 w-full py-2 rounded-lg text-[11px] font-mono font-bold border transition-all duration-300"
                        :class="[
                          !threat.response_url
                            ? 'bg-slate-900 text-gray-700 border-slate-800 cursor-not-allowed'
                            : isUpdating(threat.id)
                              ? 'bg-green-900/30 text-green-500/50 border-green-500/20 cursor-wait'
                              : 'bg-green-600/20 text-green-400 border-green-500/40 hover:bg-green-600/30 hover:shadow-lg hover:shadow-green-500/10 active:scale-[0.98]',
                        ]"
                        :disabled="!threat.response_url || isUpdating(threat.id)"
                        @click="updateThreat(threat.id, { status: 'neutralized', response_url: threat.response_url })"
                      >
                        <span v-if="isUpdating(threat.id)" class="inline-flex items-center gap-2">
                          <svg class="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
                            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                          </svg>
                          {{ $t('common.loading') }}
                        </span>
                        <span v-else class="inline-flex items-center gap-1.5">
                          <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                          </svg>
                          {{ $t('observatory.action_neutralize') }}
                        </span>
                      </button>
                    </div>
                  </template>

                  <!-- Neutralized: Show response link -->
                  <div v-else-if="threat.response_url" class="pt-1">
                    <a
                      :href="threat.response_url"
                      target="_blank"
                      rel="noopener noreferrer"
                      class="inline-flex items-center gap-1.5 text-[11px] font-mono text-green-400/70 hover:text-green-300 transition-colors"
                    >
                      <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                      {{ $t('observatory.defense_view_response') }}
                    </a>
                    <button
                      v-if="canDelete"
                      class="mr-3 text-[10px] font-mono text-red-500/50 hover:text-red-400 transition-colors"
                      @click="deleteThreat(threat.id)"
                    >
                      {{ $t('observatory.action_delete') }}
                    </button>
                  </div>
                </div>

                <!-- Non-manager view: just show response link if exists -->
                <div v-else-if="threat.response_url" class="border-t border-slate-800 pt-3 mt-2">
                  <a
                    :href="threat.response_url"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="inline-flex items-center gap-1.5 text-[11px] font-mono text-green-400/70 hover:text-green-300 transition-colors"
                  >
                    <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                    </svg>
                    {{ $t('observatory.defense_view_response') }}
                  </a>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- === Analyst Management Sidebar === -->
        <div v-if="canManage" class="space-y-6">
          <div class="rounded-2xl border border-slate-800 p-5" style="background: rgba(10,10,10,0.92); backdrop-filter: blur(16px);">
            <div class="flex items-center gap-2 mb-5">
              <svg class="w-4 h-4 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
              </svg>
              <h2 class="text-sm font-bold font-mono text-white tracking-wide">{{ $t('observatory.analysts_title') }}</h2>
            </div>

            <form novalidate @submit.prevent="addAnalyst" class="space-y-2 mb-4">
              <div>
                <label class="block text-[9px] font-mono text-gray-600 uppercase tracking-wider mb-1.5">[{{ $t('observatory.add_analyst_label') }}]</label>
                <input
                  v-model="addAnalystEmail"
                  type="text"
                  placeholder="user@example.com"
                  class="w-full px-3 py-2 text-[11px] font-mono bg-black/60 border border-slate-700 rounded-lg text-white placeholder-gray-700 focus:outline-none focus:border-gold/50 transition-colors"
                />
              </div>
              <div>
                <label class="block text-[9px] font-mono text-gray-600 uppercase tracking-wider mb-1.5">[{{ $t('observatory.add_analyst_role') }}]</label>
                <div class="flex gap-2">
                  <button
                    type="button"
                    class="flex-1 py-2 rounded-lg text-[10px] font-mono font-bold border transition-all duration-200"
                    :class="addAnalystRole === 'observatory_analyst'
                      ? 'bg-blue-500/15 text-blue-400 border-blue-500/30'
                      : 'bg-black/40 text-gray-600 border-slate-800 hover:border-slate-700'"
                    @click="addAnalystRole = 'observatory_analyst'"
                  >
                    {{ $t('observatory.role_analyst_text') }}
                  </button>
                  <button
                    type="button"
                    class="flex-1 py-2 rounded-lg text-[10px] font-mono font-bold border transition-all duration-200"
                    :class="addAnalystRole === 'observatory_manager'
                      ? 'bg-amber-500/15 text-amber-400 border-amber-500/30'
                      : 'bg-black/40 text-gray-600 border-slate-800 hover:border-slate-700'"
                    @click="addAnalystRole = 'observatory_manager'"
                  >
                    {{ $t('observatory.role_manager_text') }}
                  </button>
                </div>
              </div>
              <button
                type="submit"
                class="w-full py-2.5 rounded-lg text-[11px] font-mono font-bold border transition-all duration-200"
                :class="addingAnalyst
                  ? 'bg-gold/20 text-gold/50 border-gold/20 cursor-wait'
                  : 'bg-gold/10 text-gold border-gold/30 hover:bg-gold/20 hover:shadow-lg hover:shadow-gold/5 active:scale-[0.98]'"
                :disabled="addingAnalyst"
              >
                <span v-if="addingAnalyst" class="inline-flex items-center gap-2">
                  <svg class="w-3 h-3 animate-spin" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  {{ $t('common.loading') }}
                </span>
                <span v-else>↑ {{ $t('observatory.analysts_add') }}</span>
              </button>
            </form>

            <div v-if="!analysts.length" class="text-center py-6">
              <p class="text-xs font-mono text-gray-600">— {{ $t('observatory.analysts_empty') }} —</p>
            </div>

            <div v-else class="space-y-2 max-h-[320px] overflow-y-auto pr-1">
              <div
                v-for="a in analysts"
                :key="a.id"
                class="flex items-center justify-between p-2.5 rounded-lg border transition-colors"
                :class="a.role_type === 'observatory_manager' ? 'border-amber-500/15 bg-amber-500/5' : 'border-slate-800 bg-black/40'"
              >
                <div class="min-w-0 flex-1">
                  <p class="text-[11px] font-mono text-gray-400 truncate">{{ a.id }}</p>
                  <span class="inline-block mt-0.5 text-[9px] font-mono font-bold px-1.5 py-0.5 rounded"
                    :class="a.role_type === 'observatory_manager'
                      ? 'bg-amber-500/15 text-amber-400'
                      : 'bg-blue-500/15 text-blue-400'"
                  >
                    {{ a.role_type === 'observatory_manager' ? $t('observatory.analyst_manager') : $t('observatory.analyst_analyst') }}
                  </span>
                </div>
                <button
                  class="text-[10px] font-mono text-red-500/50 hover:text-red-400 transition-colors px-2 py-1 rounded hover:bg-red-500/5"
                  :title="$t('observatory.analysts_remove')"
                  @click="removeAnalyst(a.id)"
                >
                  ✕
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
@keyframes ping-slow {
  0%, 100% { transform: translate(-50%, -50%) scale(1); opacity: 0.6; }
  50% { transform: translate(-50%, -50%) scale(1.05); opacity: 0.15; }
}
@keyframes ping-slower {
  0%, 100% { transform: translate(-50%, -50%) scale(1); opacity: 0.4; }
  50% { transform: translate(-50%, -50%) scale(1.08); opacity: 0.1; }
}
.animate-ping-slow {
  animation: ping-slow 4s ease-in-out infinite;
}
.animate-ping-slower {
  animation: ping-slower 6s ease-in-out infinite;
}

/* Pulsing counter animation */
@keyframes pulse-counter {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.85; }
}
.animate-pulse-counter {
  animation: pulse-counter 2.5s ease-in-out infinite;
}
</style>
