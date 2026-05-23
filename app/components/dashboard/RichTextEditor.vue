<script setup lang="ts">
import { useEditor, EditorContent } from '@tiptap/vue-3'
import StarterKit from '@tiptap/starter-kit'
import Underline from '@tiptap/extension-underline'
import Link from '@tiptap/extension-link'
import TextAlign from '@tiptap/extension-text-align'
import Placeholder from '@tiptap/extension-placeholder'

const props = withDefaults(defineProps<{
  modelValue: string
  placeholder?: string
  dir?: 'rtl' | 'ltr'
}>(), {
  dir: 'rtl',
})

const emit = defineEmits<{
  'update:modelValue': [value: string]
  'image-upload': [file: File]
}>()

const editor = useEditor({
  content: props.modelValue || '',
  extensions: [
    StarterKit.configure({
      heading: { levels: [2, 3] },
      link: false,
      underline: false,
    }),
    Underline,
    Link.configure({
      openOnClick: true,
      HTMLAttributes: {
        class: 'text-gold underline underline-offset-2',
      },
    }),
    TextAlign.configure({
      types: ['heading', 'paragraph'],
      defaultAlignment: props.dir === 'rtl' ? 'right' : 'left',
    }),
    Placeholder.configure({
      placeholder: props.placeholder || '',
    }),
  ],
  editorProps: {
    attributes: {
      class: 'focus:outline-none text-lg text-gray-300 leading-relaxed min-h-[400px] px-0 py-2',
      dir: props.dir,
    },
    transformPastedHTML(html) {
      const doc = new DOMParser().parseFromString(html, 'text/html')
      const walker = doc.createTreeWalker(doc.body, NodeFilter.SHOW_ELEMENT, null)
      let node: Element | null
      while ((node = walker.nextNode() as Element | null)) {
        node.removeAttribute('style')
        node.removeAttribute('class')
        node.removeAttribute('id')
        node.removeAttribute('dir')
        node.removeAttribute('lang')
        node.removeAttribute('face')
        node.removeAttribute('size')
        node.removeAttribute('color')
        if (node.tagName === 'FONT' || node.tagName === 'SPAN') {
          node.replaceWith(...Array.from(node.childNodes))
        }
      }
      return doc.body.innerHTML
    },
  },
  onUpdate({ editor: ed }) {
    emit('update:modelValue', ed.getHTML())
  },
  onSelectionUpdate() {
    selectionKey.value++
  },
})

const selectionKey = ref(0)

provide('editor', editor)
provide('selectionKey', selectionKey)

watch(() => props.modelValue, (val) => {
  if (editor.value && val !== editor.value.getHTML()) {
    editor.value.commands.setContent(val || '')
  }
})

watch(() => props.dir, (dir) => {
  if (editor.value) {
    editor.value.chain().focus().setTextAlign(dir === 'rtl' ? 'right' : 'left').run()
    editor.value.view.dom.setAttribute('dir', dir)
  }
})

onBeforeUnmount(() => {
  editor.value?.destroy()
})
</script>

<template>
  <div class="w-full space-y-4">
    <EditorToolbar />
    <EditorContent :editor="editor" class="w-full bg-transparent border-none outline-none" />
  </div>
</template>

<style>
.ProseMirror {
  @apply outline-none text-lg text-gray-300 leading-relaxed min-h-[400px] px-0 py-2;
}
.ProseMirror h2 {
  @apply text-white font-bold text-2xl mt-10 mb-4;
}
.ProseMirror h3 {
  @apply text-white font-bold text-xl mt-8 mb-3;
}
.ProseMirror p {
  @apply mb-5 leading-[1.85];
}
.ProseMirror a {
  @apply text-gold hover:underline decoration-gold/40 underline-offset-2;
}
.ProseMirror ul {
  @apply list-disc pl-6 space-y-1 mb-5;
}
.ProseMirror ol {
  @apply list-decimal pl-6 space-y-1 mb-5;
}
.ProseMirror li {
  @apply text-gray-300;
}
.ProseMirror blockquote {
  @apply border-r-2 border-gold/30 pr-5 mr-0 italic text-base my-6;
  color: #9ca3af;
}
.ProseMirror img {
  @apply rounded-2xl my-8 mx-auto max-w-full;
}
.ProseMirror hr {
  @apply border-white/5 my-10;
}
.ProseMirror strong {
  @apply text-white font-semibold;
}
.ProseMirror code {
  @apply bg-white/5 px-2 py-0.5 rounded text-sm;
  color: #fcd34d;
}
.ProseMirror pre {
  @apply bg-white/5 rounded-2xl p-5 overflow-x-auto border border-white/5 my-6;
}
.ProseMirror p.is-editor-empty:first-child::before {
  content: attr(data-placeholder);
  @apply text-gray-600 pointer-events-none float-left h-0;
}
</style>
