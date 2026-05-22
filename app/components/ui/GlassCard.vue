<script setup lang="ts">
interface Props {
  hover?: boolean
  padding?: 'sm' | 'md' | 'lg'
}

withDefaults(defineProps<Props>(), {
  hover: false,
  padding: 'md',
})

const paddingClasses: Record<string, string> = {
  sm: 'p-4',
  md: 'p-6',
  lg: 'p-8',
}
</script>

<template>
  <div
    :class="[
      'glass rounded-2xl',
      paddingClasses[padding],
      hover ? 'glass-hover cursor-pointer' : '',
    ]"
  >
    <slot />
  </div>
</template>
