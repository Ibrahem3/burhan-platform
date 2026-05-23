<script setup lang="ts">
import type { Database, Json } from '~/types/database'
import { compressImage } from '~/utils/compressImage'

definePageMeta({
  layout: 'dashboard',
  middleware: 'dashboard-auth',
  title: 'Series Detail',
})

const supabase = useSupabaseClient<Database>()
const { t, locale } = useI18n()
const localePath = useLocalePath()
const { profile } = useUser()
const { uploadFile, uploading: isUploading } = useSupabaseStorage()
const route = useRoute()

type Branch = Database['public']['Tables']['branches']['Row']
type Entity = Database['public']['Tables']['entities']['Row']

interface Series {
  id: string
  organization_id: string
  branch_id: string
  title: Json
  description?: Json
  cover_url?: string
  is_active: boolean
  created_at: string
}

interface LinkedEntity {
  id: string
  title: Json
  content: Json
  branch_id: string
  sort_order: number
  video_id: string | null
  primary_source: string
  content_type: string | null
  audio_url: string | null
  audio_file: string | null
  is_premium: boolean
  created_at: string
}

const seriesId = route.params.id as string
const orgId = computed(() => profile.value?.organization_id)

const series = ref<Series | null>(null)
const branches = ref<Branch[]>([])
const episodes = ref<LinkedEntity[]>([])
const loading = ref(true)
const notFound = ref(false)
const error = ref('')
const savingMeta = ref(false)
const metaSuccess = ref(false)
const deletingId = ref<string | null>(null)
const confirmDeleteId = ref<string | null>(null)

// Inline edit mode
const editingMeta = ref(false)
const editForm = reactive({
  title_ar: '',
  title_en: '',
  description_ar: '',
  description_en: '',
  branch_id: '',
})

// Add episode
const showAddEpisode = ref(false)
const episodeSaving = ref(false)
const episodeForm = reactive({
  title_ar: '',
  title_en: '',
  content_type: 'article' as 'article' | 'video' | 'audio',
  is_premium: false,
  is_public_to_hub: false,
  audio_url: '',
  audio_file_url: '',
})

function localizedTitle(obj: Json): string {
  const t = obj as Record<string, string>
  return t[locale.value] || t.ar || t.en || ''
}

function localizedDescription(obj: Json | undefined): string {
  if (!obj) return ''
  const d = obj as Record<string, string>
  return d[locale.value] || d.ar || d.en || ''
}

function branchName(branchId: string): string {
  const b = branches.value.find(b => b.id === branchId)
  if (!b) return ''
  const name = b.name as Record<string, string>
  return name[locale.value] || name.ar || name.en || ''
}

async function fetchData() {
  const id = orgId.value
  if (!id) { loading.value = false; return }
  loading.value = true
  notFound.value = false

  const { data: bData } = await supabase
    .from('branches')
    .select('*')
    .eq('organization_id', id)
    .eq('is_active', true)
  if (bData) branches.value = bData

  const { data: sData, error: sErr } = await supabase
    .from('series')
    .select('*')
    .eq('id', seriesId)
    .eq('organization_id', id)
    .single()
  if (sErr || !sData) {
    notFound.value = true
    loading.value = false
    return
  }
  series.value = sData as unknown as Series

  const t = series.value.title as Record<string, string>
  const d = series.value.description as Record<string, string> | undefined
  editForm.title_ar = t.ar || ''
  editForm.title_en = t.en || ''
  editForm.description_ar = d?.ar || ''
  editForm.description_en = d?.en || ''
  editForm.branch_id = series.value.branch_id

  const { data: eData } = await supabase
    .from('entities')
    .select('id, title, content, branch_id, sort_order, video_id, primary_source, content_type, audio_url, audio_file, is_premium, created_at')
    .eq('series_id', seriesId)
    .eq('organization_id', id)
    .order('sort_order', { ascending: true })
    .order('created_at', { ascending: true })
  if (eData) episodes.value = eData as unknown as LinkedEntity[]

  loading.value = false
}

