<script setup lang="ts">
const props = defineProps<{
  modelValue: string
  placeholder?: string
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
  'image-upload': [file: File]
}>()

const editorRef = ref<HTMLElement | null>(null)
const history = ref<string[]>([])
const historyIndex = ref(-1)
const maxHistory = 50

function pushState() {
  const html = editorRef.value?.innerHTML || ''
  if (history.value[historyIndex.value] === html) return
  history.value = history.value.slice(0, historyIndex.value + 1)
  history.value.push(html)
  if (history.value.length > maxHistory) history.value.shift()
  historyIndex.value = history.value.length - 1
}

function emitContent() {
  emit('update:modelValue', editorRef.value?.innerHTML || '')
}

function onInput() {
  pushState()
  emitContent()
}

function saveSelection(): Range | null {
  const sel = window.getSelection()
  if (!sel || !sel.rangeCount) return null
  return sel.getRangeAt(0)
}

function restoreSelection(range: Range | null) {
  if (!range) return
  const sel = window.getSelection()
  if (!sel) return
  sel.removeAllRanges()
  sel.addRange(range)
  editorRef.value?.focus()
}

function applyBlockTag(tag: string) {
  const sel = window.getSelection()
  if (!sel || !sel.rangeCount || !editorRef.value) return
  const range = sel.getRangeAt(0)
  let node: Node | null = range.commonAncestorContainer
  while (node && node !== editorRef.value) {
    if (node.nodeType === Node.ELEMENT_NODE) {
      const el = node as HTMLElement
      if (el.tagName === 'P' || el.tagName === 'DIV' || /^H[1-6]$/.test(el.tagName)) {
        const newEl = document.createElement(tag)
        newEl.innerHTML = el.innerHTML
        el.parentNode?.replaceChild(newEl, el)
        pushState()
        emitContent()
        return
      }
    }
    node = node.parentNode
  }
}

function applyInlineTag(tag: string) {
  const sel = window.getSelection()
  if (!sel || !sel.rangeCount || sel.isCollapsed) return
  const range = sel.getRangeAt(0)

  const selectedText = range.extractContents()
  const wrapper = document.createElement(tag)
  wrapper.appendChild(selectedText)
  range.insertNode(wrapper)

  sel.removeAllRanges()
  const newRange = document.createRange()
  newRange.selectNodeContents(wrapper)
  sel.addRange(newRange)

  pushState()
  emitContent()
}

function toggleBold() {
  const sel = window.getSelection()
  if (!sel || !sel.rangeCount || sel.isCollapsed || !editorRef.value) return

  const range = sel.getRangeAt(0)
  let parent = range.commonAncestorContainer
  if (parent.nodeType === Node.TEXT_NODE) parent = parent.parentNode as HTMLElement

  if (parent && (parent as HTMLElement).tagName === 'STRONG') {
    const el = parent as HTMLElement
    const frag = document.createDocumentFragment()
    while (el.firstChild) frag.appendChild(el.firstChild)
    el.parentNode?.replaceChild(frag, el)
  } else {
    applyInlineTag('strong')
  }
  pushState()
  emitContent()
}

function toggleItalic() {
  const sel = window.getSelection()
  if (!sel || !sel.rangeCount || sel.isCollapsed || !editorRef.value) return

  const range = sel.getRangeAt(0)
  let parent = range.commonAncestorContainer
  if (parent.nodeType === Node.TEXT_NODE) parent = parent.parentNode as HTMLElement

  if (parent && (parent as HTMLElement).tagName === 'EM') {
    const el = parent as HTMLElement
    const frag = document.createDocumentFragment()
    while (el.firstChild) frag.appendChild(el.firstChild)
    el.parentNode?.replaceChild(frag, el)
  } else {
    applyInlineTag('em')
  }
  pushState()
  emitContent()
}

function toggleUnderline() {
  const sel = window.getSelection()
  if (!sel || !sel.rangeCount || sel.isCollapsed || !editorRef.value) return

  const range = sel.getRangeAt(0)
  let parent = range.commonAncestorContainer
  if (parent.nodeType === Node.TEXT_NODE) parent = parent.parentNode as HTMLElement

  if (parent && (parent as HTMLElement).tagName === 'U') {
    const el = parent as HTMLElement
    const frag = document.createDocumentFragment()
    while (el.firstChild) frag.appendChild(el.firstChild)
    el.parentNode?.replaceChild(frag, el)
  } else {
    applyInlineTag('u')
  }
  pushState()
  emitContent()
}

