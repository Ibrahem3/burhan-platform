<script setup lang="ts">
definePageMeta({
  middleware: 'super-admin-only',
})

await navigateTo('/admin/dashboard', { replace: true })
</script>

<template>
  <div />
</template>
