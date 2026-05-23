<script setup lang="ts">
const show = ref(true)

onMounted(() => {
  setTimeout(() => { show.value = false }, 800)
})
</script>

<template>
  <Transition name="splash">
    <div
      v-if="show"
      class="fixed inset-0 z-[9999] flex items-center justify-center bg-[#0a0a0a]"
    >
      <div class="flex flex-col items-center gap-6 animate-fade-in">
        <img
          src="/loader.webp"
          alt="Burhan"
          class="w-20 h-20 sm:w-24 sm:h-24"
          style="animation: pulseGlow 2s ease-in-out infinite"
        />
        <div class="flex gap-1.5">
          <span class="w-2 h-2 rounded-full bg-gold/60 animate-bounce" style="animation-delay: 0s" />
          <span class="w-2 h-2 rounded-full bg-gold/60 animate-bounce" style="animation-delay: 0.15s" />
          <span class="w-2 h-2 rounded-full bg-gold/60 animate-bounce" style="animation-delay: 0.3s" />
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.splash-enter-active {
  transition: opacity 0.3s ease;
}
.splash-leave-active {
  transition: opacity 0.4s ease;
}
.splash-enter-from,
.splash-leave-to {
  opacity: 0;
}

@keyframes pulseGlow {
  0%, 100% { opacity: 0.7; filter: drop-shadow(0 0 4px rgba(212, 175, 55, 0.2)); }
  50% { opacity: 1; filter: drop-shadow(0 0 12px rgba(212, 175, 55, 0.5)); }
}
</style>