watch(orgId, fetchData, { immediate: true })

// --- Meta edit ---
async function saveMeta() {
  savingMeta.value = true
  metaSuccess.value = false
  error.value = ''
  const { error: uErr } = await supabase
    .from('series')
    .update({
      title: { ar: editForm.title_ar, en: editForm.title_en } as Json,
      description: { ar: editForm.description_ar, en: editForm.description_en } as Json,
      branch_id: editForm.branch_id,
    })
    .eq('id', seriesId)
  savingMeta.value = false
  if (uErr) {
    error.value = uErr.message
    return
  }
  metaSuccess.value = true
  editingMeta.value = false
  series.value = {
    ...series.value!,
    title: { ar: editForm.title_ar, en: editForm.title_en } as Json,
    description: { ar: editForm.description_ar, en: editForm.description_en } as Json,
    branch_id: editForm.branch_id,
  }
}

function cancelMeta() {
  if (!series.value) return
  const t = series.value.title as Record<string, string>
  const d = series.value.description as Record<string, string> | undefined
  editForm.title_ar = t.ar || ''
  editForm.title_en = t.en || ''
  editForm.description_ar = d?.ar || ''
  editForm.description_en = d?.en || ''
  editForm.branch_id = series.value.branch_id
  editingMeta.value = false
}

// --- Cover upload ---
const fileInput = ref<HTMLInputElement | null>(null)

function triggerCoverUpload() {
  fileInput.value?.click()
}

async function onCoverSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  const id = orgId.value
  if (!id) return
  const compressed = await compressImage(file)
  if (!compressed) return
  const url = await uploadFile(compressed, id)
  if (url) {
    await supabase.from('series').update({ cover_url: url }).eq('id', seriesId)
    if (series.value) series.value.cover_url = url
  }
  input.value = ''
}

// --- Episode Edit ---
const editingEpisodeId = ref<string | null>(null)
const episodeEditSaving = ref(false)
const episodeEditForm = reactive({
  title_ar: '',
  title_en: '',
  content_type: 'article' as 'article' | 'video' | 'audio',
  is_premium: false,
  is_public_to_hub: false,
  audio_url: '',
  video_id: '',
})

function openEditEpisode(ep: LinkedEntity) {
  editingEpisodeId.value = ep.id
  const t = ep.title as Record<string, string>
  episodeEditForm.title_ar = t.ar || ''
  episodeEditForm.title_en = t.en || ''
  episodeEditForm.content_type = (ep.content_type as any) || 'article'
  episodeEditForm.is_premium = ep.is_premium
  episodeEditForm.is_public_to_hub = (ep as any).is_public_to_hub ?? false
  episodeEditForm.audio_url = ep.audio_url || ''
  episodeEditForm.video_id = ep.video_id || ''
  error.value = ''
}

function cancelEditEpisode() {
  editingEpisodeId.value = null
}

async function saveEditEpisode() {
  const epId = editingEpisodeId.value
  if (!epId) return
  if (!episodeEditForm.title_ar || !episodeEditForm.title_en) {
    error.value = 'العنوان (بالعربية والإنجليزية) مطلوب'
    return
  }
  episodeEditSaving.value = true
  error.value = ''

  const payload: Record<string, any> = {
    title: { ar: episodeEditForm.title_ar, en: episodeEditForm.title_en } as Json,
    content_type: episodeEditForm.content_type,
    is_premium: episodeEditForm.is_premium,
    is_public_to_hub: episodeEditForm.is_public_to_hub,
  }

  if (episodeEditForm.content_type === 'video') {
    payload.video_id = episodeEditForm.video_id || null
    payload.primary_source = episodeEditForm.video_id ? 'youtube' : ''
    payload.audio_url = null
  } else if (episodeEditForm.content_type === 'audio') {
    payload.audio_url = episodeEditForm.audio_url || null
    payload.video_id = null
    payload.primary_source = ''
  } else {
    payload.video_id = null
    payload.primary_source = ''
    payload.audio_url = null
  }

  const { error: uErr } = await supabase
    .from('entities')
    .update(payload)
    .eq('id', epId)

  episodeEditSaving.value = false
  if (uErr) {
    error.value = uErr.message
    return
  }

  editingEpisodeId.value = null
  await fetchData()
}

