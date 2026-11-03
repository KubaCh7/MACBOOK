-- Katalog podpowiedzi: orientacyjne ceny z polskiego Apple Store (listopad 2026).
-- Ceny to punkt startowy — użytkownik zawsze może je zmienić przy celu.
insert into public.macbook_catalog
  (id, family, name, chip, screen_inches, cpu_cores, gpu_cores, memory_gb, storage_gb, price_pln, popularity, is_active)
values
  ('air13-m5-16-512',   'air', 'MacBook Air 13" M5',      'M5',        13.6, 10, 8,  16,  512,  5499, 100, true),
  ('neo13-a18-8-256',   'neo', 'MacBook Neo 13"',         'A18 Pro',   13.0, 6,  5,  8,   256,  2999, 95,  true),
  ('air15-m5-16-512',   'air', 'MacBook Air 15" M5',      'M5',        15.3, 10, 10, 16,  512,  6499, 90,  true),
  ('pro14-m5-16-512',   'pro', 'MacBook Pro 14" M5',      'M5',        14.2, 10, 10, 16,  512,  7999, 85,  true),
  ('air13-m5-24-1024',  'air', 'MacBook Air 13" M5',      'M5',        13.6, 10, 10, 24,  1024, 7499, 75,  true),
  ('neo13-a18-8-512',   'neo', 'MacBook Neo 13" Touch ID','A18 Pro',   13.0, 6,  5,  8,   512,  3499, 70,  true),
  ('pro14-m5-16-1024',  'pro', 'MacBook Pro 14" M5',      'M5',        14.2, 10, 10, 16,  1024, 8999, 65,  true),
  ('air15-m5-24-1024',  'air', 'MacBook Air 15" M5',      'M5',        15.3, 10, 10, 24,  1024, 8499, 60,  true),
  ('pro14-m5-24-1024',  'pro', 'MacBook Pro 14" M5',      'M5',        14.2, 10, 10, 24,  1024, 9999, 55,  true),
  ('pro14-m5pro-24-1024','pro','MacBook Pro 14" M5 Pro',  'M5 Pro',    14.2, 15, 16, 24,  1024, 14999, 50, true),
  ('pro16-m5pro-24-1024','pro','MacBook Pro 16" M5 Pro',  'M5 Pro',    16.2, 18, 20, 24,  1024, 17999, 45, true),
  ('air13-m5-32-1024',  'air', 'MacBook Air 13" M5',      'M5',        13.6, 10, 10, 32,  1024, 8499, 40,  true),
  ('air15-m5-32-1024',  'air', 'MacBook Air 15" M5',      'M5',        15.3, 10, 10, 32,  1024, 9499, 35,  true),
  ('pro14-m5max-36-2048','pro','MacBook Pro 14" M5 Max',  'M5 Max',    14.2, 18, 32, 36,  2048, 23499, 30, true),
  ('pro16-m5max-36-2048','pro','MacBook Pro 16" M5 Max',  'M5 Max',    16.2, 18, 32, 36,  2048, 24999, 25, true),
  ('pro16-m5max-48-2048','pro','MacBook Pro 16" M5 Max',  'M5 Max',    16.2, 18, 40, 48,  2048, 25999, 20, true),
  ('air13-m4-16-256',   'air', 'MacBook Air 13" M4',      'M4',        13.6, 10, 8,  16,  256,  4999, 10,  false)
on conflict (id) do update set
  name = excluded.name, chip = excluded.chip, price_pln = excluded.price_pln,
  popularity = excluded.popularity, is_active = excluded.is_active,
  memory_gb = excluded.memory_gb, storage_gb = excluded.storage_gb,
  cpu_cores = excluded.cpu_cores, gpu_cores = excluded.gpu_cores;

insert into public.app_config (key, value) values
  ('ios_update', '{"latest_build": 1, "notes_pl": "Pierwsza wersja.", "notes_en": "First version."}'),
  ('catalog', '{"updated": "2026-11-03", "source": "apple.com/pl (orientacyjnie)"}')
on conflict (key) do update set value = excluded.value;
