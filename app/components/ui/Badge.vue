<script setup lang="ts">
interface Props {
  variant?: 'default' | 'premium' | 'success' | 'warning' | 'info'
  size?: 'sm' | 'md'
}

withDefaults(defineProps<Props>(), {
  variant: 'default',
  size: 'sm',
})

const variantClasses: Record<string, string> = {
  default: 'bg-white/10 text-gray-300 border-white/10',
  premium: 'bg-gold/20 text-gold border-gold/30',
  success: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30',
  warning: 'bg-amber-500/20 text-amber-400 border-amber-500/30',
  info: 'bg-blue-500/20 text-blue-400 border-blue-500/30',
}

const sizeClasses: Record<string, string> = {
  sm: 'px-2 py-0.5 text-xs',
  md: 'px-3 py-1 text-sm',
}
</script>

<template>
  <span
    :class="[
      'inline-flex items-center gap-1 font-medium rounded-full border',
      variantClasses[variant],
      sizeClasses[size],
    ]"
  >
    <slot />
  </span>
</template>
