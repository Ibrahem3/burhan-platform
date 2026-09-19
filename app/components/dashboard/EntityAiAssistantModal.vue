<script setup lang="ts">
import { useAiGenerate } from '~/composables/useAiGenerate'

const props = withDefaults(defineProps<{
  modelValue: boolean
  currentLang?: 'ar' | 'en'
  branchId?: string | null
  editorContent?: string | null
  sourceContent?: string | null
  sourceLanguage?: 'ar' | 'en' | null
}>(), {
  currentLang: 'ar',
  branchId: null,
  editorContent: null,
  sourceContent: null,
  sourceLanguage: null,
})

const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  'apply': [{ content: string; mode: 'insert' | 'append' | 'replace'; targetLang?: 'ar' | 'en' }]
}>()

const { t } = useI18n()
const { isReadOnly, features } = useSubscription()
const { isSuperAdmin } = useUser()
const { state, generate, cancel, reset, consume } = useAiGenerate()

const prompt = ref('')
const systemPrompt = ref('')
const applyMode = ref<'insert' | 'append' | 'replace'>('append')
const showAdvanced = ref(false)
const showOverwriteConfirm = ref(false)
const pendingTranslationAction = ref<(() => Promise<void>) | null>(null)

const canUseAi = computed(() => {
  if (isSuperAdmin.value) return true
  if (isReadOnly.value) return false
  if (features.value?.ai_generate === false) return false
  return true
})

const displayedResult = computed(() => {
  if (state.value.outputFinal) return state.value.outputFinal
  if (state.value.outputBuffer) return state.value.outputBuffer
  return ''
})

const isGenerating = computed(() => {
  return state.value.status === 'pending' || state.value.status === 'processing'
})

const isCompleted = computed(() => {
  return state.value.status === 'completed' && Boolean(state.value.outputFinal)
})

// Translation availability helpers
const canTranslateToEnglish = computed(() => {
  return props.currentLang === 'ar' &&
    Boolean(props.editorContent?.replace(/<[^>]*>/g, '').trim())
})

const canTranslateToArabic = computed(() => {
  return props.currentLang === 'en' &&
    Boolean(props.editorContent?.replace(/<[^>]*>/g, '').trim())
})

function closeModal() {
  if (isGenerating.value) {
    cancel()
  }
  showOverwriteConfirm.value = false
  pendingTranslationAction.value = null
  emit('update:modelValue', false)
}

async function triggerDirectTranslation(targetLang: 'ar' | 'en') {
  if (isGenerating.value || !canUseAi.value) return

  // Check if target editor already has content -> ask for explicit overwrite confirmation
  const targetAlreadyHasContent = Boolean(props.sourceContent?.replace(/<[^>]*>/g, '').trim())
  if (targetAlreadyHasContent && !showOverwriteConfirm.value) {
    pendingTranslationAction.value = () => executeTranslation(targetLang)
    showOverwriteConfirm.value = true
    return
  }

  showOverwriteConfirm.value = false
  pendingTranslationAction.value = null
  await executeTranslation(targetLang)
}

const activeTargetLang = ref<'ar' | 'en'>(props.currentLang)

async function executeTranslation(targetLang: 'ar' | 'en') {
  activeTargetLang.value = targetLang
  const srcLang = targetLang === 'en' ? 'ar' : 'en'
  const srcName = srcLang === 'ar' ? 'Arabic' : 'English'
  const tgtName = targetLang === 'en' ? 'English' : 'Arabic'

  const translationPrompt = `Translate this entire article into professional, editorial-quality ${tgtName} while strictly preserving all semantic HTML tags (<h2>, <h3>, <p>, <ul>, <ol>, <li>, <blockquote>, <strong>, <em>) and exact structure.`

  prompt.value = translationPrompt

  await generate({
    prompt: translationPrompt,
    generationMode: 'current',
    editorContent: '',
    sourceContent: props.editorContent || null,
    sourceLanguage: srcLang,
    targetLanguage: targetLang,
    systemPrompt: systemPrompt.value.trim() || null,
    language: targetLang,
    branchId: props.branchId || null,
  })
}

function confirmOverwriteAndProceed() {
  if (pendingTranslationAction.value) {
    const act = pendingTranslationAction.value
    pendingTranslationAction.value = null
    showOverwriteConfirm.value = false
    act()
  }
}

function cancelOverwrite() {
  showOverwriteConfirm.value = false
  pendingTranslationAction.value = null
}

