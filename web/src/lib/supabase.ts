import { createClient, type SupabaseClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string | undefined

export const supabase: SupabaseClient | null = url && key ? createClient(url, key, { auth: { persistSession: true, autoRefreshToken: true } }) : null

export const PHOTO_BUCKET = 'goal-photos'

export const owner = {
  name: (import.meta.env.VITE_OWNER_NAME as string | undefined) || '',
  email: (import.meta.env.VITE_CONTACT_EMAIL as string | undefined) || '',
}
