# Supabase — macbook progress

Projekt: `macbook-progress` (region eu-central-1). Migracje w `migrations/` są już zastosowane.

| Tabela | Co trzyma |
| --- | --- |
| `profiles` | imię (`display_name`), `onboarded` — tworzony automatycznie przy rejestracji |
| `goals` | cele: nazwa, cena (`target_amount`), zdjęcie (`photo_url`, `photo_position` „x% y%”), `catalog_id`, `is_default`, `deleted_at` |
| `deposits` | wpłaty (+) i wypłaty (−): `amount <> 0`, `deposit_date`, `note`, `deleted_at` |
| `macbook_catalog` | podpowiedzi modeli z cenami w PLN, `popularity`, `is_active` |
| `app_config` | np. `ios_update.latest_build` — baner „Dostępna nowa wersja” |

- RLS na wszystkim; każdy widzi tylko swoje dane. Usuwanie jest miękkie (`deleted_at`).
- Wypłata nie może przekroczyć salda celu (trigger `deposits_balance_check`).
- RPC: `set_default_goal(p_goal_id)`, `delete_account()`.
- Storage: prywatny bucket `goal-photos`, ścieżka `<user_id>/<goal_id>.jpg`.
- Realtime: wszystkie tabele.

Nowa wersja iOS: `update app_config set value = jsonb_set(value, '{latest_build}', '2') where key = 'ios_update';`
oraz `APP_BUILD = 2` w `ios/Config/Base.xcconfig`.
