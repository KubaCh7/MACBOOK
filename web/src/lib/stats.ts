import type { Deposit, Goal } from './types'
import { parseDate } from './format'

export interface MonthPoint {
  key: string // YYYY-MM
  date: Date // pierwszy dzień miesiąca
  inflow: number // suma wpłat
  outflow: number // suma wypłat (ujemna)
  net: number
  cumulative: number // stan na koniec miesiąca
}

export interface GoalStats {
  saved: number
  target: number
  left: number
  ratio: number // 0..1
  thisMonth: number // netto w bieżącym miesiącu
  pace: number // średnio netto na miesiąc od pierwszej wpłaty
  avgDeposit: number // tylko wpłaty
  depositCount: number // tylko wpłaty
  withdrawalCount: number
  totalIn: number
  totalOut: number
  largest: number
  forecast: Date | null // miesiąc zakupu
  monthsToGo: number | null
  months: MonthPoint[] // od pierwszej wpłaty do bieżącego miesiąca
}

const r2 = (n: number) => Math.round(n * 100) / 100
export const monthKey = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
export const addMonths = (d: Date, n: number) => new Date(d.getFullYear(), d.getMonth() + n, 1)

export function activeDeposits(deposits: Deposit[], goalId: string): Deposit[] {
  return deposits
    .filter((d) => d.goal_id === goalId && !d.deleted_at)
    .sort((a, b) => (a.deposit_date === b.deposit_date ? a.created_at.localeCompare(b.created_at) : a.deposit_date.localeCompare(b.deposit_date)))
}

export function goalBalance(deposits: Deposit[], goalId: string, excludeId?: string): number {
  return r2(deposits.filter((d) => d.goal_id === goalId && !d.deleted_at && d.id !== excludeId).reduce((s, d) => s + d.amount, 0))
}

export function computeStats(goal: Goal, all: Deposit[], now = new Date()): GoalStats {
  const ds = activeDeposits(all, goal.id)
  const target = goal.target_amount
  const saved = r2(ds.reduce((s, d) => s + d.amount, 0))
  const left = r2(Math.max(0, target - saved))
  const ins = ds.filter((d) => d.amount > 0)
  const outs = ds.filter((d) => d.amount < 0)
  const totalIn = r2(ins.reduce((s, d) => s + d.amount, 0))
  const totalOut = r2(outs.reduce((s, d) => s + d.amount, 0))
  const curKey = monthKey(now)
  const thisMonth = r2(ds.filter((d) => d.deposit_date.slice(0, 7) === curKey).reduce((s, d) => s + d.amount, 0))

  const months: MonthPoint[] = []
  if (ds.length) {
    const first = parseDate(ds[0].deposit_date)
    let m = new Date(first.getFullYear(), first.getMonth(), 1)
    const end = new Date(now.getFullYear(), now.getMonth(), 1)
    const lastDeposit = parseDate(ds[ds.length - 1].deposit_date)
    const endAll = lastDeposit > end ? new Date(lastDeposit.getFullYear(), lastDeposit.getMonth(), 1) : end
    let cum = 0
    while (m <= endAll) {
      const key = monthKey(m)
      const inM = ds.filter((d) => d.deposit_date.slice(0, 7) === key)
      const inflow = r2(inM.filter((d) => d.amount > 0).reduce((s, d) => s + d.amount, 0))
      const outflow = r2(inM.filter((d) => d.amount < 0).reduce((s, d) => s + d.amount, 0))
      cum = r2(cum + inflow + outflow)
      months.push({ key, date: m, inflow, outflow, net: r2(inflow + outflow), cumulative: cum })
      m = addMonths(m, 1)
    }
  }

  // tempo: oszczędności netto podzielone przez liczbę miesięcy od pierwszej wpłaty (z bieżącym)
  const span = months.filter((p) => p.date <= now).length || 1
  const pace = ds.length ? r2(saved / span) : 0

  let forecast: Date | null = null
  let monthsToGo: number | null = null
  if (left === 0 && ds.length) {
    forecast = new Date(now.getFullYear(), now.getMonth(), 1)
    monthsToGo = 0
  } else if (pace > 0) {
    monthsToGo = Math.ceil(left / pace)
    forecast = addMonths(now, monthsToGo)
  }

  return {
    saved,
    target,
    left,
    ratio: target > 0 ? Math.min(1, Math.max(0, saved / target)) : 0,
    thisMonth,
    pace,
    avgDeposit: ins.length ? r2(totalIn / ins.length) : 0,
    depositCount: ins.length,
    withdrawalCount: outs.length,
    totalIn,
    totalOut,
    largest: ins.length ? Math.max(...ins.map((d) => d.amount)) : 0,
    forecast,
    monthsToGo,
    months,
  }
}
