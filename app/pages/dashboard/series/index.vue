<script setup lang="ts">
import type { Database, Json } from '~/types/database'

definePageMeta({
  layout: 'dashboard',
  middleware: 'dashboard-auth',
  title: 'Series & Courses',
})

const supabase = useSupabaseClient<Database>()
const { t, locale } = useI18n()
const localePath = useLocalePath()
const { profile } = useUser()

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

interface Branch {
  id: string
  name: Json
}

const seriesList = ref<Series[]>([])
const branches = ref<Branch[]>([])
const loading = ref(true)
const togglingId = ref<string | null>(null)

const orgId = computed(() => profile.value?.organization_id)

async function fetchData() {
  const id = orgId.value
  if (!id) return
  loading.value = true
  const { data: sData } = await supabase
    .from('series')
    .select('*')
    .eq('organization_id', id)
    .order('created_at', { ascending: false })
  if (sData) seriesList.value = sData as unknown as Series[]
  const { data: bData } = await supabase
    .from('branches')
    .select('id, name')
    .eq('organization_id', id)
  if (bData) branches.value = bData
  loading.value = false
}

watch(orgId, fetchData, { immediate: true })

function branchName(branchId: string): string {
  const b = branches.value.find(b => b.id === branchId)
  if (!b) return ''
  const name = b.name as Record<string, string>
  return name[locale.value] || name.ar || name.en || ''
}

function seriesTitle(s: Series): string {
  const t = s.title as Record<string, string>
  return t[locale.value] || t.ar || t.en || ''
}

async function toggleActive(s: Series) {
  togglingId.value = s.id
  const { error } = await supabase
    .from('series')
    .update({ is_active: !s.is_active })
    .eq('id', s.id)
  if (!error) {
    s.is_active = !s.is_active
  }
  togglingId.value = null
}
</script>

<template>
  <div>
    <div class="flex items-center justify-between mb-8">
      <div>
        <NuxtLink
          :to="localePath('/dashboard/entities')"
          class="text-sm text-gray-500 hover:text-gold transition-colors mb-1 inline-block"
        >
          ← {{ $t('dashboard.entities') }}
        </NuxtLink>
        <h1 class="text-xl font-bold text-white">إدارة السلاسل التعليمية والكورسات</h1>
        <p class="text-sm text-gray-500 mt-1">{{ seriesList.length }} سلسلة تعليمية</p>
      </div>
      <Button @click="navigateTo(localePath('/dashboard/series/new'))">
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
        </svg>
        + إنشاء سلسلة جديدة
      </Button>
    </div>

    <div v-if="loading" class="flex items-center justify-center py-20">
      <span class="text-gold animate-pulse font-bold">جاري التحميل...</span>
    </div>

    <div v-else-if="seriesList.length === 0" class="flex flex-col items-center justify-center py-20">
      <div class="w-20 h-20 rounded-full bg-white/5 border border-white/10 flex items-center justify-center mb-4">
        <svg class="w-10 h-10 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
        </svg>
      </div>
      <p class="text-gray-500 font-bold mb-1">لا توجد سلاسل تعليمية بعد</p>
      <p class="text-gray-600 text-sm mb-4">قم بإنشاء أول سلسلة تعليمية أو كورس</p>
      <Button @click="navigateTo(localePath('/dashboard/series/new'))">
        + إنشاء سلسلة جديدة
      </Button>
    </div>

    <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
      <div
        v-for="s in seriesList"
        :key="s.id"
        class="group glass rounded-2xl overflow-hidden border border-white/5 hover:border-white/20 transition-all duration-500 hover:shadow-2xl hover:shadow-gold/5"
      >
        <!-- 16:9 Cover -->
        <div class="relative aspect-video overflow-hidden bg-white/5">
          <img
            v-if="s.cover_url"
            :src="s.cover_url"
            :alt="seriesTitle(s)"
            class="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
          />
          <div v-else class="w-full h-full flex items-center justify-center">
            <svg class="w-12 h-12 text-gray-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
            </svg>
          </div>
          <!-- Branch badge overlay -->
          <div class="absolute top-3 right-3">
            <span class="px-2.5 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wider bg-black/60 backdrop-blur-md border border-white/10 text-white shadow-lg">
              {{ branchName(s.branch_id) }}
            </span>
          </div>
        </div>

        <!-- Body -->
        <div class="p-5 space-y-3">
          <h3 class="font-bold text-white text-sm leading-snug line-clamp-2 min-h-[2.5rem]">
            {{ seriesTitle(s) }}
          </h3>
          <p v-if="s.description" class="text-xs text-gray-500 line-clamp-2 leading-relaxed">
            {{ (s.description as Record<string, string>)[locale] || (s.description as Record<string, string>).ar || (s.description as Record<string, string>).en }}
          </p>
          <div class="flex items-center justify-between pt-1">
            <Button size="sm" variant="outline" @click.stop="navigateTo(localePath(`/dashboard/series/${s.id}`))">
              إدارة المحتوى
            </Button>
            <div class="flex items-center gap-2">
              <span class="text-[11px] text-gray-500">{{ s.is_active ? 'منشور' : 'غير منشور' }}</span>
              <button
                class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors"
                :class="s.is_active ? 'bg-gold' : 'bg-white/10'"
                :disabled="togglingId === s.id"
                @click.stop="toggleActive(s)"
              >
                <span
                  class="inline-block h-4 w-4 transform rounded-full bg-white transition-transform"
                  :class="s.is_active ? 'translate-x-6' : 'translate-x-1'"
                />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>
