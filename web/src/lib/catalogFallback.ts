import type { CatalogItem } from './types'

/** Kopia katalogu z supabase/migrations (gdy nie ma sieci albo trybu bez konta przed pierwszym połączeniem). */
export const fallbackCatalog: CatalogItem[] = [
  { id: 'air13-m5-16-512', family: 'air', name: 'MacBook Air 13" M5', chip: 'M5', screen_inches: 13.6, cpu_cores: 10, gpu_cores: 8, memory_gb: 16, storage_gb: 512, price_pln: 5499, popularity: 100, is_active: true },
  { id: 'neo13-a18-8-256', family: 'neo', name: 'MacBook Neo 13"', chip: 'A18 Pro', screen_inches: 13.0, cpu_cores: 6, gpu_cores: 5, memory_gb: 8, storage_gb: 256, price_pln: 2999, popularity: 95, is_active: true },
  { id: 'air15-m5-16-512', family: 'air', name: 'MacBook Air 15" M5', chip: 'M5', screen_inches: 15.3, cpu_cores: 10, gpu_cores: 10, memory_gb: 16, storage_gb: 512, price_pln: 6499, popularity: 90, is_active: true },
  { id: 'pro14-m5-16-512', family: 'pro', name: 'MacBook Pro 14" M5', chip: 'M5', screen_inches: 14.2, cpu_cores: 10, gpu_cores: 10, memory_gb: 16, storage_gb: 512, price_pln: 7999, popularity: 85, is_active: true },
  { id: 'air13-m5-24-1024', family: 'air', name: 'MacBook Air 13" M5', chip: 'M5', screen_inches: 13.6, cpu_cores: 10, gpu_cores: 10, memory_gb: 24, storage_gb: 1024, price_pln: 7499, popularity: 75, is_active: true },
  { id: 'neo13-a18-8-512', family: 'neo', name: 'MacBook Neo 13" Touch ID', chip: 'A18 Pro', screen_inches: 13.0, cpu_cores: 6, gpu_cores: 5, memory_gb: 8, storage_gb: 512, price_pln: 3499, popularity: 70, is_active: true },
  { id: 'pro14-m5-16-1024', family: 'pro', name: 'MacBook Pro 14" M5', chip: 'M5', screen_inches: 14.2, cpu_cores: 10, gpu_cores: 10, memory_gb: 16, storage_gb: 1024, price_pln: 8999, popularity: 65, is_active: true },
  { id: 'air15-m5-24-1024', family: 'air', name: 'MacBook Air 15" M5', chip: 'M5', screen_inches: 15.3, cpu_cores: 10, gpu_cores: 10, memory_gb: 24, storage_gb: 1024, price_pln: 8499, popularity: 60, is_active: true },
  { id: 'pro14-m5-24-1024', family: 'pro', name: 'MacBook Pro 14" M5', chip: 'M5', screen_inches: 14.2, cpu_cores: 10, gpu_cores: 10, memory_gb: 24, storage_gb: 1024, price_pln: 9999, popularity: 55, is_active: true },
  { id: 'pro14-m5pro-24-1024', family: 'pro', name: 'MacBook Pro 14" M5 Pro', chip: 'M5 Pro', screen_inches: 14.2, cpu_cores: 15, gpu_cores: 16, memory_gb: 24, storage_gb: 1024, price_pln: 14999, popularity: 50, is_active: true },
  { id: 'pro16-m5pro-24-1024', family: 'pro', name: 'MacBook Pro 16" M5 Pro', chip: 'M5 Pro', screen_inches: 16.2, cpu_cores: 18, gpu_cores: 20, memory_gb: 24, storage_gb: 1024, price_pln: 17999, popularity: 45, is_active: true },
  { id: 'air13-m5-32-1024', family: 'air', name: 'MacBook Air 13" M5', chip: 'M5', screen_inches: 13.6, cpu_cores: 10, gpu_cores: 10, memory_gb: 32, storage_gb: 1024, price_pln: 8499, popularity: 40, is_active: true },
  { id: 'air15-m5-32-1024', family: 'air', name: 'MacBook Air 15" M5', chip: 'M5', screen_inches: 15.3, cpu_cores: 10, gpu_cores: 10, memory_gb: 32, storage_gb: 1024, price_pln: 9499, popularity: 35, is_active: true },
  { id: 'pro14-m5max-36-2048', family: 'pro', name: 'MacBook Pro 14" M5 Max', chip: 'M5 Max', screen_inches: 14.2, cpu_cores: 18, gpu_cores: 32, memory_gb: 36, storage_gb: 2048, price_pln: 23499, popularity: 30, is_active: true },
  { id: 'pro16-m5max-36-2048', family: 'pro', name: 'MacBook Pro 16" M5 Max', chip: 'M5 Max', screen_inches: 16.2, cpu_cores: 18, gpu_cores: 32, memory_gb: 36, storage_gb: 2048, price_pln: 24999, popularity: 25, is_active: true },
  { id: 'pro16-m5max-48-2048', family: 'pro', name: 'MacBook Pro 16" M5 Max', chip: 'M5 Max', screen_inches: 16.2, cpu_cores: 18, gpu_cores: 40, memory_gb: 48, storage_gb: 2048, price_pln: 25999, popularity: 20, is_active: true },
]
