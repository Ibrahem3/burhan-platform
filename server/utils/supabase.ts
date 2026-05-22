import { createClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database'

export function getSupabaseClient() {
  const config = useRuntimeConfig()

  const url = config.public.supabase?.url as string
  const key = config.public.supabase?.key as string

  if (!url || !key) {
    throw createError({
      statusCode: 500,
      statusMessage: 'Supabase credentials are not configured. Check SUPABASE_URL and SUPABASE_KEY in .env',
    })
  }

  return createClient<Database>(url, key)
}

export function getSupabaseAdmin() {
  const config = useRuntimeConfig()

  const url = config.public.supabase?.url as string
  const serviceKey = config.supabase?.serviceKey as string

  if (!url || !serviceKey) {
    throw createError({
      statusCode: 500,
      statusMessage: 'Supabase admin credentials are not configured. Set SUPABASE_SERVICE_KEY in .env',
    })
  }

  return createClient<Database>(url, serviceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  })
}