async function handleGenerate() {
  if (!prompt.value.trim() || isGenerating.value || !canUseAi.value) return

  activeTargetLang.value = props.currentLang
  const userPrompt = prompt.value.trim()

  // Check if translation / cross-language transform is explicitly requested
  const isTranslationRequest = Boolean(
    props.sourceContent &&
    props.sourceLanguage &&
    props.sourceLanguage !== props.currentLang &&
    /\b(translate|translation|ترجم|ترجمة|مترجم|نقل|انقل)\b/i.test(userPrompt)
  )

  await generate({
    prompt: userPrompt,
    generationMode: 'current',
    editorContent: props.editorContent || null,
    sourceContent: isTranslationRequest ? props.sourceContent : null,
    sourceLanguage: isTranslationRequest ? props.sourceLanguage : null,
    targetLanguage: props.currentLang,
    systemPrompt: systemPrompt.value.trim() || null,
    language: props.currentLang,
    branchId: props.branchId || null,
  })
}

async function handleApply() {
  if (state.value.jobId) {
    consume(state.value.jobId).catch(() => {})
  }

  const content = displayedResult.value
  if (!content) return

  emit('apply', {
    content,
    mode: applyMode.value,
    targetLang: activeTargetLang.value,
  })

  closeModal()
}

watch(() => props.modelValue, (open) => {
  if (open) {
    activeTargetLang.value = props.currentLang
  } else {
    reset()
    prompt.value = ''
    systemPrompt.value = ''
    showOverwriteConfirm.value = false
    pendingTranslationAction.value = null
  }
})
</script>

