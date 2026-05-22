<script setup lang="ts">
import type { Database } from '~/types/database'

definePageMeta({
  layout: 'dashboard',
  middleware: 'dashboard-auth',
  title: 'Branches Management',
})

const supabase = useSupabaseClient<Database>()
const { t, locale } = useI18n()
const { profile } = useUser()

type Branch = Database['public']['Tables']['branches']['Row']

const branches = ref<Branch[]>([])
const entityCounts = ref<Record<string, number>>({})
const loading = ref(true)
const showModal = ref(false)
const editingId = ref<string | null>(null)
const submitting = ref(false)
const togglingId = ref<string | null>(null)
const error = ref('')
const success = ref('')

const form = reactive({
  name_ar: '',
  name_en: '',
  slug: '',
  module_type: 'content',
})

const moduleTypes = computed(() => [
  { value: 'content', label: t('dashboard.module_content') },
  { value: 'media', label: t('dashboard.module_media') },
  { value: 'forum', label: t('dashboard.module_forum') },
])

const isEditing = computed(() => editingId.value !== null)
const orgId = computed(() => profile.value?.organization_id)

function generateSlug(val: string): string {
  return val
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/[\s]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '')
}

const manualSlugEdit = ref(false)

function onNameEnInput(val: string) {
  if (!manualSlugEdit.value) {
    form.slug = generateSlug(val)
  }
}

function onSlugInput() {
  manualSlugEdit.value = true
}

async function fetchEntityCounts() {
  for (const branch of branches.value) {
    const { count } = await supabase
      .from('entities')
      .select('id', { count: 'exact', head: true })
      .eq('branch_id', branch.id)

    entityCounts.value[branch.id] = count ?? 0
  }
}

async function fetchBranches() {
  const id = orgId.value
  if (!id) return

  loading.value = true
  const { data } = await supabase
    .from('branches')
    .select('*')
    .eq('organization_id', id)
    .order('created_at', { ascending: false })

  if (data) {
    branches.value = data
    await fetchEntityCounts()
  }
  loading.value = false
}

watch(orgId, (id) => {
  if (id) fetchBranches()
}, { immediate: true })

function openCreateModal() {
  editingId.value = null
  form.name_ar = ''
  form.name_en = ''
  form.slug = ''
  form.module_type = 'content'
  manualSlugEdit.value = false
  error.value = ''
  showModal.value = true
}

function openEditModal(branch: Branch) {
  editingId.value = branch.id
  const name = branch.name as { ar?: string; en?: string }
  form.name_ar = name?.ar || ''
  form.name_en = name?.en || ''
  form.slug = branch.slug
  form.module_type = branch.module_type
  manualSlugEdit.value = true
  error.value = ''
  showModal.value = true
}

async function submitBranch() {
  error.value = ''
  success.value = ''

  if (!form.name_ar || !form.name_en || !form.slug) {
    error.value = t('dashboard.validation.required_fields')
    return
  }

  const id = orgId.value
  if (!id) {
    error.value = t('common.org_not_found')
    return
  }

  submitting.value = true

  const payload = {
    organization_id: id,
    name: { ar: form.name_ar, en: form.name_en },
    slug: form.slug,
    module_type: form.module_type as 'content' | 'forum' | 'media',
  }

  if (isEditing.value) {
    const editId = editingId.value
    if (!editId) {
      submitting.value = false
      return
    }

    const { error: updateError } = await supabase
      .from('branches')
      .update({
        name: payload.name,
        slug: payload.slug,
        module_type: payload.module_type,
      })
      .eq('id', editId)

    submitting.value = false

    if (updateError) {
      error.value = t('dashboard.update_error')
      return
    }

    showModal.value = false
    success.value = t('dashboard.branch_updated')
  } else {
    const { error: insertError } = await supabase
      .from('branches')
      .insert(payload)

    submitting.value = false

    if (insertError) {
      error.value = t('dashboard.create_error')
      return
    }

    showModal.value = false
    success.value = t('dashboard.branch_created')
  }

  await fetchBranches()
}

async function toggleStatus(branch: Branch) {
  togglingId.value = branch.id
  const newStatus = !branch.is_active

  const original = branches.value.map(b => ({ ...b }))
  const idx = branches.value.findIndex(b => b.id === branch.id)
  if (idx !== -1) {
    branches.value[idx] = { ...branches.value[idx], is_active: newStatus }
  }

  const { error: toggleError } = await supabase
    .from('branches')
    .update({ is_active: newStatus })
    .eq('id', branch.id)

  if (toggleError) {
    branches.value = original
  }

  togglingId.value = null
}

async function deleteBranch(id: string) {
  const confirmed = window.confirm(t('dashboard.confirm_delete_desc'))
  if (!confirmed) return

  await supabase.from('branches').delete().eq('id', id)
  await fetchBranches()
}
</script>