// --- Episode CRUD ---
async function addEpisode() {
  error.value = ''
  if (!episodeForm.title_ar || !episodeForm.title_en) {
    error.value = 'العنوان (بالعربية والإنجليزية) مطلوب'
    return
  }
  const id = orgId.value
  if (!id || !series.value) return

  episodeSaving.value = true
  const maxOrder = episodes.value.reduce((max, e) => Math.max(max, e.sort_order), -1)
  const newSortOrder = maxOrder + 1

  const title = { ar: episodeForm.title_ar, en: episodeForm.title_en }
  const payload: Record<string, any> = {
    organization_id: id,
    branch_id: series.value.branch_id,
    series_id: seriesId,
    sort_order: newSortOrder,
    title: title as Json,
    content: { ar: '', en: '' } as Json,
    primary_source: '',
    is_premium: episodeForm.is_premium,
    is_public_to_hub: episodeForm.is_public_to_hub,
    content_type: episodeForm.content_type,
  }

  if (episodeForm.content_type === 'audio') {
    payload.audio_url = episodeForm.audio_url || null
    payload.audio_file = episodeForm.audio_file_url || null
  }

  const { error: insErr } = await supabase
    .from('entities')
    .insert(payload as any)

  episodeSaving.value = false
  if (insErr) {
    error.value = insErr.message
    return
  }
  episodeForm.title_ar = ''
  episodeForm.title_en = ''
  episodeForm.is_premium = false
  episodeForm.is_public_to_hub = false
  episodeForm.audio_url = ''
  episodeForm.audio_file_url = ''
  showAddEpisode.value = false
  await fetchData()
}

async function removeFromSeries(entityId: string) {
  const { error: uErr } = await supabase
    .from('entities')
    .update({ series_id: null, sort_order: 0 })
    .eq('id', entityId)
  if (!uErr) {
    episodes.value = episodes.value.filter(e => e.id !== entityId)
  }
  confirmDeleteId.value = null
}

async function deleteEntity(entityId: string) {
  const { error: dErr } = await supabase
    .from('entities')
    .delete()
    .eq('id', entityId)
  if (!dErr) {
    episodes.value = episodes.value.filter(e => e.id !== entityId)
  }
  confirmDeleteId.value = null
}

async function moveUp(entity: LinkedEntity, index: number) {
  if (index === 0) return
  const above = episodes.value[index - 1]
  const tempOrder = entity.sort_order
  await supabase.from('entities').update({ sort_order: above.sort_order }).eq('id', entity.id)
  await supabase.from('entities').update({ sort_order: tempOrder }).eq('id', above.id)
  episodes.value[index] = { ...above, sort_order: tempOrder }
  episodes.value[index - 1] = { ...entity, sort_order: above.sort_order }
}

async function moveDown(entity: LinkedEntity, index: number) {
  if (index >= episodes.value.length - 1) return
  const below = episodes.value[index + 1]
  const tempOrder = entity.sort_order
  await supabase.from('entities').update({ sort_order: below.sort_order }).eq('id', entity.id)
  await supabase.from('entities').update({ sort_order: tempOrder }).eq('id', below.id)
  episodes.value[index] = { ...below, sort_order: tempOrder }
  episodes.value[index + 1] = { ...entity, sort_order: below.sort_order }
}

