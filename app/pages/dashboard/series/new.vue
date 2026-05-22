<script setup lang="ts">
import type { Database, Json } from '~/types/database'
import { compressImage } from '~/utils/compressImage'

definePageMeta({
  layout: 'dashboard',
  middleware: 'dashboard-auth',
  title: 'New Series',
})

const supabase = useSupabaseClient<Database>()
const { t, locale } = useI18n()
const localePath = useLocalePath()
const { profile } = useUser()
const { uploadFile, uploading: isUploading } = useSupabaseStorage()

type Branch = Database['public']['Tables']['branches']['Row']

const orgId = computed(() => profile.value?.organization_id)
const branches = ref<Branch[]>([])
const saving = ref(false)
const error = ref('')
const coverUrl = ref('')
const fileInput = ref<HTMLInputElement | null>(null)

const form = reactive({
  title_ar: '',
  title_en: '',
  description_ar: '',
  description_en: '',
  branch_id: '',
})

async function fetchBranches() {
  const id = orgId.value
  if (!id) return
  const { data } = await supabase
    .from('branches')
    .select('*')
    .eq('organization_id', id)
    .eq('is_active', true)
    .order('created_at', { ascending: false })
  if (data) {
    branches.value = data
    if (!form.branch_id && data.length > 0) {
      form.branch_id = data[0].id
    }
  }
}

watch(orgId, (id) => {
  if (id) fetchBranches()
}, { immediate: true })

async function handleCoverImage(file: File) {
  const id = orgId.value
  if (!id) return
  const compressed = await compressImage(file)
  if (!compressed) return
  const url = await uploadFile(compressed, id)
  if (url) coverUrl.value = url
}

function triggerImageUpload() {
  fileInput.value?.click()
}

async function onFileSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (file) await handleCoverImage(file)
  input.value = ''
}

async function save() {
  error.value = ''
  if (!form.title_ar || !form.title_en || !form.branch_id) {
    error.value = 'العنوان (بالعربية والإنجليزية) والفرع مطلوب'
    return
  }
  const id = orgId.value
  if (!id) {
    error.value = t('common.org_not_found')
    return
  }
  saving.value = true
  const { error: insertError } = await supabase
    .from('series')
    .insert({
      organization_id: id,
      branch_id: form.branch_id,
      title: { ar: form.title_ar, en: form.title_en } as Json,
      description: { ar: form.description_ar, en: form.description_en } as Json,
      cover_url: coverUrl.value || null,
      is_active: true,
    } as any)
  saving.value = false
  if (insertError) {
    error.value = insertError.message
    return
  }
  await navigateTo(localePath('/dashboard/series'))
}
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-8">
      <div>
        <NuxtLink
          :to="localePath('/dashboard/series')"
          class="text-sm text-gray-500 hover:text-gold transition-colors mb-1 inline-block"
        >
          ← العودة إلى السلاسل
        </NuxtLink>
        <h1 class="text-xl font-bold text-white">إنشاء سلسلة تعليمية جديدة</h1>
      </div>
      <div class="flex gap-2">
        <Button variant="outline" @click="navigateTo(localePath('/dashboard/series'))">
          إلغاء
        </Button>
        <Button :loading="saving" @click="save">
          حفظ السلسلة
        </Button>
      </div>
    </div>

    <div v-if="error" class="mb-6 text-red-400 text-sm text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3">
      {{ error }}
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8 items-start">
      <!-- Main content -->
      <div class="lg:col-span-2 space-y-8">
        <!-- Cover Image -->
        <div class="relative group cursor-pointer" @click="triggerImageUpload">
          <div
            class="aspect-video w-full rounded-2xl overflow-hidden relative border border-white/5 transition-all group-hover:border-white/20"
            :class="!coverUrl ? 'bg-white/5 flex flex-col items-center justify-center border-dashed border-2 border-white/10' : ''"
          >
            <img
              v-if="coverUrl"
              :src="coverUrl"
              class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
            />
            <div class="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center backdrop-blur-sm">
              <div class="bg-white/10 px-6 py-3 rounded-full backdrop-blur-md border border-white/20 flex items-center gap-2 text-sm font-bold">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                {{ coverUrl ? 'تغيير الصورة' : 'إضافة صورة الغلاف' }}
              </div>
            </div>
            <div v-if="!coverUrl" class="text-gray-500 flex flex-col items-center gap-3">
              <svg class="w-10 h-10 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              <span class="font-bold text-gray-600">إضافة صورة الغلاف</span>
            </div>
          </div>
          <div v-if="isUploading" class="absolute inset-0 bg-black/60 z-10 flex items-center justify-center rounded-2xl backdrop-blur-sm">
            <span class="text-gold font-bold animate-pulse">جاري رفع الصورة...</span>
          </div>
          <input ref="fileInput" type="file" accept="image/*" class="hidden" @change="onFileSelected" />
        </div>

        <!-- Title (bilingual) -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="space-y-2">
            <label class="block text-sm font-medium text-gray-400">العنوان بالعربية</label>
            <input
              v-model="form.title_ar"
              type="text"
              placeholder="عنوان السلسلة بالعربية"
              class="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3.5 text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 transition-all text-lg"
            />
          </div>
          <div class="space-y-2">
            <label class="block text-sm font-medium text-gray-400">Title (English)</label>
            <input
              v-model="form.title_en"
              type="text"
              dir="ltr"
              placeholder="Series title in English"
              class="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3.5 text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 transition-all text-lg"
            />
          </div>
        </div>

        <!-- Description (bilingual) -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="space-y-2">
            <label class="block text-sm font-medium text-gray-400">الوصف بالعربية</label>
            <textarea
              v-model="form.description_ar"
              rows="4"
              placeholder="وصف السلسلة بالعربية"
              class="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3.5 text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 transition-all resize-none"
            />
          </div>
          <div class="space-y-2">
            <label class="block text-sm font-medium text-gray-400">Description (English)</label>
            <textarea
              v-model="form.description_en"
              dir="ltr"
              rows="4"
              placeholder="Series description in English"
              class="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3.5 text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 transition-all resize-none"
            />
          </div>
        </div>
      </div>

      <!-- Sidebar -->
      <div class="lg:col-span-1 space-y-6 sticky top-8">
        <!-- Branch -->
        <div class="glass rounded-2xl p-6 border border-white/5 space-y-3">
          <h3 class="text-gray-500 font-bold text-xs uppercase tracking-wider">الفرع التابع له</h3>
          <select
            v-model="form.branch_id"
            class="w-full bg-black/40 border border-white/10 rounded-xl p-3 text-white focus:border-gold/50 outline-none appearance-none cursor-pointer"
          >
            <option v-for="b in branches" :key="b.id" :value="b.id">
              {{ localizedValue(b.name, locale) }}
            </option>
          </select>
        </div>

        <!-- Summary -->
        <div class="glass rounded-2xl p-6 border border-white/5 space-y-3">
          <h3 class="text-gray-500 font-bold text-xs uppercase tracking-wider">ملخص</h3>
          <div class="space-y-2 text-sm">
            <div class="flex justify-between">
              <span class="text-gray-500">الحالة</span>
              <span class="text-green-400">نشط</span>
            </div>
            <div class="flex justify-between">
              <span class="text-gray-500">صورة الغلاف</span>
              <span class="text-white" :class="coverUrl ? 'text-green-400' : 'text-gray-500'">{{ coverUrl ? 'تم الرفع' : 'غير مرفوعة' }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
