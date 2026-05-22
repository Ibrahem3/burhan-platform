<script setup lang="ts">
interface Props {
  variant?: 'primary' | 'secondary' | 'ghost' | 'outline'
  size?: 'sm' | 'md' | 'lg'
  disabled?: boolean
  loading?: boolean
  block?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'primary',
  size: 'md',
  disabled: false,
  loading: false,
  block: false,
})

const emit = defineEmits<{
  click: [e: MouseEvent]
}>()

const baseClasses = 'inline-flex items-center justify-center font-medium transition-all duration-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-gold/50 disabled:opacity-50 disabled:cursor-not-allowed'

const variantClasses: Record<string, string> = {
  primary: 'bg-gold text-onyx hover:bg-gold-500 active:bg-gold-600 shadow-lg shadow-gold/20',
  secondary: 'glass glass-hover text-gray-100',
  ghost: 'text-gray-300 hover:text-gold hover:bg-white/5',
  outline: 'gold-border text-gold hover:bg-gold/10',
}

const sizeClasses: Record<string, string> = {
  sm: 'px-3 py-1.5 text-sm gap-1.5',
  md: 'px-5 py-2.5 text-sm gap-2',
  lg: 'px-7 py-3.5 text-base gap-2.5',
}
</script>

<template>
  <button
    :class="[
      baseClasses,
      variantClasses[variant],
      sizeClasses[size],
      block ? 'w-full' : '',
    ]"
    :disabled="disabled || loading"
    @click="emit('click', $event)"
  >
    <span v-if="loading" class="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />
    <slot v-else name="icon" />
    <slot />
  </button>
</template>
