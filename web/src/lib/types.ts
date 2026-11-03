export interface Profile {
  display_name: string
  onboarded: boolean
}

export interface Goal {
  id: string
  name: string
  target_amount: number
  photo_url: string | null
  photo_position: string
  catalog_id: string | null
  is_default: boolean
  created_at: string
  updated_at: string
  deleted_at: string | null
}

export interface Deposit {
  id: string
  goal_id: string
  amount: number
  deposit_date: string // YYYY-MM-DD
  note: string | null
  created_at: string
  updated_at: string
  deleted_at: string | null
}

export interface CatalogItem {
  id: string
  family: 'neo' | 'air' | 'pro'
  name: string
  chip: string
  screen_inches: number
  cpu_cores: number | null
  gpu_cores: number | null
  memory_gb: number
  storage_gb: number
  price_pln: number
  popularity: number
  is_active: boolean
}

export type Lang = 'pl' | 'en'
export type ThemePref = 'system' | 'light' | 'dark'
