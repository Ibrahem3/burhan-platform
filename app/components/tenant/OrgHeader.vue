<script setup lang="ts">
import type { Database } from '~/types/database'

type Organization = Database['public']['Tables']['organizations']['Row'] & {
  branches: Database['public']['Tables']['branches']['Row'][]
}

const props = defineProps<{
  org: Organization
}>()

const { locale } = useI18n()

function localize(value: unknown): string {
  if (!value) return ''
  const obj = typeof value === 'string' ? JSON.parse(value as string) : value
  return obj?.[locale.value as 'ar' | 'en'] || obj?.ar || ''
}

const displayName = computed(() => localize(props.org.name))

const logoUrl = computed(() => {
  const settings = props.org.settings as Record<string, any> | null
  return settings?.logos?.dark || settings?.logos?.light || null
})
</script>

<template>
  <header class="relative overflow-hidden rounded-3xl glass mb-8">
    <div class="absolute inset-0 bg-gradient-to-br from-gold/5 to-transparent pointer-events-none" />

    <div class="relative z-10 p-8 md:p-12 flex flex-col md:flex-row items-center md:items-start gap-6">
      <div
        v-if="logoUrl"
        class="w-20 h-20 md:w-24 md:h-24 rounded-2xl overflow-hidden shrink-0 bg-white/5 p-2"
      >
        <img
          :src="logoUrl"
          :alt="displayName"
          class="w-full h-full object-contain"
        />
      </div>
      <div
        v-else
        class="w-20 h-20 md:w-24 md:h-24 rounded-2xl shrink-0 bg-gold/20 flex items-center justify-center"
      >
        <span class="text-3xl font-bold text-gold">{{ displayName.charAt(0) }}</span>
      </div>

      <div class="text-center md:text-right">
        <h1 class="text-3xl md:text-4xl font-bold text-white mb-2">
          {{ displayName }}
        </h1>

        <div class="flex flex-wrap items-center justify-center md:justify-start gap-2 mt-4">
          <Badge
            v-for="branch in org.branches"
            :key="branch.id"
            :variant="branch.module_type === 'media' ? 'info' : branch.module_type === 'forum' ? 'warning' : 'default'"
            size="md"
          >
            <template v-if="branch.name">
              {{ localize(branch.name) }}
            </template>
          </Badge>
        </div>
      </div>
    </div>
  </header>
</template>