function setHeading(level: 'h2' | 'h3') {
  applyBlockTag(level)
}

function insertUnorderedList() {
  const sel = window.getSelection()
  if (!sel || !sel.rangeCount || !editorRef.value) return
  const range = sel.getRangeAt(0)
  let node: Node | null = range.commonAncestorContainer
  while (node && node !== editorRef.value) {
    if (node.nodeType === Node.ELEMENT_NODE) {
      const el = node as HTMLElement
      if (el.tagName === 'P' || el.tagName === 'DIV' || /^H[1-6]$/.test(el.tagName)) {
        const ul = document.createElement('ul')
        const li = document.createElement('li')
        li.innerHTML = el.innerHTML
        ul.appendChild(li)
        el.parentNode?.replaceChild(ul, el)
        pushState()
        emitContent()
        return
      }
    }
    node = node.parentNode
  }
}

const showLinkModal = ref(false)
const linkUrl = ref('https://')
let savedRange: Range | null = null

function openLinkModal() {
  const sel = window.getSelection()
  if (!sel || !sel.rangeCount || sel.isCollapsed) return
  savedRange = sel.getRangeAt(0)
  linkUrl.value = 'https://'
  showLinkModal.value = true
}

function confirmAddLink() {
  if (!savedRange || !linkUrl.value) {
    showLinkModal.value = false
    return
  }
  const sel = window.getSelection()
  if (!sel) return
  sel.removeAllRanges()
  sel.addRange(savedRange)

  const anchor = document.createElement('a')
  anchor.href = linkUrl.value
  anchor.target = '_blank'
  anchor.rel = 'noopener noreferrer'

  const selectedText = savedRange.extractContents()
  anchor.appendChild(selectedText)
  savedRange.insertNode(anchor)

  sel.removeAllRanges()
  const newRange = document.createRange()
  newRange.selectNodeContents(anchor)
  sel.addRange(newRange)

  pushState()
  emitContent()
  showLinkModal.value = false
}

function removeFormat() {
  const sel = window.getSelection()
  if (!sel || !sel.rangeCount || sel.isCollapsed || !editorRef.value) return
  const range = sel.getRangeAt(0)

  const fragment = range.extractContents()
  const text = fragment.textContent || ''
  range.insertNode(document.createTextNode(text))

  pushState()
  emitContent()
}

function undo() {
  if (historyIndex.value <= 0) return
  historyIndex.value--
  if (editorRef.value) {
    editorRef.value.innerHTML = history.value[historyIndex.value]
  }
  emitContent()
}

function redo() {
  if (historyIndex.value >= history.value.length - 1) return
  historyIndex.value++
  if (editorRef.value) {
    editorRef.value.innerHTML = history.value[historyIndex.value]
  }
  emitContent()
}

const showImageModal = ref(false)

const fileInput = ref<HTMLInputElement | null>(null)

function triggerImageUpload() {
  fileInput.value?.click()
}

function handleImageFile(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (file) {
    emit('image-upload', file)
  }
  input.value = ''
}

onMounted(() => {
  if (editorRef.value) {
    editorRef.value.innerHTML = props.modelValue || ''
    pushState()
  }
})
</script>

