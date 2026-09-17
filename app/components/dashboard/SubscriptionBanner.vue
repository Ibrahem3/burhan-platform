<script setup lang="ts">
const { isExpired, isCancelled, status, plan, isReadOnly } = useSubscription()
const { t } = useI18n()

const planName = computed(() => {
  if (!plan.value?.name) return ''
  if (typeof plan.value.name === 'string') return plan.value.name
  return plan.value.name.ar || plan.value.name.en || ''
})
</script>

<template>
  <div v-if="isReadOnly" class="mb-6">
    <div
      v-if="isExpired"
      class="rounded-xl border border-amber-500/30 bg-amber-500/10 p-4 text-amber-200 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 shadow-lg"
    >
      <div class="flex items-center gap-3">
        <div class="w-9 h-9 rounded-lg bg-amber-500/20 flex items-center justify-center shrink-0">
          <svg class="w-5 h-5 text-amber-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
        </div>
        <div>
          <p class="text-sm font-bold text-white">انتهت صلاحية اشتراك المنظمة (وضع القراءة فقط)</p>
          <p class="text-xs text-amber-300/80">بياناتك محفوظة بالكامل. تم إيقاف عمليات التعديل والإنشاء مؤقتاً حتى تجديد الاشتراك.</p>
        </div>
      </div>
      <span class="text-xs font-mono px-2.5 py-1 rounded bg-amber-500/20 text-amber-300 border border-amber-500/30">
        {{ planName || 'Expired' }}
      </span>
    </div>

    <div
      v-else-if="isCancelled"
      class="rounded-xl border border-red-500/30 bg-red-500/10 p-4 text-red-200 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 shadow-lg"
    >
      <div class="flex items-center gap-3">
        <div class="w-9 h-9 rounded-lg bg-red-500/20 flex items-center justify-center shrink-0">
          <svg class="w-5 h-5 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
        <div>
          <p class="text-sm font-bold text-white">تم إلغاء اشتراك المنظمة</p>
          <p class="text-xs text-red-300/80">الوصول للمنظومة مقتصر على القراءة وتصفح المحتوى فقط.</p>
        </div>
      </div>
      <span class="text-xs font-mono px-2.5 py-1 rounded bg-red-500/20 text-red-300 border border-red-500/30">
        Cancelled
      </span>
    </div>

    <div
      v-else-if="status === 'none'"
      class="rounded-xl border border-gray-500/30 bg-gray-500/10 p-4 text-gray-200 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 shadow-lg"
    >
      <div class="flex items-center gap-3">
        <div class="w-9 h-9 rounded-lg bg-gray-500/20 flex items-center justify-center shrink-0">
          <svg class="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
        <div>
          <p class="text-sm font-bold text-white">لا يوجد اشتراك نشط للمنظمة</p>
          <p class="text-xs text-gray-400">يرجى التواصل مع مسؤول المنظومة لتفعيل الاشتراك.</p>
        </div>
      </div>
    </div>
  </div>
</template>