<template>
  <Transition name="fade">
    <div
      v-if="modelValue"
      class="fixed inset-0 z-[100] flex items-center justify-center p-4 sm:p-6"
    >
      <!-- Backdrop -->
      <div
        class="absolute inset-0 bg-black/70 backdrop-blur-md transition-opacity"
        @click="closeModal"
      />

      <!-- Modal Card -->
      <div
        class="relative bg-zinc-900 border border-white/10 rounded-2xl w-full max-w-2xl max-h-[90vh] flex flex-col shadow-2xl overflow-hidden"
        :dir="currentLang === 'ar' ? 'rtl' : 'ltr'"
      >
        <!-- Header -->
        <div class="px-6 py-4 border-b border-white/10 flex items-center justify-between bg-white/[0.02]">
          <div class="flex items-center gap-2.5">
            <div class="w-8 h-8 rounded-lg bg-gold/10 text-gold flex items-center justify-center border border-gold/20">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <div>
              <h3 class="text-base font-bold text-white flex items-center gap-2">
                مساعد الذكاء الاصطناعي
                <span class="text-[10px] px-2 py-0.5 rounded-full bg-gold/20 text-gold border border-gold/30 font-mono">
                  M1 DeAI
                </span>
              </h3>
              <p class="text-xs text-gray-400">توليد وصياغة محتوى ذكي مباشرة إلى محرر المقال</p>
            </div>
          </div>

          <button
            type="button"
            class="text-gray-400 hover:text-white p-1 rounded-lg hover:bg-white/5 transition-colors"
            @click="closeModal"
          >
            <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <!-- Body -->
        <div class="p-6 space-y-4 overflow-y-auto flex-1">
          <!-- Read-Only / Disabled Guard Notice -->
          <div
            v-if="!canUseAi"
            class="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-300 text-sm flex items-center gap-3"
          >
            <svg class="w-5 h-5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
            <span>
              {{ isReadOnly ? 'حساب المنظمة في وضع القراءة فقط. لا يمكن توليد محتوى جديد.' : 'خاصية توليد الذكاء الاصطناعي غير متاحة في خطتك الحالية.' }}
            </span>
          </div>

          <!-- Translation Quick Action & Target Header -->
          <div
            v-if="canTranslateToEnglish || canTranslateToArabic"
            class="p-3 bg-white/[0.03] border border-white/5 rounded-xl flex items-center justify-between"
          >
            <div class="flex items-center gap-2">
              <span class="text-xs font-semibold uppercase tracking-wider text-gray-400">الترجمة السريعة:</span>
              <span class="text-xs text-gray-300">ترجمة محتوى المقال الحالي مباشرة للغة الأخرى بدقة هيكلية كاملة</span>
            </div>
            <div class="flex items-center gap-2">
              <button
                v-if="canTranslateToEnglish"
                type="button"
                class="px-2.5 py-1 rounded-lg text-xs font-medium bg-emerald-500/10 text-emerald-300 border border-emerald-500/30 hover:bg-emerald-500/20 transition-colors flex items-center gap-1.5"
                :disabled="isGenerating || !canUseAi"
                @click="triggerDirectTranslation('en')"
              >
                <span>🌐</span>
                <span>ترجمة للإنجليزية</span>
              </button>
              <button
                v-else-if="canTranslateToArabic"
                type="button"
                class="px-2.5 py-1 rounded-lg text-xs font-medium bg-emerald-500/10 text-emerald-300 border border-emerald-500/30 hover:bg-emerald-500/20 transition-colors flex items-center gap-1.5"
                :disabled="isGenerating || !canUseAi"
                @click="triggerDirectTranslation('ar')"
              >
                <span>🌐</span>
                <span>ترجمة للعربية</span>
              </button>
            </div>
          </div>

          <!-- Explicit Overwrite Warning Dialog -->
          <div
            v-if="showOverwriteConfirm"
            class="p-3.5 rounded-xl bg-amber-500/10 border border-amber-500/30 text-amber-200 text-xs space-y-2"
          >
            <div class="flex items-center gap-2 font-bold">
              <span>⚠️</span>
              <span>تنبيه استبدال المحتوى</span>
            </div>
            <p>
              يوجد محتوى سابق في حقل اللغة الهدف. المتابعة ستؤدي إلى استبدال هذا المحتوى بالنسخة المترجمة الجديدة.
            </p>
            <div class="flex items-center justify-end gap-2 pt-1">
              <button
                type="button"
                class="px-3 py-1 rounded-lg text-xs text-gray-400 hover:text-white bg-white/5 transition-colors"
                @click="cancelOverwrite"
              >
                إلغاء
              </button>
              <button
                type="button"
                class="px-3 py-1 rounded-lg text-xs font-bold text-black bg-amber-400 hover:bg-amber-300 transition-colors"
                @click="confirmOverwriteAndProceed"
              >
                تأكيد واستبدال
              </button>
            </div>
          </div>

          <!-- Prompt Input -->
          <div>
            <div class="flex items-center justify-between mb-2">
              <label class="block text-xs font-semibold uppercase tracking-wider text-gray-400">
                تعليمات التحرير والتوليد (Instruction)
              </label>
              <div class="flex items-center gap-1.5 flex-wrap">
                <span
                  class="text-[10px] px-2 py-0.5 rounded-full bg-gold/10 text-gold border border-gold/20 font-mono uppercase font-bold"
                >
                  {{ currentLang === 'ar' ? 'الهدف: عربي' : 'Target: English' }}
                </span>
                <span
                  v-if="editorContent && editorContent.replace(/<[^>]*>/g, '').trim().length > 0"
                  class="text-[11px] px-2 py-0.5 rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/20 flex items-center gap-1 font-sans"
                >
                  <span>📄</span>
                  <span>المحرر متصل</span>
                </span>
                <span
                  v-else-if="sourceContent && sourceContent.replace(/<[^>]*>/g, '').trim().length > 0"
                  class="text-[11px] px-2 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 flex items-center gap-1 font-sans"
                  :title="currentLang === 'en' ? 'Arabic source available for translation' : 'English source available for translation'"
                >
                  <span>🌐</span>
                  <span>المقال متاح باللغة الأخرى للترجمة</span>
                </span>
                <span
                  v-else
                  class="text-[11px] px-2 py-0.5 rounded-full bg-white/5 text-gray-400 border border-white/10 flex items-center gap-1 font-sans"
                >
                  <span>✨</span>
                  <span>المحرر فارغ</span>
                </span>
              </div>
            </div>
            <textarea
              v-model="prompt"
              rows="3"
              class="w-full bg-black/40 border border-white/10 rounded-xl p-3 text-sm text-white placeholder-gray-600 focus:outline-none focus:border-gold/50 transition-colors resize-none"
              :placeholder="currentLang === 'ar' ? 'اكتب موضوع أو فكرة المقال، أو اطلب مسودة كاملة...' : 'Enter prompt or topic instructions...'"
              :disabled="isGenerating || !canUseAi"
            />
          </div>

          <!-- Advanced Toggle -->
          <div>
            <button
              type="button"
              class="text-xs text-gray-500 hover:text-gold flex items-center gap-1 transition-colors"
              @click="showAdvanced = !showAdvanced"
            >
              <svg
                class="w-3.5 h-3.5 transition-transform"
                :class="showAdvanced ? 'rotate-90' : ''"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
              <span>إعدادات متقدمة (تعليمات النظام)</span>
            </button>

            <div v-if="showAdvanced" class="mt-2">
              <textarea
                v-model="systemPrompt"
                rows="2"
                class="w-full bg-black/30 border border-white/5 rounded-xl p-2.5 text-xs text-white placeholder-gray-600 focus:outline-none focus:border-gold/40 transition-colors resize-none"
                placeholder="تعليمات إضافية لأسلوب النص، النبرة، أو سياق التوليد..."
                :disabled="isGenerating || !canUseAi"
              />
            </div>
          </div>

          <!-- Generation Status / Live Stream Box -->
          <div
            v-if="state.status !== 'idle'"
            class="rounded-xl border p-4 transition-all"
            :class="{
              'bg-blue-500/5 border-blue-500/20': isGenerating,
              'bg-green-500/5 border-green-500/20': isCompleted,
              'bg-red-500/5 border-red-500/20': state.status === 'failed' || state.status === 'cancelled',
            }"
          >
            <div class="flex items-center justify-between mb-2">
              <div class="flex items-center gap-2 text-xs font-semibold">
                <span
                  v-if="isGenerating"
                  class="w-2 h-2 rounded-full bg-blue-400 animate-ping"
                />
                <span
                  v-else-if="isCompleted"
                  class="w-2 h-2 rounded-full bg-green-400"
                />
                <span
                  v-else
                  class="w-2 h-2 rounded-full bg-red-400"
                />
                <span class="text-gray-300">
                  {{ isGenerating ? 'جاري المعالجة والتوليد...' : isCompleted ? 'اكتمل التوليد بنجاح' : 'توقف التوليد' }}
                </span>
              </div>

              <button
                v-if="isGenerating"
                type="button"
                class="text-xs text-red-400 hover:text-red-300 transition-colors"
                @click="cancel"
              >
                إلغاء
              </button>
            </div>

            <!-- Error message if any -->
            <p v-if="state.error" class="text-xs text-red-400 mt-1">
              {{ state.error }}
            </p>

            <!-- Output Preview Box -->
            <div
              v-if="displayedResult"
              class="mt-3 max-h-48 overflow-y-auto bg-black/40 rounded-lg p-3 border border-white/5 text-xs text-gray-300 leading-relaxed font-sans whitespace-pre-wrap select-text"
            >
              {{ displayedResult }}
            </div>
          </div>

          <!-- Application Options (Visible when result ready) -->
          <div v-if="isCompleted && displayedResult" class="pt-2 border-t border-white/10 space-y-3">
            <label class="block text-xs font-semibold uppercase tracking-wider text-gray-400">
              طريقة إدراج النص في المحرر:
            </label>
            <div class="grid grid-cols-3 gap-2">
              <label
                class="flex items-center justify-center gap-2 p-2.5 rounded-xl border text-xs font-medium cursor-pointer transition-all"
                :class="applyMode === 'append' ? 'bg-gold/10 border-gold text-gold' : 'bg-white/5 border-white/10 text-gray-400 hover:text-white'"
              >
                <input v-model="applyMode" type="radio" value="append" class="sr-only" />
                <span>إلحاق بالنهاية</span>
              </label>

              <label
                class="flex items-center justify-center gap-2 p-2.5 rounded-xl border text-xs font-medium cursor-pointer transition-all"
                :class="applyMode === 'insert' ? 'bg-gold/10 border-gold text-gold' : 'bg-white/5 border-white/10 text-gray-400 hover:text-white'"
              >
                <input v-model="applyMode" type="radio" value="insert" class="sr-only" />
                <span>إدراج في البداية</span>
              </label>

              <label
                class="flex items-center justify-center gap-2 p-2.5 rounded-xl border text-xs font-medium cursor-pointer transition-all"
                :class="applyMode === 'replace' ? 'bg-red-500/10 border-red-500/40 text-red-300' : 'bg-white/5 border-white/10 text-gray-400 hover:text-white'"
              >
                <input v-model="applyMode" type="radio" value="replace" class="sr-only" />
                <span>استبدال المحتوى</span>
              </label>
            </div>
          </div>
        </div>

        <!-- Footer -->
        <div class="px-6 py-3.5 border-t border-white/10 bg-white/[0.02] flex items-center justify-between">
          <button
            type="button"
            class="px-4 py-2 text-xs font-medium text-gray-400 hover:text-white transition-colors"
            @click="closeModal"
          >
            إغلاق
          </button>

          <div class="flex items-center gap-2">
            <button
              v-if="!isCompleted"
              type="button"
              class="px-5 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2"
              :class="!prompt.trim() || isGenerating || !canUseAi ? 'bg-white/10 text-gray-500 cursor-not-allowed' : 'bg-gold text-black hover:bg-gold/90 shadow-lg shadow-gold/20'"
              :disabled="!prompt.trim() || isGenerating || !canUseAi"
              @click="handleGenerate"
            >
              <svg v-if="isGenerating" class="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              <span>{{ isGenerating ? 'جاري التوليد...' : 'بدء التوليد' }}</span>
            </button>

            <button
              v-else
              type="button"
              class="px-5 py-2 rounded-xl text-xs font-bold bg-gold text-black hover:bg-gold/90 shadow-lg shadow-gold/20 transition-all flex items-center gap-2"
              @click="handleApply"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
              <span>إدراج في المحرر</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
