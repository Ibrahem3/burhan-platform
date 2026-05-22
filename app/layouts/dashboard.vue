<script setup lang="ts">
const { t, locale } = useI18n()
const isPinned = useCookie('sidebar-pinned', { default: () => false })
</script>

<template>
  <div class="min-h-screen bg-[#0a0a0a] text-gray-100">
    <FloatingSidebar />

    <div
      class="flex flex-col min-h-screen transition-all duration-300"
      :class="isPinned ? (locale === 'ar' ? 'lg:mr-[380px]' : 'lg:ml-[380px]') : ''"
    >
      <main class="flex-1 p-4 lg:p-6">
        <slot />
      </main>
    </div>
  </div>
</template>
