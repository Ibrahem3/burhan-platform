export function useSupabaseStorage() {
  const supabase = useSupabaseClient()
  const uploading = ref(false)
  const uploadError = ref<string | null>(null)

  async function uploadFile(
    file: File,
    orgId: string,
    bucket = 'organization_assets',
  ): Promise<string | null> {
    uploading.value = true
    uploadError.value = null

    try {
      const ext = file.name.split('.').pop()
      const fileName = `${crypto.randomUUID()}.${ext}`
      const filePath = `${orgId}/entities/${fileName}`

      const { error: storageError } = await supabase.storage
        .from(bucket)
        .upload(filePath, file, {
          cacheControl: '3600',
          upsert: false,
          contentType: file.type,
        })

      if (storageError) {
        uploadError.value = storageError.message
        return null
      }

      const { data: { publicUrl } } = supabase.storage
        .from(bucket)
        .getPublicUrl(filePath)

      return publicUrl
    } finally {
      uploading.value = false
    }
  }

  return {
    uploadFile,
    uploading: readonly(uploading),
    uploadError: readonly(uploadError),
  }
}
