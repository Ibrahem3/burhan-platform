<script setup lang="ts">
import type { Database, Json } from '~/types/database'

definePageMeta({
  layout: 'dashboard',
  middleware: 'dashboard-auth',
  title: 'Content & Entities',
})

const supabase = useSupabaseClient<Database>()
const { t, locale } = useI18n()
const localePath = useLocalePath()
const { profile } = useUser()

type Entity = Database['public']['Tables']['entities']['Row']
type Branch = Database['public']['Tables']['branches']['Row']

interface Series {
  id: string
  organization_id: string
  branch_id: string
  title: { ar: string; en: string }
  description?: { ar: string; en: string }
  cover_url?: string
  is_active: boolean
  created_at: string
}

const entities = ref<Entity[]>([])
const branches = ref<Branch[]>([])
const seriesList = ref<Series[]>([])
const loading = ref(true)
const showModal = ref(false)
const editingId = ref<string | null>(null)
const submitting = ref(false)
const error = ref('')
const success = ref('')

const searchQuery = ref('')
const filterBranch = useCookie('entities-filter-branch', { default: () => '' })
const contentTypeFilter = ref<'all' | 'video' | 'article'>('all')
const deletingId = ref<string | null>(null)
const confirmId = ref<string | null>(null)
const brokenThumbnails = ref<string[]>([])

function isThumbnailBroken(id: string) {
  return brokenThumbnails.value.includes(id)
}

function markThumbnailBroken(id: string) {
  if (!brokenThumbnails.value.includes(id)) {
    brokenThumbnails.value.push(id)
  }
}

const form = reactive({
  title_ar: '',
  title_en: '',
  content_ar: '',
  content_en: '',
  content_type: 'video',
  branch_id: '',
  video_id: '',
  is_premium: false,
  is_public_to_hub: false,
  price: '',
  series_id: '',
  sort_order: 0,
})

const filteredFormSeries = computed(() => {
  if (!form.branch_id) return seriesList.value
  return seriesList.value.filter(s => s.branch_id === form.branch_id)
})

const isEditing = computed(() => editingId.value !== null)
const orgId = computed(() => profile.value?.organization_id)

const filteredEntities = computed(() => {
  let result = entities.value
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase()
    result = result.filter((e) => {
      const title = e.title as { ar?: string; en?: string }
      return title?.ar?.toLowerCase().includes(q) || title?.en?.toLowerCase().includes(q)
    })
  }
  if (filterBranch.value) {
    result = result.filter(e => e.branch_id === filterBranch.value)
  }
  if (contentTypeFilter.value !== 'all') {
    result = result.filter(e => contentTypeFilter.value === 'video'
      ? (e.video_id !== null && e.video_id !== '')
      : (e.video_id === null || e.video_id === '')
    )
  }
  return result
})

function isVideo(entity: Entity): boolean {
  return entity.video_id !== null && entity.video_id !== ''
}

function thumbnailUrl(entity: Entity): string | null {
  if (isVideo(entity) && entity.video_id) {
    return `https://img.youtube.com/vi/${entity.video_id}/hqdefault.jpg`
  }
  const content = entity.content as { image_url?: string } | null
  if (content?.image_url) {
    return content.image_url
  }
  return null
}

function branchName(branchId: string): string {
  const branch = branches.value.find(b => b.id === branchId)
  if (!branch) return ''
  const name = branch.name as { ar?: string; en?: string }
  return name?.[locale.value] || name?.ar || name?.en || ''
}

function seriesName(seriesId: string | null): string {
  if (!seriesId) return ''
  const s = seriesList.value.find(s => s.id === seriesId)
  if (!s) return ''
  return s.title?.[locale.value as keyof typeof s.title] || s.title?.ar || s.title?.en || ''
}

