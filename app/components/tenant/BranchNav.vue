<script setup lang="ts">
import type { Database } from '~/types/database'

type Branch = Database['public']['Tables']['branches']['Row']

const props = defineProps<{
  branches: Branch[]
  activeBranchId?: string
}>()

const emit = defineEmits<{
  select: [branchId: string | undefined]
}>()

const { locale } = useI18n()
const currentLocale = computed(() => locale.value as 'ar' | 'en')

const localizedName = (branch: Branch) => {
  const name = branch.name as Record<string, string>
  return name[currentLocale.value] || name.en || ''
}

const moduleIcons: Record<string, string> = {
  content: '📄',
  forum: '💬',
  media: '🎬',
}

const isActive = (branchId: string) => props.activeBranchId === branchId
</script>

<template>
  <nav class="flex flex-wrap gap-2 mb-8">
    <button
      :class="[
        'px-4 py-2 rounded-xl text-sm font-medium transition-all duration-200',
        !activeBranchId
          ? 'bg-gold text-onyx shadow-lg shadow-gold/20'
          : 'glass text-gray-300 hover:text-white hover:bg-white/10',
      ]"
      @click="emit('select', undefined)"
    >
      {{ $t('tenant.overview') }}
    </button>

    <button
      v-for="branch in branches"
      :key="branch.id"
      :class="[
        'px-4 py-2 rounded-xl text-sm font-medium transition-all duration-200',
        isActive(branch.id)
          ? 'bg-gold text-onyx shadow-lg shadow-gold/20'
          : 'glass text-gray-300 hover:text-white hover:bg-white/10',
      ]"
      @click="emit('select', branch.id)"
    >
      {{ localizedName(branch) }}
    </button>
  </nav>
</template>