<template>
  <div class="space-y-4">
    <!-- Toolbar -->
    <div class="flex flex-wrap items-center gap-1 text-gray-300 bg-white/5 w-fit px-2 py-1.5 rounded-xl border border-white/10">
      <button
        type="button"
        class="p-2 hover:bg-white/10 rounded-lg transition-colors"
        :title="$t('dashboard.editor.toolbar.undo')"
        @click="undo"
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6" />
        </svg>
      </button>
      <button
        type="button"
        class="p-2 hover:bg-white/10 rounded-lg transition-colors"
        :title="$t('dashboard.editor.toolbar.redo')"
        @click="redo"
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 10H11a8 8 0 00-8 8v2m18-10l-6 6m6-6l-6-6" />
        </svg>
      </button>

      <div class="w-px h-6 bg-white/10 mx-1" />

      <button
        type="button"
        class="p-2 hover:bg-white/10 rounded-lg transition-colors font-bold text-sm"
        :title="$t('dashboard.editor.toolbar.heading_2')"
        @click="setHeading('h2')"
      >
        H2
      </button>
      <button
        type="button"
        class="p-2 hover:bg-white/10 rounded-lg transition-colors font-bold text-sm"
        :title="$t('dashboard.editor.toolbar.heading_3')"
        @click="setHeading('h3')"
      >
        H3
      </button>

      <div class="w-px h-6 bg-white/10 mx-1" />

      <button
        type="button"
        class="p-2 hover:bg-white/10 rounded-lg transition-colors font-bold text-sm min-w-[28px]"
        :title="$t('dashboard.editor.toolbar.bold')"
        @click="toggleBold"
      >
        <b>B</b>
      </button>
      <button
        type="button"
        class="p-2 hover:bg-white/10 rounded-lg transition-colors italic text-sm min-w-[28px]"
        :title="$t('dashboard.editor.toolbar.italic')"
        @click="toggleItalic"
      >
        <i>I</i>
      </button>
      <button
        type="button"
        class="p-2 hover:bg-white/10 rounded-lg transition-colors underline text-sm min-w-[28px]"
        :title="$t('dashboard.editor.toolbar.underline')"
        @click="toggleUnderline"
      >
        <u>U</u>
      </button>

      <div class="w-px h-6 bg-white/10 mx-1" />

      <button
        type="button"
        class="p-2 hover:bg-white/10 rounded-lg transition-colors"
        :title="$t('dashboard.editor.toolbar.bullet_list')"
        @click="insertUnorderedList"
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16" />
        </svg>
      </button>
      <button
        type="button"
        class="p-2 hover:bg-white/10 rounded-lg transition-colors"
        :title="$t('dashboard.editor.toolbar.insert_link')"
        @click="openLinkModal"
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
        </svg>
      </button>

      <div class="w-px h-6 bg-white/10 mx-1" />

      <button
        type="button"
        class="p-2 hover:bg-red-500/20 text-red-400 rounded-lg transition-colors"
        :title="$t('dashboard.editor.toolbar.remove_format')"
        @click="removeFormat"
      >
        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>

    <!-- Editor canvas -->
    <div
      ref="editorRef"
      contenteditable="true"
      class="w-full bg-transparent border-none outline-none text-lg text-gray-300 leading-relaxed min-h-[400px] focus:outline-none [&_h2]:text-2xl [&_h2]:font-bold [&_h2]:text-white [&_h2]:mt-6 [&_h2]:mb-3 [&_h3]:text-xl [&_h3]:font-semibold [&_h3]:text-white [&_h3]:mt-4 [&_h3]:mb-2 [&_strong]:text-white [&_a]:text-gold [&_a]:underline [&_ul]:list-disc [&_ul]:pl-6 [&_ul]:space-y-1 [&_ol]:list-decimal [&_ol]:pl-6 [&_ol]:space-y-1 [&_li]:text-gray-300 empty:before:content-[attr(data-placeholder)] empty:before:text-gray-600"
      :data-placeholder="placeholder"
      @input="onInput"
    />

    <!-- Link Modal -->
    <Transition name="fade">
      <div
        v-if="showLinkModal"
        class="fixed inset-0 z-50 flex items-center justify-center"
      >
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="showLinkModal = false" />
        <div class="relative bg-zinc-900 border border-white/10 p-6 rounded-2xl w-full max-w-md shadow-2xl">
          <h3 class="text-lg font-bold text-white mb-4">🔗 Insert Link</h3>
          <input
            v-model="linkUrl"
            type="url"
            class="w-full bg-black/40 border border-white/10 rounded-xl p-3 text-white mb-6 focus:outline-none focus:border-gold/50"
            @keyup.enter="confirmAddLink"
          />
          <div class="flex justify-end gap-3">
            <button
              type="button"
              class="text-gray-400 hover:text-white transition-colors"
              @click="showLinkModal = false"
            >
              Cancel
            </button>
            <button
              type="button"
              class="bg-gold px-6 py-2 rounded-lg font-bold text-black"
              @click="confirmAddLink"
            >
              Add
            </button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- Hidden file input for image upload -->
    <input
      ref="fileInput"
      type="file"
      accept="image/*"
      class="hidden"
      @change="handleImageFile"
    />
  </div>
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
