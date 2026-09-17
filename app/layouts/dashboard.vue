<script setup lang="ts">
const { t, locale } = useI18n()
const isPinned = useCookie('sidebar-pinned', { default: () => false })
const { bootstrap, bootstrapStatus, bootstrapError, signOut } = useTenantBootstrap()
const { isSuperAdmin } = useUser()

// Trigger tenant bootstrap on dashboard mount
onMounted(async () => {
  if (!isSuperAdmin.value) {
    await bootstrap()
  }
})
</script>

<template>
  <div class="min-h-screen bg-[#0a0a0a] text-gray-100">
    <FloatingSidebar />

    <div
      class="flex flex-col min-h-screen transition-all duration-300"
      :class="isPinned ? (locale === 'ar' ? 'lg:mr-[380px]' : 'lg:ml-[380px]') : ''"
    >
      <main class="flex-1 p-4 lg:p-6">
        <!-- Bootstrap Loading State -->
        <div v-if="bootstrapStatus === 'loading'" class="flex flex-col items-center justify-center min-h-[60vh] gap-4">
          <div class="w-10 h-10 border-2 border-gold border-t-transparent rounded-full animate-spin" />
          <p class="text-sm text-gray-400 font-medium">جارٍ تهيئة بيانات المنظومة والاشتراك...</p>
        </div>

        <!-- Bootstrap Error / Unassigned State -->
        <div v-else-if="bootstrapStatus === 'error'" class="max-w-xl mx-auto my-12 p-6 glass rounded-2xl border border-red-500/20 text-center space-y-4">
          <div class="w-12 h-12 mx-auto rounded-full bg-red-500/10 flex items-center justify-center text-red-400">
            <svg class="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </div>
          <h2 class="text-lg font-bold text-white">تعذر تحميل بيانات المنظمة</h2>
          <p class="text-sm text-gray-400">{{ bootstrapError || 'حدث خطأ غير متوقع أثناء الاتصال بالخادم.' }}</p>
          <div class="pt-4 flex items-center justify-center gap-3">
            <button
              class="px-4 py-2 bg-gold text-onyx font-bold rounded-xl text-sm hover:bg-gold-500 transition-colors"
              @click="bootstrap(true)"
            >
              إعادة المحاولة
            </button>
            <button
              class="px-4 py-2 bg-white/5 border border-white/10 text-gray-300 rounded-xl text-sm hover:bg-white/10 transition-colors"
              @click="signOut"
            >
              تسجيل الخروج
            </button>
          </div>
        </div>

        <!-- Authenticated Content Shell -->
        <template v-else>
          <SubscriptionBanner />
          <slot />
        </template>
      </main>
    </div>
  </div>
</template>