function episodeType(entity: LinkedEntity): string {
  const ct = entity.content_type
  if (ct === 'audio') return '🎙️ صوتيات / بودكاست'
  if (ct === 'video' || entity.video_id) return '🎬 فيديو'
  return '📝 مقال'
}

function episodeContentSummary(entity: LinkedEntity): string {
  const c = entity.content as Record<string, string>
  const text = c[locale.value] || c.ar || c.en || ''
  return text.replace(/<[^>]*>/g, '').substring(0, 100)
}
</script>

<template>
  <div>
    <div v-if="loading" class="flex items-center justify-center py-20">
      <span class="text-gold animate-pulse font-bold">جاري التحميل...</span>
    </div>

    <div v-else-if="notFound" class="flex flex-col items-center justify-center py-20">
      <p class="text-gray-500 font-bold mb-2">السلسلة غير موجودة</p>
      <Button variant="outline" @click="navigateTo(localePath('/dashboard/series'))">← العودة إلى السلاسل</Button>
    </div>

    <div v-else-if="series" class="space-y-8">
      <div v-if="error" class="text-red-400 text-sm text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3">{{ error }}</div>

      <!-- ===== Top Row: Series Metadata ===== -->
      <div class="glass rounded-2xl border border-white/5 overflow-hidden">
        <!-- Edit meta header -->
          <div v-if="!editingMeta" class="flex flex-col md:flex-row items-start gap-4 md:gap-6 p-4 sm:p-6">
          <div class="relative w-full md:w-48 shrink-0 aspect-video rounded-xl overflow-hidden bg-white/5 border border-white/5 group cursor-pointer" @click="triggerCoverUpload">
            <img v-if="series.cover_url" :src="series.cover_url" class="w-full h-full object-cover transition-transform group-hover:scale-105" />
            <div v-else class="w-full h-full flex items-center justify-center">
              <svg class="w-8 h-8 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
              </svg>
            </div>
            <div class="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center backdrop-blur-sm">
              <span class="text-xs font-bold text-white">تغيير الغلاف</span>
            </div>
            <input ref="fileInput" type="file" accept="image/*" class="hidden" @change="onCoverSelected" />
            <div v-if="isUploading" class="absolute inset-0 bg-black/60 z-10 flex items-center justify-center rounded-xl backdrop-blur-sm">
              <span class="text-gold text-xs font-bold animate-pulse">جاري الرفع...</span>
            </div>
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-start justify-between gap-4">
              <div class="min-w-0">
                <h1 class="text-xl font-bold text-white">{{ localizedTitle(series.title) }}</h1>
                <p v-if="series.description" class="text-sm text-gray-400 mt-1 line-clamp-2">{{ localizedDescription(series.description) }}</p>
                <div class="flex items-center gap-3 mt-3">
                  <span class="px-2.5 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wider bg-white/5 border border-white/10 text-gray-300">
                    {{ branchName(series.branch_id) }}
                  </span>
                  <span class="text-[11px] text-gray-500">{{ episodes.length }} حلقة / مادة</span>
                  <span class="flex items-center gap-1.5 text-[11px]" :class="series.is_active ? 'text-green-400' : 'text-red-400'">
                    <span class="w-1.5 h-1.5 rounded-full" :class="series.is_active ? 'bg-green-400' : 'bg-red-400'" />
                    {{ series.is_active ? 'منشور' : 'غير منشور' }}
                  </span>
                </div>
              </div>
              <Button variant="outline" size="sm" @click="editingMeta = true">
                تعديل البيانات
              </Button>
            </div>
          </div>
        </div>

        <!-- Inline edit form -->
        <div v-else class="p-6 space-y-5">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-bold text-gold uppercase tracking-wider">تعديل بيانات السلسلة</h2>
            <div class="flex gap-2">
              <Button variant="outline" size="sm" @click="cancelMeta">إلغاء</Button>
              <Button size="sm" :loading="savingMeta" @click="saveMeta">حفظ</Button>
            </div>
          </div>
          <div v-if="metaSuccess" class="text-green-400 text-xs bg-green-500/10 border border-green-500/20 rounded-lg px-3 py-2">تم حفظ التغييرات</div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <input v-model="editForm.title_ar" type="text" placeholder="العنوان بالعربية" class="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2.5 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-gold/50" />
            <input v-model="editForm.title_en" type="text" dir="ltr" placeholder="Title (English)" class="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2.5 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-gold/50" />
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <textarea v-model="editForm.description_ar" rows="3" placeholder="الوصف بالعربية" class="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2.5 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-gold/50 resize-none" />
            <textarea v-model="editForm.description_en" dir="ltr" rows="3" placeholder="Description (English)" class="w-full bg-white/5 border border-white/10 rounded-lg px-3 py-2.5 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-gold/50 resize-none" />
          </div>
          <AppSelect
            :model-value="editForm.branch_id"
            :options="branches.map(b => ({ value: b.id, label: localizedValue(b.name, locale) }))"
            placeholder=" "
            @update:model-value="editForm.branch_id = $event"
          />
        </div>
      </div>

      <!-- ===== Episodes Section ===== -->
      <div class="glass rounded-2xl border border-white/5 p-6">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h2 class="text-lg font-bold text-white">الحلقات والمواد التعليمية</h2>
            <p class="text-sm text-gray-500 mt-0.5">{{ episodes.length }} عنصر — رتبها باستخدام أزرار الترتيب</p>
          </div>
          <Button @click="showAddEpisode = !showAddEpisode">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
            </svg>
            {{ showAddEpisode ? 'إلغاء' : '+ إضافة حلقة / مادة للسلسلة' }}
          </Button>
        </div>

        <!-- Add Episode Form -->
        <Transition name="fade">
          <div v-if="showAddEpisode" class="mb-6 glass rounded-xl p-5 border border-gold/20 bg-gold/[0.02]">
            <h3 class="text-sm font-bold text-gold mb-4">إضافة محتوى جديد للسلسلة</h3>
            <div class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <input v-model="episodeForm.title_ar" type="text" placeholder="العنوان بالعربية" class="w-full bg-black/40 border border-white/10 rounded-lg px-3 py-2.5 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-gold/50" />
                <input v-model="episodeForm.title_en" type="text" dir="ltr" placeholder="Title (English)" class="w-full bg-black/40 border border-white/10 rounded-lg px-3 py-2.5 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-gold/50" />
              </div>
              <div class="flex items-center gap-6 flex-wrap">
                <AppSelect
                  :model-value="episodeForm.content_type"
                  :options="[
                    { value: 'article', label: '📝 مقال' },
                    { value: 'video', label: '🎬 فيديو' },
                    { value: 'audio', label: '🎙️ صوتيات / بودكاست' },
                  ]"
                  placeholder=" "
                  @update:model-value="episodeForm.content_type = $event"
                />
                <label class="flex items-center gap-2 text-sm text-gray-400 cursor-pointer">
                  <input v-model="episodeForm.is_premium" type="checkbox" class="accent-gold" />
                  محتوى مدفوع
                </label>
                <label class="flex items-center gap-2 text-sm text-gray-400 cursor-pointer">
                  <input v-model="episodeForm.is_public_to_hub" type="checkbox" class="accent-gold" />
                  منشور في الـ Hub
                </label>
              </div>
              <div v-if="episodeForm.content_type === 'audio'" class="space-y-3">
                <div class="flex items-center gap-3">
                  <svg class="w-5 h-5 text-purple-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                  </svg>
                  <input v-model="episodeForm.audio_url" type="text" dir="ltr" placeholder="رابط البث الخارجي (مثل SoundCloud, Spotify embed URL)" class="flex-1 bg-black/40 border border-white/10 rounded-lg px-3 py-2.5 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-gold/50" />
                </div>
              </div>
              <div class="flex gap-2">
                <Button :loading="episodeSaving" @click="addEpisode">إضافة</Button>
                <Button variant="outline" @click="showAddEpisode = false">إلغاء</Button>
              </div>
            </div>
          </div>
        </Transition>

        <!-- Episodes list -->
        <div v-if="episodes.length === 0 && !showAddEpisode" class="text-center py-12">
          <div class="w-16 h-16 rounded-full bg-white/5 border border-white/10 flex items-center justify-center mx-auto mb-3">
            <svg class="w-8 h-8 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
            </svg>
          </div>
          <p class="text-gray-500 font-bold mb-1">لا توجد حلقات بعد</p>
          <p class="text-gray-600 text-sm mb-4">أضف أول حلقة أو مادة تعليمية لهذه السلسلة</p>
          <Button @click="showAddEpisode = true">+ إضافة حلقة / مادة</Button>
        </div>

        <div v-else class="space-y-2">
          <template v-for="(ep, i) in episodes" :key="ep.id">
            <!-- Edit form -->
            <div
              v-if="editingEpisodeId === ep.id"
              class="glass rounded-xl p-4 sm:p-5 border border-gold/20 bg-gold/[0.02] space-y-4"
            >
              <div class="flex items-center justify-between">
                <h4 class="text-sm font-bold text-gold">تعديل الحلقة</h4>
                <div class="flex gap-2">
                  <Button variant="outline" size="sm" @click="cancelEditEpisode">إلغاء</Button>
                  <Button size="sm" :loading="episodeEditSaving" @click="saveEditEpisode">حفظ</Button>
                </div>
              </div>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <input v-model="episodeEditForm.title_ar" type="text" placeholder="العنوان بالعربية" class="w-full bg-black/40 border border-white/10 rounded-lg px-3 py-2.5 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-gold/50" />
                <input v-model="episodeEditForm.title_en" type="text" dir="ltr" placeholder="Title (English)" class="w-full bg-black/40 border border-white/10 rounded-lg px-3 py-2.5 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-gold/50" />
              </div>
              <div class="flex items-center gap-4 flex-wrap">
                <AppSelect
                  :model-value="episodeEditForm.content_type"
                  :options="[
                    { value: 'article', label: '📝 مقال' },
                    { value: 'video', label: '🎬 فيديو' },
                    { value: 'audio', label: '🎙️ صوتيات / بودكاست' },
                  ]"
                  placeholder=" "
                  @update:model-value="episodeEditForm.content_type = $event"
                />
                <label class="flex items-center gap-2 text-sm text-gray-400 cursor-pointer">
                  <input v-model="episodeEditForm.is_premium" type="checkbox" class="accent-gold" />
                  محتوى مدفوع
                </label>
                <label class="flex items-center gap-2 text-sm text-gray-400 cursor-pointer">
                  <input v-model="episodeEditForm.is_public_to_hub" type="checkbox" class="accent-gold" />
                  منشور في الـ Hub
                </label>
              </div>
              <div v-if="episodeEditForm.content_type === 'video'">
                <input v-model="episodeEditForm.video_id" type="text" dir="ltr" placeholder="معرف الفيديو (YouTube)" class="w-full bg-black/40 border border-white/10 rounded-lg px-3 py-2.5 text-white text-sm placeholder-gray-600 font-mono focus:outline-none focus:border-gold/50" />
              </div>
              <div v-if="episodeEditForm.content_type === 'audio'" class="flex items-center gap-3">
                <svg class="w-5 h-5 text-purple-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                </svg>
                <input v-model="episodeEditForm.audio_url" type="text" dir="ltr" placeholder="رابط البث الخارجي (SoundCloud, Spotify...)" class="flex-1 bg-black/40 border border-white/10 rounded-lg px-3 py-2.5 text-white text-sm placeholder-gray-600 focus:outline-none focus:border-gold/50" />
              </div>
            </div>

            <!-- Episode row -->
            <div
              v-else
              class="flex items-center gap-3 glass rounded-xl px-4 py-3 border border-white/5 hover:border-white/10 transition-all group"
            >
              <!-- Sort order badge -->
              <div class="w-7 h-7 rounded-lg bg-white/5 border border-white/10 flex items-center justify-center shrink-0">
                <span class="text-xs font-bold text-gray-400">{{ i + 1 }}</span>
              </div>

              <!-- Content type icon -->
              <div class="w-9 h-9 rounded-lg flex items-center justify-center shrink-0" :class="ep.content_type === 'audio' ? 'bg-purple-500/10 text-purple-400' : ep.content_type === 'video' || ep.video_id ? 'bg-purple-500/10 text-purple-400' : 'bg-blue-500/10 text-blue-400'">
                <span class="text-sm">{{ ep.content_type === 'audio' ? '🎙️' : ep.content_type === 'video' || ep.video_id ? '🎬' : '📝' }}</span>
              </div>

              <!-- Info -->
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-white truncate">{{ localizedTitle(ep.title) }}</p>
                <p class="text-[11px] text-gray-500 mt-0.5">{{ episodeType(ep) }}</p>
              </div>

              <!-- Reorder arrows -->
              <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                <button
                  class="p-1.5 rounded-lg text-gray-500 hover:text-white hover:bg-white/10 transition-all disabled:opacity-20"
                  :disabled="i === 0"
                  @click="moveUp(ep, i)"
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                  </svg>
                </button>
                <button
                  class="p-1.5 rounded-lg text-gray-500 hover:text-white hover:bg-white/10 transition-all disabled:opacity-20"
                  :disabled="i >= episodes.length - 1"
                  @click="moveDown(ep, i)"
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              </div>

              <!-- Edit -->
              <button
                class="p-1.5 rounded-lg text-gray-500 hover:text-gold hover:bg-gold/10 transition-all opacity-0 group-hover:opacity-100"
                :title="$t('common.edit')"
                @click="openEditEpisode(ep)"
              >
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
              </button>

              <!-- Remove / Delete -->
              <div class="relative">
                <button
                  class="p-1.5 rounded-lg text-gray-500 hover:text-red-400 hover:bg-red-500/10 transition-all opacity-0 group-hover:opacity-100"
                  @click="confirmDeleteId = ep.id"
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>

                <Transition name="fade">
                  <div
                    v-if="confirmDeleteId === ep.id"
                    class="absolute left-0 top-0 z-20 bg-black/95 backdrop-blur-xl rounded-xl p-4 border border-white/10 shadow-2xl w-64"
                  >
                    <p class="text-xs text-gray-300 mb-3 leading-relaxed">
                      هل تريد <span class="text-red-400">حذف</span> المحتوى بالكامل أم <span class="text-amber-400">فصل</span> السلسلة فقط؟
                    </p>
                    <div class="flex items-center gap-2">
                      <button
                        class="flex-1 px-3 py-1.5 rounded-lg text-xs font-bold bg-red-500/20 text-red-400 border border-red-500/30 hover:bg-red-500/30 transition-all"
                        @click="deleteEntity(ep.id)"
                      >
                        حذف كلي
                      </button>
                      <button
                        class="flex-1 px-3 py-1.5 rounded-lg text-xs font-bold bg-amber-500/20 text-amber-400 border border-amber-500/30 hover:bg-amber-500/30 transition-all"
                        @click="removeFromSeries(ep.id)"
                      >
                        فصل فقط
                      </button>
                      <button
                        class="px-3 py-1.5 rounded-lg text-xs font-bold bg-white/10 text-gray-400 border border-white/10 hover:bg-white/20 transition-all"
                        @click="confirmDeleteId = null"
                      >
                        إلغاء
                      </button>
                    </div>
                  </div>
                </Transition>
              </div>
            </div>
          </template>
        </div>
      </div>
    </div>
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
