export function useScrollAware() {
  const visible = ref(true)
  const lastScrollY = ref(0)

  function onScroll() {
    const currentY = window.scrollY
    visible.value = currentY < 10 || currentY < lastScrollY.value
    lastScrollY.value = currentY
  }

  let cleanup: (() => void) | null = null

  onMounted(() => {
    window.addEventListener('scroll', onScroll, { passive: true })
    cleanup = () => window.removeEventListener('scroll', onScroll)
  })

  onUnmounted(() => {
    cleanup?.()
  })

  return { visible }
}
