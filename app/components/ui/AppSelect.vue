<script setup lang="ts">
const props = defineProps<{
  modelValue: string
  options: { value: string; label: string }[]
  placeholder?: string
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const open = ref(false)
const triggerRef = ref<HTMLElement | null>(null)
const listRef = ref<HTMLElement | null>(null)
const style = ref<Record<string, string>>({})

function toggle() {
  if (open.value) {
    close()
  } else {
    openMenu()
  }
}

function openMenu() {
  if (!triggerRef.value) return
  const rect = triggerRef.value.getBoundingClientRect()
  style.value = {
    position: 'fixed',
    top: `${rect.bottom + 4}px`,
    [document.documentElement.dir === 'rtl' ? 'right' : 'left']: `${document.documentElement.dir === 'rtl' ? window.innerWidth - rect.right : rect.left}px`,
    minWidth: `${Math.max(rect.width, 200)}px`,
    zIndex: '9999',
  }
  open.value = true
}

function close() {
  open.value = false
}

function select(val: string) {
  emit('update:modelValue', val)
  close()
}

function onClickOutside(e: MouseEvent) {
  if (!triggerRef.value?.contains(e.target as Node) && !listRef.value?.contains(e.target as Node)) {
    close()
  }
}

onMounted(() => document.addEventListener('click', onClickOutside))
onUnmounted(() => document.removeEventListener('click', onClickOutside))

const displayLabel = computed(() => {
  const opt = props.options.find(o => o.value === props.modelValue)
  return opt?.label || props.placeholder || ''
})
</script>

<template>
  <div ref="triggerRef" class="relative cursor-pointer select-none" @click="toggle">
    <div
      class="flex items-center justify-between gap-2 w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-gold/50 transition-colors"
      :class="{ 'border-gold/50': open }"
    >
      <span :class="{ 'text-gray-500': !modelValue }">{{ displayLabel }}</span>
      <svg
        class="w-4 h-4 text-gray-500 transition-transform duration-200"
        :class="{ 'rotate-180': open }"
        fill="none" viewBox="0 0 24 24" stroke="currentColor"
      >
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
      </svg>
    </div>
  </div>

  <Teleport to="body">
    <Transition name="fade">
      <div v-if="open" ref="listRef" :style="style" class="bg-zinc-900 border border-white/10 rounded-xl shadow-2xl py-1 max-h-60 overflow-y-auto">
        <button
          v-for="opt in options"
          :key="opt.value"
          class="w-full text-right px-4 py-2.5 text-sm transition-colors hover:bg-white/5"
          :class="opt.value === modelValue ? 'text-gold bg-gold/10' : 'text-gray-300'"
          @click="select(opt.value)"
        >
          {{ opt.label }}
        </button>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.15s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
