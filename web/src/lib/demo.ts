import type { Deposit, Goal, Profile } from './types'

/** Przykładowe dane dla podglądu (?demo). Zapisywane tylko lokalnie w tej przeglądarce. */
export function demoData(now = new Date()): { profile: Profile; goals: Goal[]; deposits: Deposit[] } {
  const iso = (y: number, m: number, d: number) => `${y}-${String(m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`
  const ts = new Date().toISOString()
  const goals: Goal[] = [
    { id: 'demo-air', name: 'MacBook Air 13" M5', target_amount: 5499, photo_url: null, photo_position: '50% 50%', catalog_id: 'air13-m5-16-512', is_default: true, created_at: ts, updated_at: ts, deleted_at: null },
    { id: 'demo-monitor', name: 'Monitor 27" 4K', target_amount: 1600, photo_url: null, photo_position: '50% 50%', catalog_id: null, is_default: false, created_at: ts, updated_at: ts, deleted_at: null },
  ]
  // [miesiące wstecz, dzień, kwota, notatka]
  const plan: [number, number, number, string][] = [
    [6, 2, 400, 'Start'], [6, 20, 150, 'Kieszonkowe'],
    [5, 1, 500, 'Wypłata z pracy'], [5, 15, 100, ''],
    [4, 3, 500, 'Wypłata z pracy'], [4, 22, -200, 'Bilet na koncert'],
    [3, 1, 600, 'Wypłata z pracy'], [3, 18, 200, 'Sprzedaż gry'],
    [2, 2, 500, 'Wypłata z pracy'], [2, 28, 50, ''],
    [1, 1, 600, 'Wypłata z pracy'], [1, 12, 200, 'Urodziny'],
    [0, 1, 500, 'Wypłata z pracy'],
  ]
  const deposits: Deposit[] = plan.map(([back, day, amount, note], i) => {
    const d = new Date(now.getFullYear(), now.getMonth() - back, 1)
    const dd = Math.min(day, back === 0 ? Math.max(1, now.getDate()) : 28)
    return { id: `demo-${i}`, goal_id: 'demo-air', amount, deposit_date: iso(d.getFullYear(), d.getMonth(), dd), note: note || null, created_at: ts, updated_at: ts, deleted_at: null }
  })
  deposits.push({ id: 'demo-m1', goal_id: 'demo-monitor', amount: 300, deposit_date: iso(now.getFullYear(), now.getMonth(), 1), note: null, created_at: ts, updated_at: ts, deleted_at: null })
  return { profile: { display_name: 'Kuba', onboarded: true }, goals, deposits }
}
