<script setup lang="ts">
import type { Editor } from '@tiptap/vue-3'

const editorRef = inject<{ value: Editor | null }>('editor')
const selectionKey = inject<Ref<number>>('selectionKey', ref(0))

const editor = computed(() => {
  selectionKey.value
  return editorRef?.value ?? null
})

const linkModalOpen = ref(false)
const linkUrl = ref('')

function isActive(name: string, attrs?: Record<string, any>): boolean {
  selectionKey.value
  return editor.value?.isActive(name, attrs) ?? false
}

function openLinkModal() {
  const currentUrl = editor.value?.getAttributes('link').href || ''
  linkUrl.value = currentUrl || 'https://'
  linkModalOpen.value = true
}

function setLink() {
  if (!linkUrl.value) {
    editor.value?.chain().focus().unsetLink().run()
  } else {
    editor.value?.chain().focus().setLink({ href: linkUrl.value }).run()
  }
  linkModalOpen.value = false
}
</script>

<template>
  <div
    class="sticky top-0 z-50 flex flex-wrap items-center gap-1 text-gray-300 bg-white/5 px-2 py-1.5 rounded-xl border border-white/10"
  >
    <button
      type="button"
      class="p-2 hover:bg-white/10 rounded-lg transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
      :class="{ 'bg-white/15 text-white': isActive('undo') }"
      :title="$t('dashboard.editor.toolbar.undo')"
      :disabled="!editor?.can()?.undo()"
      @mousedown.prevent="editor?.chain()?.focus()?.undo()?.run()"
    >
      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6" />
      </svg>
    </button>
    <button
      type="button"
      class="p-2 hover:bg-white/10 rounded-lg transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
      :class="{ 'bg-white/15 text-white': isActive('redo') }"
      :title="$t('dashboard.editor.toolbar.redo')"
      :disabled="!editor?.can()?.redo()"
      @mousedown.prevent="editor?.chain()?.focus()?.redo()?.run()"
    >
      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 10H11a8 8 0 00-8 8v2m18-10l-6 6m6-6l-6-6" />
      </svg>
    </button>

    <div class="w-px h-6 bg-white/10 mx-1" />

    <button
      type="button"
      class="p-2 hover:bg-white/10 rounded-lg transition-colors font-bold text-sm disabled:opacity-30 disabled:cursor-not-allowed"
      :class="{ 'bg-gold/20 text-gold': isActive('heading', { level: 2 }) }"
      :title="$t('dashboard.editor.toolbar.heading_2')"
      :disabled="!editor?.can()?.toggleHeading({ level: 2 })"
      @mousedown.prevent="editor?.chain()?.focus()?.toggleHeading({ level: 2 })?.run()"
    >
      H2
    </button>
    <button
      type="button"
      class="p-2 hover:bg-white/10 rounded-lg transition-colors font-bold text-sm disabled:opacity-30 disabled:cursor-not-allowed"
      :class="{ 'bg-gold/20 text-gold': isActive('heading', { level: 3 }) }"
      :title="$t('dashboard.editor.toolbar.heading_3')"
      :disabled="!editor?.can()?.toggleHeading({ level: 3 })"
      @mousedown.prevent="editor?.chain()?.focus()?.toggleHeading({ level: 3 })?.run()"
    >
      H3
    </button>

    <div class="w-px h-6 bg-white/10 mx-1" />

    <button
      type="button"
      class="p-2 hover:bg-white/10 rounded-lg transition-colors font-bold text-sm min-w-[28px] disabled:opacity-30 disabled:cursor-not-allowed"
      :class="{ 'bg-gold/20 text-gold': isActive('bold') }"
      :title="$t('dashboard.editor.toolbar.bold')"
      :disabled="!editor?.can()?.toggleBold()"
      @mousedown.prevent="editor?.chain()?.focus()?.toggleBold()?.run()"
    >
      <b>B</b>
    </button>
    <button
      type="button"
      class="p-2 hover:bg-white/10 rounded-lg transition-colors italic text-sm min-w-[28px] disabled:opacity-30 disabled:cursor-not-allowed"
      :class="{ 'bg-gold/20 text-gold': isActive('italic') }"
      :title="$t('dashboard.editor.toolbar.italic')"
      :disabled="!editor?.can()?.toggleItalic()"
      @mousedown.prevent="editor?.chain()?.focus()?.toggleItalic()?.run()"
    >
      <i>I</i>
    </button>
    <button
      type="button"
      class="p-2 hover:bg-white/10 rounded-lg transition-colors underline text-sm min-w-[28px] disabled:opacity-30 disabled:cursor-not-allowed"
      :class="{ 'bg-gold/20 text-gold': isActive('underline') }"
      :title="$t('dashboard.editor.toolbar.underline')"
      :disabled="!editor?.can()?.toggleUnderline()"
      @mousedown.prevent="editor?.chain()?.focus()?.toggleUnderline()?.run()"
    >
      <u>U</u>
    </button>

    <div class="w-px h-6 bg-white/10 mx-1" />

    <button
      type="button"
      class="p-2 hover:bg-white/10 rounded-lg transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
      :class="{ 'bg-gold/20 text-gold': isActive('bulletList') }"
      :title="$t('dashboard.editor.toolbar.bullet_list')"
      :disabled="!editor?.can()?.toggleBulletList()"
      @mousedown.prevent="editor?.chain()?.focus()?.toggleBulletList()?.run()"
    >
      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16" />
      </svg>
    </button>
    <button
      type="button"
      class="p-2 hover:bg-white/10 rounded-lg transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
      :class="{ 'bg-gold/20 text-gold': isActive('link') }"
      :title="$t('dashboard.editor.toolbar.insert_link')"
      :disabled="!editor?.can()?.setLink({ href: '' })"
      @mousedown.prevent="editor?.chain()?.focus()?.run(); openLinkModal()"
    >
      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
      </svg>
    </button>

    <div class="w-px h-6 bg-white/10 mx-1" />

    <button
      type="button"
      class="p-2 hover:bg-red-500/20 text-red-400 rounded-lg transition-colors disabled:opacity-30 disabled:cursor-not-allowed"
      :class="{ 'bg-red-500/30 text-red-300': isActive('link') || isActive('bold') || isActive('italic') || isActive('underline') || isActive('heading') || isActive('bulletList') }"
      :title="$t('dashboard.editor.toolbar.remove_format')"
      :disabled="!editor?.can()?.unsetAllMarks()"
      @mousedown.prevent="editor?.chain()?.focus()?.unsetAllMarks()?.clearNodes()?.run()"
    >
      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
      </svg>
    </button>
  </div>

  <!-- Link Modal -->
  <Transition name="fade">
    <div
      v-if="linkModalOpen"
      class="fixed inset-0 z-[100] flex items-center justify-center"
    >
      <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="linkModalOpen = false" />
      <div class="relative bg-zinc-900 border border-white/10 p-6 rounded-2xl w-full max-w-md shadow-2xl">
        <h3 class="text-lg font-bold text-white mb-4">🔗 {{ $t('dashboard.editor.toolbar.insert_link') }}</h3>
        <input
          v-model="linkUrl"
          type="url"
          class="w-full bg-black/40 border border-white/10 rounded-xl p-3 text-white mb-6 focus:outline-none focus:border-gold/50"
          @keyup.enter="setLink"
        />
        <div class="flex justify-end gap-3">
          <button
            type="button"
            class="text-gray-400 hover:text-white transition-colors px-4 py-2"
            @click="linkModalOpen = false"
          >
            {{ $t('common.cancel') }}
          </button>
          <button
            type="button"
            class="bg-gold px-6 py-2 rounded-lg font-bold text-black"
            @click="setLink"
          >
            {{ $t('common.save') }}
          </button>
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