async function fetchData() {
  const id = orgId.value
  if (!id) return
  loading.value = true
  const [entitiesRes, branchesRes, seriesRes] = await Promise.all([
    supabase
      .from('entities')
      .select('*')
      .eq('organization_id', id)
      .order('created_at', { ascending: false }),
    supabase
      .from('branches')
      .select('*')
      .eq('organization_id', id)
      .eq('is_active', true)
      .order('created_at', { ascending: false }),
    supabase
      .from('series')
      .select('*')
      .eq('organization_id', id)
      .order('created_at', { ascending: false }),
  ])
  if (entitiesRes.data) entities.value = entitiesRes.data
  if (branchesRes.data) branches.value = branchesRes.data
  if (seriesRes.data) seriesList.value = seriesRes.data as unknown as Series[]
  loading.value = false
}

watch(orgId, (id) => {
  if (id) fetchData()
}, { immediate: true })

function openCreateModal() {
  editingId.value = null
  form.title_ar = ''
  form.title_en = ''
  form.content_ar = ''
  form.content_en = ''
  form.content_type = 'video'
  form.branch_id = branches.value[0]?.id || ''
  form.video_id = ''
  form.is_premium = false
  form.is_public_to_hub = false
  form.price = ''
  form.series_id = ''
  form.sort_order = 0
  error.value = ''
  showModal.value = true
}

function navigateToNew() {
  navigateTo(localePath('/dashboard/entities/new'))
}

function openEditModal(entity: Entity) {
  if (!isVideo(entity)) {
    navigateTo(localePath(`/dashboard/entities/${entity.id}`))
    return
  }
  editingId.value = entity.id
  const title = entity.title as { ar?: string; en?: string }
  const content = entity.content as { ar?: string; en?: string }
  const isVid = isVideo(entity)
  form.title_ar = title?.ar || ''
  form.title_en = title?.en || ''
  form.content_ar = content?.ar || ''
  form.content_en = content?.en || ''
  form.content_type = isVid ? 'video' : 'article'
  form.branch_id = entity.branch_id
  form.video_id = entity.video_id || ''
  form.is_premium = entity.is_premium
  form.is_public_to_hub = entity.is_public_to_hub
  form.price = entity.price ? String(entity.price) : ''
  form.series_id = (entity as any).series_id || ''
  form.sort_order = (entity as any).sort_order || 0
  error.value = ''
  showModal.value = true
}

async function submitEntity() {
  error.value = ''
  success.value = ''
  if (!form.title_ar || !form.title_en || !form.branch_id) {
    error.value = t('dashboard.validation.title_branch_required')
    return
  }
  if (form.content_type === 'video' && !form.video_id) {
    error.value = t('dashboard.validation.video_id_required')
    return
  }
  const id = orgId.value
  if (!id) {
    error.value = t('common.org_not_found')
    return
  }
  submitting.value = true
  const payload: Record<string, any> = {
    organization_id: id,
    branch_id: form.branch_id,
    title: { ar: form.title_ar, en: form.title_en } as Json,
    content: { ar: form.content_ar, en: form.content_en } as Json,
    is_public_to_hub: form.is_public_to_hub,
    is_premium: form.is_premium,
    video_id: form.content_type === 'video' ? form.video_id : null,
    primary_source: form.content_type === 'video' ? 'youtube' : '',
    price: form.is_premium && form.price ? parseFloat(form.price) : null,
    series_id: form.series_id || null,
    sort_order: form.sort_order,
  }
  if (isEditing.value) {
    const editId = editingId.value
    if (!editId) {
      submitting.value = false
      return
    }
    const { error: updateError } = await supabase
      .from('entities')
      .update(payload)
      .eq('id', editId)
    submitting.value = false
    if (updateError) {
      error.value = t('dashboard.entity_update_error')
      return
    }
    showModal.value = false
    success.value = t('dashboard.entity_updated')
  } else {
    const { error: insertError } = await supabase
      .from('entities')
      .insert(payload)
    submitting.value = false
    if (insertError) {
      error.value = t('dashboard.entity_create_error')
      return
    }
    showModal.value = false
    success.value = t('dashboard.entity_created')
  }
  await fetchData()
}

function requestDelete(id: string) {
  confirmId.value = id
}

function cancelDelete() {
  confirmId.value = null
}

