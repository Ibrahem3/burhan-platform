<script setup lang="ts">
import type { Database } from '~/types/database'

type Entity = Database['public']['Tables']['entities']['Row'] & {
  organizations?: Pick<Database['public']['Tables']['organizations']['Row'], 'name' | 'org_slug'>
  branches?: Pick<Database['public']['Tables']['branches']['Row'], 'name' | 'module_type'>
}

const props = defineProps<{
  entity: Entity
}>()

const { extractLocalized } = useLocale()
const { locale } = useI18n()
const currentLocale = computed(() => locale.value as 'ar' | 'en')

const localizedTitle = computed(() => {
  return extractLocalized<string>(props.entity.title as any, '') ?? ''
})

const localizedContent = computed(() => {
  const text = extractLocalized<string>(props.entity.content as any, '') ?? ''
  return text.length > 120 ? text.slice(0, 120) + '...' : text
})

const orgName = computed(() => {
  const name = props.entity.organizations?.name
  if (!name) return ''
  const obj = typeof name === 'string' ? JSON.parse(name as string) : name
  return obj[currentLocale.value] || obj.en || obj.ar || ''
})

const orgSlug = computed(() => props.entity.organizations?.org_slug ?? '')
</script>

<template>
  <GlassCard :hover="true" class="group">
    <div class="flex flex-col gap-3">
      <div class="flex items-center justify-between">
        <Badge
          :variant="entity.is_premium ? 'premium' : 'default'"
          size="sm"
        >
          {{ entity.is_premium ? $t('entities.premium') : $t('entities.video') }}
        </Badge>
        <span class="text-xs text-gray-500">
          {{ new Date(entity.created_at).toLocaleDateString(currentLocale === 'ar' ? 'ar-SA' : 'en-US') }}
        </span>
      </div>

      <h3 class="text-lg font-semibold text-white group-hover:text-gold transition-colors line-clamp-2">
        {{ localizedTitle }}
      </h3>

      <p class="text-sm text-gray-400 leading-relaxed line-clamp-3">
        {{ localizedContent }}
      </p>

      <div v-if="orgName" class="flex items-center justify-between pt-2 border-t border-white/5">
        <NuxtLink
          :to="`/${orgSlug}`"
          class="text-xs text-gray-500 hover:text-gold transition-colors"
        >
          {{ $t('entities.by_organization', { name: orgName }) }}
        </NuxtLink>
        <span
          v-if="entity.video_id"
          class="text-xs text-gold"
        >
          {{ $t('entities.video') }}
        </span>
      </div>
    </div>
  </GlassCard>
</template>
