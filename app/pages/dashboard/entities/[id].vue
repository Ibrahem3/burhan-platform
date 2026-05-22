<script setup lang="ts">
import type { Database } from '~/types/database'
import { compressImage } from '~/utils/compressImage'

definePageMeta({
  layout: 'dashboard',
  middleware: 'dashboard-auth',
  title: 'Edit Article',
})

const supabase = useSupabaseClient<Database>()
const { t, locale } = useI18n()
const localePath = useLocalePath()
const { profile } = useUser()
const { uploadFile, uploading: isUploading } = useSupabaseStorage()
const route = useRoute()

type Branch = Database['public']['Tables']['branches']['Row']

const entityId = route.params.id as string
const orgId = computed(() => profile.value?.organization_id)
const branches = ref<Branch[]>([])
const coverUrl = ref('')
const saving = ref(false)
const loading = ref(true)
const notFound = ref(false)
const error = ref('')

const form = reactive({
  title_ar: '',
  title_en: '',
  slug: '',
  content_ar: '',
  content_en: '',
  branch_id: '',
  is_premium: false,
  is_public_to_hub: false,
  price: '',
})

const currentLang = ref<'ar' | 'en'>('ar')

async function fetchEntity() {
  const id = orgId.value
  if (!id) return

  const { data: branchesData } = await supabase
    .from('branches')
    .select('*')
    .eq('organization_id', id)
    .eq('is_active', true)
    .order('created_at', { ascending: false })

  if (branchesData) branches.value = branchesData

  const { data: entity, error: entityError } = await supabase
    .from('entities')
    .select('*')
    .eq('id', entityId)
    .eq('organization_id', id)
    .single()

  if (entityError || !entity) {
    notFound.value = true
    loading.value = false
    return
  }

  const title = entity.title as { ar?: string; en?: string }
  const content = entity.content as { ar?: string; en?: string; image_url?: string }

  form.title_ar = title?.ar || ''
  form.title_en = title?.en || ''
  form.content_ar = content?.ar || ''
  form.content_en = content?.en || ''
  coverUrl.value = (content as any)?.image_url || ''
  form.branch_id = entity.branch_id
  form.is_premium = entity.is_premium
  form.is_public_to_hub = entity.is_public_to_hub
  form.price = entity.price ? String(entity.price) : ''

  loading.value = false
}

watch(orgId, (id) => {
  if (id) fetchEntity()
}, { immediate: true })

function generateSlug(val: string): string {
  return val
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/[\s]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
}

const manualSlug = ref(false)

function onTitleEnInput(val: string) {
  if (!manualSlug.value) {
    form.slug = generateSlug(val)
  }
}

async function handleCoverImage(file: File) {
  const id = orgId.value
  if (!id) return
  const compressed = await compressImage(file)
  if (!compressed) return
  const url = await uploadFile(compressed, id)
  if (url) coverUrl.value = url
}

async function save() {
  error.value = ''
  if (!form.title_ar || !form.title_en || !form.branch_id) {
    error.value = t('dashboard.validation.title_branch_required')
    return
  }

  const id = orgId.value
  if (!id) {
    error.value = t('common.org_not_found')
    return
  }

  saving.value = true

  const { error: updateError } = await supabase
    .from('entities')
    .update({
      branch_id: form.branch_id,
      title: { ar: form.title_ar, en: form.title_en } as Json,
      content: { ar: form.content_ar, en: form.content_en, image_url: coverUrl.value } as Json,
      is_public_to_hub: form.is_public_to_hub,
      is_premium: form.is_premium,
      price: form.is_premium && form.price ? parseFloat(form.price) : null,
    })
    .eq('id', entityId)

  saving.value = false

  if (updateError) {
    error.value = t('dashboard.entity_update_error')
    return
  }

  await navigateTo(localePath('/dashboard/entities'))
}

function setLang(lang: 'ar' | 'en') {
  currentLang.value = lang
}

const fileInput = ref<HTMLInputElement | null>(null)

function triggerImageUpload() {
  fileInput.value?.click()
}

async function onFileSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (file) await handleCoverImage(file)
  input.value = ''
}
</script>

