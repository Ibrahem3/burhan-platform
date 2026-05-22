<script setup lang="ts">
interface Props {
  src?: string | null
  alt?: string
  size?: 'sm' | 'md' | 'lg' | 'xl'
  fallback?: string
}

const props = withDefaults(defineProps<Props>(), {
  src: null,
  alt: 'Avatar',
  size: 'md',
  fallback: '',
})

const sizeClasses: Record<string, string> = {
  sm: 'w-8 h-8 text-xs',
  md: 'w-10 h-10 text-sm',
  lg: 'w-12 h-12 text-base',
  xl: 'w-16 h-16 text-lg',
}

const initials = computed(() => {
  if (props.fallback) {
    return props.fallback.slice(0, 2).toUpperCase()
  }
  return '?'
})
</script>

<template>
  <div
    :class="[
      'relative inline-flex items-center justify-center rounded-full overflow-hidden shrink-0',
      sizeClasses[size],
      src ? '' : 'bg-gold/20 text-gold border border-gold/30',
    ]"
  >
    <img
      v-if="src"
      :src="src"
      :alt="alt"
      class="w-full h-full object-cover"
    />
    <span v-else class="font-medium">{{ initials }}</span>
  </div>
</template>