async function confirmDelete() {
  const id = confirmId.value
  if (!id) return
  deletingId.value = id
  await supabase.from('entities').delete().eq('id', id)
  deletingId.value = null
  confirmId.value = null
  await fetchData()
}
</script>

<template>
  <div>
    <div v-if="success" class="mb-6 text-green-400 text-sm text-center bg-green-500/10 border border-green-500/20 rounded-xl px-4 py-3">
      {{ success }}
    </div>

    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <div>
        <h1 class="text-xl font-bold text-white">{{ $t('dashboard.entities_title') }}</h1>
        <p class="text-sm text-gray-500 mt-1">
          {{ $t('dashboard.total_content') }}:
          <span class="text-gold font-semibold">{{ entities.length }}</span>
        </p>
      </div>
      <div class="flex gap-2">
        <Button variant="outline" @click="navigateTo(localePath('/dashboard/series'))">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
          </svg>
          إدارة السلاسل والكورسات 📚
        </Button>
        <Button variant="outline" @click="navigateToNew">
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
          </svg>
          {{ $t('dashboard.type_article') }}
        </Button>
        <Button @click="openCreateModal">
          + {{ $t('dashboard.add_entity') }}
        </Button>
      </div>
    </div>

    <!-- Filters & Toolbar -->
    <div class="flex flex-col sm:flex-row gap-3 mb-6">
      <div class="relative flex-1">
        <svg class="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <input
          v-model="searchQuery"
          type="text"
          class="w-full px-4 py-2.5 pr-10 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 text-sm focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
          :placeholder="$t('common.search')"
        />
      </div>
      <select
        v-model="filterBranch"
        class="px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white text-sm focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200 min-w-[160px]"
      >
        <option value="">{{ $t('dashboard.all_branches') }}</option>
        <option v-for="b in branches" :key="b.id" :value="b.id">
          {{ localizedValue(b.name, locale) }}
        </option>
      </select>
    </div>

    <!-- Pill Tabs -->
    <div class="flex items-center gap-2 mb-6">
      <button
        class="px-4 py-1.5 rounded-lg text-xs font-medium transition-all duration-200"
        :class="contentTypeFilter === 'all' ? 'bg-gold/15 text-gold border border-gold/30 shadow-lg shadow-gold/5' : 'bg-white/5 text-gray-400 border border-white/10 hover:text-white hover:bg-white/10'"
        @click="contentTypeFilter = 'all'"
      >
        {{ $t('dashboard.all_content') }}
      </button>
      <button
        class="px-4 py-1.5 rounded-lg text-xs font-medium transition-all duration-200 flex items-center gap-1.5"
        :class="contentTypeFilter === 'video' ? 'bg-blue-500/15 text-blue-400 border border-blue-500/30 shadow-lg shadow-blue-500/5' : 'bg-white/5 text-gray-400 border border-white/10 hover:text-white hover:bg-white/10'"
        @click="contentTypeFilter = 'video'"
      >
        <span>{{ $t('dashboard.type_video') }}</span>
        <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
        </svg>
      </button>
      <button
        class="px-4 py-1.5 rounded-lg text-xs font-medium transition-all duration-200 flex items-center gap-1.5"
        :class="contentTypeFilter === 'article' ? 'bg-purple-500/15 text-purple-400 border border-purple-500/30 shadow-lg shadow-purple-500/5' : 'bg-white/5 text-gray-400 border border-white/10 hover:text-white hover:bg-white/10'"
        @click="contentTypeFilter = 'article'"
      >
        <span>{{ $t('dashboard.type_article') }}</span>
        <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
        </svg>
      </button>
    </div>

    <!-- Loading Skeleton -->
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
      <div v-for="i in 8" :key="i" class="glass rounded-2xl overflow-hidden animate-pulse">
        <div class="aspect-video bg-white/5" />
        <div class="p-4 space-y-3">
          <div class="h-4 bg-white/5 rounded w-3/4" />
          <div class="h-4 bg-white/5 rounded w-1/2" />
          <div class="flex gap-2">
            <div class="h-5 bg-white/5 rounded-full w-16" />
            <div class="h-5 bg-white/5 rounded-full w-14" />
          </div>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div v-else-if="filteredEntities.length === 0" class="glass rounded-2xl p-12 text-center">
      <div class="w-16 h-16 mx-auto mb-4 rounded-2xl bg-white/5 flex items-center justify-center">
        <svg class="w-8 h-8 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
      </div>
      <p class="text-gray-500 text-sm">{{ $t('dashboard.no_entities') }}</p>
    </div>

    <!-- Premium Content Grid -->
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
      <div
        v-for="entity in filteredEntities"
        :key="entity.id"
        class="group glass rounded-2xl overflow-hidden border border-white/5 hover:border-gold/20 transition-all duration-500 relative"
      >
        <!-- Thumbnail -->
        <div class="relative aspect-video overflow-hidden bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900">
          <!-- Thumbnail image -->
          <img
            v-if="thumbnailUrl(entity) && !isThumbnailBroken(entity.id)"
            :src="thumbnailUrl(entity)"
            :alt="localizedValue(entity.title, locale)"
            class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
            loading="lazy"
            @error="markThumbnailBroken(entity.id)"
          />
          <!-- Article / fallback -->
          <div
            v-else
            class="w-full h-full bg-gradient-to-br from-purple-900/40 via-gray-800 to-blue-900/40 flex items-center justify-center"
          >
            <svg class="w-10 h-10 text-white/10" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
            </svg>
          </div>

          <!-- Play button overlay (video) -->
          <div
            v-if="isVideo(entity)"
            class="absolute inset-0 flex items-center justify-center bg-black/0 group-hover:bg-black/30 transition-all duration-500"
          >
            <div class="w-12 h-12 rounded-full bg-white/10 backdrop-blur border border-white/20 flex items-center justify-center transition-transform duration-500 group-hover:scale-110">
              <svg class="w-5 h-5 text-white ml-0.5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z" />
              </svg>
            </div>
          </div>

          <!-- Type badge -->
          <div class="absolute top-3 left-3">
            <span
              class="inline-flex items-center gap-1 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wider rounded-md backdrop-blur-sm"
              :class="isVideo(entity) ? 'bg-blue-500/20 text-blue-300 border border-blue-500/30' : 'bg-purple-500/20 text-purple-300 border border-purple-500/30'"
            >
              <svg v-if="isVideo(entity)" class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
              <svg v-else class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
              </svg>
              {{ isVideo(entity) ? $t('dashboard.type_video') : $t('dashboard.type_article') }}
            </span>
          </div>

          <!-- Hover actions -->
          <div class="absolute inset-x-0 bottom-0 p-3 bg-gradient-to-t from-black/80 via-black/40 to-transparent opacity-0 group-hover:opacity-100 transition-all duration-500 translate-y-2 group-hover:translate-y-0">
            <div class="flex items-center justify-end gap-2">
              <button
                class="p-2 rounded-lg bg-white/10 backdrop-blur border border-white/20 text-white hover:bg-gold/20 hover:text-gold hover:border-gold/30 transition-all duration-200"
                :title="$t('common.edit')"
                @click="openEditModal(entity)"
              >
                <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
              </button>
              <button
                class="p-2 rounded-lg bg-white/10 backdrop-blur border border-white/20 text-white hover:bg-red-500/20 hover:text-red-400 hover:border-red-500/30 transition-all duration-200"
                :title="$t('common.delete')"
                @click="requestDelete(entity.id)"
              >
                <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </button>
            </div>
          </div>
        </div>

        <!-- Card Body -->
        <div class="p-4">
          <p class="text-sm font-medium text-white leading-snug line-clamp-2 min-h-[2.5rem]">
            {{ localizedValue(entity.title, locale) }}
          </p>
          <div class="flex items-center gap-2 mt-3 flex-wrap">
            <span class="inline-flex items-center px-2 py-0.5 text-[10px] font-medium rounded-full bg-white/5 text-gray-400 border border-white/10">
              {{ branchName(entity.branch_id) }}
            </span>
            <span
              v-if="(entity as any).series_id"
              class="inline-flex items-center gap-1 px-2 py-0.5 text-[10px] font-medium rounded-full bg-amber-500/10 text-amber-400 border border-amber-500/20"
            >
              <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
              </svg>
              {{ seriesName((entity as any).series_id) }}
            </span>
            <span
              class="inline-flex items-center gap-1 px-2 py-0.5 text-[10px] font-medium rounded-full"
              :class="entity.is_premium ? 'bg-gold/15 text-gold border border-gold/20' : 'bg-green-500/10 text-green-400 border border-green-500/20'"
            >
              <svg v-if="entity.is_premium" class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
              </svg>
              {{ entity.is_premium ? $t('dashboard.access_premium') : $t('dashboard.access_free') }}
            </span>
          </div>
        </div>

        <!-- Delete Confirmation Overlay -->
        <Transition name="fade">
          <div
            v-if="confirmId === entity.id"
            class="absolute inset-0 z-10 bg-black/80 backdrop-blur-sm rounded-2xl flex items-center justify-center p-4"
          >
            <div class="text-center">
              <div class="w-10 h-10 mx-auto mb-3 rounded-full bg-red-500/20 flex items-center justify-center">
                <svg class="w-5 h-5 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z" />
                </svg>
              </div>
              <p class="text-xs text-gray-300 mb-3 px-2">{{ $t('dashboard.confirm_delete_entity') }}</p>
              <div class="flex items-center justify-center gap-2">
                <button
                  class="px-3 py-1.5 rounded-lg text-xs font-medium bg-red-500/20 text-red-400 border border-red-500/30 hover:bg-red-500/30 transition-all"
                  :disabled="deletingId === entity.id"
                  @click="confirmDelete"
                >
                  {{ $t('common.delete') }}
                </button>
                <button
                  class="px-3 py-1.5 rounded-lg text-xs font-medium bg-white/10 text-gray-400 border border-white/10 hover:bg-white/20 transition-all"
                  @click="cancelDelete"
                >
                  {{ $t('common.cancel') }}
                </button>
              </div>
            </div>
          </div>
        </Transition>
      </div>
    </div>

    <!-- Inline Create/Edit Modal -->
    <Transition name="fade">
      <div
        v-if="showModal"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
      >
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="showModal = false" />
        <div class="relative w-full max-w-xl glass rounded-2xl p-6 lg:p-8 border border-white/5 max-h-[90vh] overflow-y-auto">
          <h2 class="text-lg font-bold text-white mb-6">
            {{ isEditing ? $t('dashboard.edit_entity_title') : $t('dashboard.create_entity_title') }}
          </h2>

          <form novalidate @submit.prevent="submitEntity">
            <div class="space-y-4">
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-400 mb-1.5">
                    {{ $t('dashboard.entity_title_ar') }}
                  </label>
                  <input
                    v-model="form.title_ar"
                    type="text"
                    class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                    :disabled="submitting"
                    required
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-400 mb-1.5">
                    {{ $t('dashboard.entity_title_en') }}
                  </label>
                  <input
                    v-model="form.title_en"
                    type="text"
                    dir="ltr"
                    class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                    :disabled="submitting"
                    required
                  />
                </div>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-400 mb-1.5">
                    {{ $t('dashboard.content_type') }}
                  </label>
                  <select
                    v-model="form.content_type"
                    class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                    :disabled="submitting"
                  >
                    <option value="video">{{ $t('dashboard.type_video') }}</option>
                    <option value="article">{{ $t('dashboard.type_article') }}</option>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-400 mb-1.5">
                    {{ $t('dashboard.target_branch') }}
                  </label>
                  <select
                    v-model="form.branch_id"
                    class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                    :disabled="submitting"
                  >
                    <option v-for="b in branches" :key="b.id" :value="b.id">
                      {{ localizedValue(b.name, locale) }}
                    </option>
                  </select>
                </div>
              </div>

              <div v-if="form.content_type === 'video'">
                <label class="block text-sm font-medium text-gray-400 mb-1.5">
                  {{ $t('dashboard.video_id') }}
                </label>
                <input
                  v-model="form.video_id"
                  type="text"
                  dir="ltr"
                  class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 font-mono text-sm focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                  :disabled="submitting"
                  :placeholder="$t('dashboard.video_id_placeholder')"
                />
              </div>

              <div v-if="form.content_type === 'article'" class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-400 mb-1.5">
                    {{ $t('dashboard.entity_content_ar') }}
                  </label>
                  <textarea
                    v-model="form.content_ar"
                    rows="3"
                    class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200 resize-none"
                    :disabled="submitting"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-400 mb-1.5">
                    {{ $t('dashboard.entity_content_en') }}
                  </label>
                  <textarea
                    v-model="form.content_en"
                    rows="3"
                    dir="ltr"
                    class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200 resize-none"
                    :disabled="submitting"
                  />
                </div>
              </div>

              <div class="flex items-center gap-3">
                <label class="relative inline-flex cursor-pointer items-center">
                  <input
                    v-model="form.is_premium"
                    type="checkbox"
                    class="peer sr-only"
                    :disabled="submitting"
                  />
                  <div class="h-5 w-9 rounded-full bg-white/10 after:absolute after:left-[3px] after:top-[3px] after:h-3.5 after:w-3.5 after:rounded-full after:bg-white after:transition-all after:duration-200 peer-checked:bg-gold peer-checked:after:translate-x-[18px]" />
                </label>
                <span class="text-sm text-gray-400">{{ $t('dashboard.premium_toggle') }}</span>

                <div v-if="form.is_premium" class="flex-1 max-w-[160px]">
                  <input
                    v-model="form.price"
                    type="number"
                    step="0.01"
                    min="0"
                    dir="ltr"
                    placeholder="0.00"
                    class="w-full px-3 py-1.5 bg-white/5 border border-white/10 rounded-lg text-white text-sm placeholder-gray-600 focus:outline-none focus:border-gold/50 transition-all duration-200"
                    :disabled="submitting"
                  />
                </div>
              </div>

              <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm font-medium text-gray-400 mb-1.5">
                    السلسلة / الكورس (اختياري)
                  </label>
                  <select
                    v-model="form.series_id"
                    class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white text-sm focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                    :disabled="submitting"
                  >
                    <option value="">— بدون سلسلة —</option>
                    <option v-for="s in filteredFormSeries" :key="s.id" :value="s.id">
                      {{ s.title?.[locale as keyof typeof s.title] || s.title?.ar || s.title?.en }}
                    </option>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-400 mb-1.5">
                    ترتيب الدرس
                  </label>
                  <input
                    v-model.number="form.sort_order"
                    type="number"
                    min="0"
                    step="1"
                    class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white text-sm focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                    :disabled="submitting"
                    placeholder="0"
                  />
                </div>
              </div>

              <div class="flex items-center gap-3">
                <label class="relative inline-flex cursor-pointer items-center">
                  <input
                    v-model="form.is_public_to_hub"
                    type="checkbox"
                    class="peer sr-only"
                    :disabled="submitting"
                  />
                  <div class="h-5 w-9 rounded-full bg-white/10 after:absolute after:left-[3px] after:top-[3px] after:h-3.5 after:w-3.5 after:rounded-full after:bg-white after:transition-all after:duration-200 peer-checked:bg-gold peer-checked:after:translate-x-[18px]" />
                </label>
                <span class="text-sm text-gray-400">{{ $t('dashboard.hub_visibility') }}</span>
              </div>

              <div v-if="error" class="text-red-400 text-sm text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
                {{ error }}
              </div>

              <div class="flex gap-3 pt-2">
                <Button variant="outline" :disabled="submitting" @click="showModal = false">
                  {{ $t('common.cancel') }}
                </Button>
                <Button type="submit" block :loading="submitting">
                  {{ isEditing ? $t('common.save') : $t('dashboard.add_entity') }}
                </Button>
              </div>
            </div>
          </form>
        </div>
      </div>
    </Transition>

  </div>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