<template>
  <div>
    <div v-if="loading" class="space-y-6 animate-pulse">
      <div class="h-6 bg-white/5 rounded w-1/3" />
      <div class="aspect-video bg-white/5 rounded-2xl" />
      <div class="h-12 bg-white/5 rounded w-3/4" />
      <div class="h-[400px] bg-white/5 rounded-2xl" />
    </div>

    <div v-else-if="notFound" class="glass rounded-2xl p-12 text-center">
      <p class="text-gray-500">{{ $t('common.not_found') }}</p>
      <NuxtLink :to="localePath('/dashboard/entities')" class="text-gold hover:underline mt-4 inline-block">
        ← {{ $t('dashboard.entities') }}
      </NuxtLink>
    </div>

    <div v-else>
      <div class="flex items-center justify-between mb-8">
        <div>
          <NuxtLink
            :to="localePath('/dashboard/entities')"
            class="text-sm text-gray-500 hover:text-gold transition-colors mb-1 inline-block"
          >
            ← {{ $t('dashboard.entities') }}
          </NuxtLink>
          <h1 class="text-xl font-bold text-white">{{ $t('dashboard.edit_entity_title') }}</h1>
        </div>
        <div class="flex gap-2">
          <Button variant="outline" @click="navigateTo(localePath('/dashboard/entities'))">
            {{ $t('common.cancel') }}
          </Button>
          <Button :loading="saving" @click="save">
            {{ $t('common.save') }}
          </Button>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8 items-start">
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
                  {{ coverUrl ? $t('dashboard.editor.cover_image.change') : $t('dashboard.editor.cover_image.add') }}
                </div>
              </div>
              <div v-if="!coverUrl" class="text-gray-500 flex flex-col items-center gap-3">
                <svg class="w-10 h-10 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <span class="font-bold text-gray-600">{{ $t('dashboard.editor.cover_image.add') }}</span>
              </div>
            </div>
            <div v-if="isUploading" class="absolute inset-0 bg-black/60 z-10 flex items-center justify-center rounded-2xl backdrop-blur-sm">
              <span class="text-gold font-bold animate-pulse">{{ $t('dashboard.editor.cover_image.uploading') }}</span>
            </div>
            <input ref="fileInput" type="file" accept="image/*" class="hidden" @change="onFileSelected" />
          </div>

          <!-- Language Tabs -->
          <div class="flex items-center gap-2 bg-white/5 w-fit p-1 rounded-xl border border-white/10">
            <button
              v-for="lang in ['ar', 'en']"
              :key="lang"
              class="px-6 py-2 rounded-lg text-xs font-bold uppercase tracking-widest transition-all flex items-center gap-2"
              :class="currentLang === lang ? (lang === 'ar' ? 'bg-white text-black' : 'bg-gold text-black') : 'text-gray-500 hover:text-white'"
              @click="setLang(lang as 'ar' | 'en')"
            >
              {{ lang === 'ar' ? $t('locale.switch_to_ar') : $t('locale.switch_to_en') }}
            </button>
          </div>

          <!-- Title -->
          <input
            v-if="currentLang === 'ar'"
            v-model="form.title_ar"
            type="text"
            class="w-full bg-transparent border-none outline-none text-4xl md:text-5xl font-bold placeholder-gray-600 focus:placeholder-gray-500 transition-colors leading-tight"
            placeholder="عنوان المقال..."
          />
          <input
            v-else
            v-model="form.title_en"
            type="text"
            dir="ltr"
            class="w-full bg-transparent border-none outline-none text-4xl md:text-5xl font-bold placeholder-gray-600 focus:placeholder-gray-500 transition-colors leading-tight"
            placeholder="Article Title..."
            @input="onTitleEnInput(($event.target as HTMLInputElement).value)"
          />

          <!-- Content Editor -->
          <div v-if="currentLang === 'ar'">
            <RichTextEditor
              v-model="form.content_ar"
              :placeholder="$t('dashboard.editor.placeholder')"
              @image-upload="handleCoverImage"
            />
          </div>
          <div v-else>
            <RichTextEditor
              v-model="form.content_en"
              :placeholder="$t('dashboard.editor.placeholder')"
              @image-upload="handleCoverImage"
            />
          </div>
        </div>

        <!-- Sidebar -->
        <div class="lg:col-span-1 space-y-6 sticky top-8">
          <div class="glass rounded-2xl p-6 border border-white/5">
            <h3 class="text-gray-500 font-bold text-xs uppercase tracking-wider mb-4">{{ $t('dashboard.editor.status_card.title') }}</h3>
            <label class="flex items-center justify-between cursor-pointer group">
              <span class="font-medium text-gray-300 group-hover:text-white transition">{{ $t('dashboard.editor.status_card.publish_label') }}</span>
              <div class="relative">
                <input v-model="form.is_public_to_hub" type="checkbox" class="sr-only peer" />
                <div class="w-12 h-7 bg-white/10 rounded-full peer-checked:bg-gold after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-gray-400 after:rounded-full after:h-6 after:w-6 after:transition-all peer-checked:after:translate-x-full peer-checked:after:bg-white" />
              </div>
            </label>
          </div>

          <div class="glass rounded-2xl p-6 border border-white/5 space-y-3">
            <h3 class="text-gray-500 font-bold text-xs uppercase tracking-wider">{{ $t('dashboard.target_branch') }}</h3>
            <select
              v-model="form.branch_id"
              class="w-full bg-black/40 border border-white/10 rounded-xl p-3 text-white focus:border-gold/50 outline-none appearance-none cursor-pointer"
            >
              <option v-for="b in branches" :key="b.id" :value="b.id">
                {{ localizedValue(b.name, locale) }}
              </option>
            </select>
          </div>

          <div class="glass rounded-2xl p-6 border border-white/5 space-y-4">
            <label class="flex items-center justify-between cursor-pointer group">
              <span class="font-medium text-gray-300 group-hover:text-white transition text-sm">{{ $t('dashboard.premium_toggle') }}</span>
              <div class="relative">
                <input v-model="form.is_premium" type="checkbox" class="sr-only peer" />
                <div class="w-12 h-7 bg-white/10 rounded-full peer-checked:bg-gold after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-gray-400 after:rounded-full after:h-6 after:w-6 after:transition-all peer-checked:after:translate-x-full peer-checked:after:bg-white" />
              </div>
            </label>
            <div v-if="form.is_premium">
              <label class="block text-xs text-gray-500 mb-1">{{ $t('dashboard.premium_revenue') }}</label>
              <input
                v-model="form.price"
                type="number"
                step="0.01"
                min="0"
                dir="ltr"
                placeholder="0.00"
                class="w-full bg-black/40 border border-white/10 rounded-xl p-3 text-white focus:border-gold/50 outline-none"
              />
            </div>
          </div>

          <div v-if="error" class="text-red-400 text-sm text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3">
            {{ error }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