<template>
  <div>
    <div v-if="success" class="mb-6 text-green-400 text-sm text-center bg-green-500/10 border border-green-500/20 rounded-xl px-4 py-3">
      {{ success }}
    </div>

    <div class="flex items-center justify-between mb-8">
      <h1 class="text-xl font-bold text-white">{{ $t('dashboard.branches_title') }}</h1>
      <Button @click="openCreateModal">
        + {{ $t('dashboard.add_branch') }}
      </Button>
    </div>

    <div v-if="loading" class="space-y-4">
      <div v-for="i in 3" :key="i" class="glass rounded-2xl p-5 animate-pulse">
        <div class="h-5 bg-white/5 rounded w-1/3 mb-3" />
        <div class="h-4 bg-white/5 rounded w-1/4 mb-2" />
        <div class="h-4 bg-white/5 rounded w-1/6" />
      </div>
    </div>

    <div v-else-if="branches.length === 0" class="glass rounded-2xl p-12 text-center">
      <div class="w-16 h-16 mx-auto mb-4 rounded-2xl bg-white/5 flex items-center justify-center">
        <svg class="w-8 h-8 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
        </svg>
      </div>
      <p class="text-gray-500 text-sm">{{ $t('dashboard.no_branches') }}</p>
    </div>

    <div v-else class="grid gap-4">
      <div
        v-for="branch in branches"
        :key="branch.id"
        class="glass rounded-2xl p-5 border border-white/5 hover:border-gold/20 transition-all duration-300"
      >
        <div class="flex items-center justify-between gap-4">
          <div class="flex items-center gap-4 min-w-0">
            <div class="w-10 h-10 rounded-xl bg-gold/10 flex items-center justify-center shrink-0">
              <svg class="w-5 h-5 text-gold" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
              </svg>
            </div>
            <div class="min-w-0">
              <p class="text-sm font-medium text-white truncate">{{ localizedValue(branch.name, locale) }}</p>
              <p class="text-xs text-gray-500 mt-0.5 font-mono">/{{ branch.slug }}</p>
            </div>
          </div>

          <div class="flex items-center gap-3 shrink-0">
            <span
              class="hidden sm:inline-block px-2.5 py-0.5 text-xs font-medium rounded-full"
              :class="branch.module_type === 'content' ? 'bg-gold/15 text-gold border border-gold/20' : branch.module_type === 'media' ? 'bg-blue-500/10 text-blue-400 border border-blue-500/20' : 'bg-purple-500/10 text-purple-400 border border-purple-500/20'"
            >
              {{ $t(`dashboard.module_${branch.module_type}`) }}
            </span>

            <div class="hidden sm:flex items-center gap-1.5 text-xs text-gray-500">
              <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
              </svg>
              <span>{{ entityCounts[branch.id] ?? '-' }}</span>
            </div>

            <button
              class="relative inline-flex h-5 w-9 items-center rounded-full transition-colors duration-200 focus:outline-none"
              :class="branch.is_active ? 'bg-green-500' : 'bg-white/10'"
              :disabled="togglingId === branch.id"
              @click="toggleStatus(branch)"
            >
              <span
                class="inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform duration-200"
                :class="branch.is_active ? 'translate-x-[18px]' : 'translate-x-[3px]'"
              />
            </button>

            <button
              class="p-2 text-gray-500 hover:text-gold rounded-lg hover:bg-white/5 transition-all duration-200"
              :title="$t('common.edit')"
              @click="openEditModal(branch)"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
              </svg>
            </button>
            <button
              class="p-2 text-gray-500 hover:text-red-400 rounded-lg hover:bg-red-500/10 transition-all duration-200"
              :title="$t('common.delete')"
              @click="deleteBranch(branch.id)"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>

    <Transition name="fade">
      <div
        v-if="showModal"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
      >
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="showModal = false" />
        <div class="relative w-full max-w-lg glass rounded-2xl p-6 lg:p-8 border border-white/5">
          <h2 class="text-lg font-bold text-white mb-6">
            {{ isEditing ? $t('dashboard.edit_branch_title') : $t('dashboard.create_branch_title') }}
          </h2>

          <form novalidate @submit.prevent="submitBranch">
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-400 mb-1.5">
                  {{ $t('dashboard.branch_name_ar') }}
                </label>
                <input
                  v-model="form.name_ar"
                  type="text"
                  class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                  :disabled="submitting"
                  required
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-400 mb-1.5">
                  {{ $t('dashboard.branch_name_en') }}
                </label>
                <input
                  v-model="form.name_en"
                  type="text"
                  dir="ltr"
                  class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                  :disabled="submitting"
                  @input="onNameEnInput(($event.target as HTMLInputElement).value)"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-400 mb-1.5">
                  {{ $t('dashboard.branch_slug') }}
                </label>
                <input
                  :value="form.slug"
                  type="text"
                  dir="ltr"
                  class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white placeholder-gray-600 font-mono text-sm focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                  :disabled="submitting"
                  @input="onSlugInput(); form.slug = generateSlug(($event.target as HTMLInputElement).value)"
                  @focus="manualSlugEdit = true"
                />
                <p v-if="!manualSlugEdit && isEditing" class="text-xs text-gray-600 mt-1">
                  {{ $t('dashboard.slug_auto_generate') }}
                </p>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-400 mb-1.5">
                  {{ $t('dashboard.module_type_selector') }}
                </label>
                <select
                  v-model="form.module_type"
                  class="w-full px-4 py-2.5 bg-white/5 border border-white/10 rounded-xl text-white focus:outline-none focus:border-gold/50 focus:ring-1 focus:ring-gold/30 transition-all duration-200"
                  :disabled="submitting"
                >
                  <option v-for="mt in moduleTypes" :key="mt.value" :value="mt.value">
                    {{ mt.label }}
                  </option>
                </select>
              </div>

              <div v-if="error" class="text-red-400 text-sm text-center bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-2.5">
                {{ error }}
              </div>

              <div class="flex gap-3 pt-2">
                <Button variant="outline" :disabled="submitting" @click="showModal = false">
                  {{ $t('common.cancel') }}
                </Button>
                <Button type="submit" block :loading="submitting">
                  {{ isEditing ? $t('common.save') : $t('dashboard.add_branch') }}
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
</style>
