import type { Lang } from './types'

const locale = (lang: Lang) => (lang === 'pl' ? 'pl-PL' : 'en-GB')

export function money(n: number, lang: Lang, opts: { sign?: boolean; decimals?: 'auto' | 0 | 2 } = {}): string {
  const dec = opts.decimals ?? 'auto'
  const frac = dec === 'auto' ? (Math.round(n * 100) % 100 === 0 ? 0 : 2) : dec
  const f = new Intl.NumberFormat(locale(lang), {
    minimumFractionDigits: frac,
    maximumFractionDigits: frac,
    useGrouping: 'always',
  } as Intl.NumberFormatOptions)
  const abs = f.format(Math.abs(n))
  const sign = n < 0 ? '−' : opts.sign && n > 0 ? '+' : ''
  return lang === 'pl' ? `${sign}${abs} zł` : `${sign}${abs} zł`
}

export function compactMoney(n: number, lang: Lang): string {
  if (Math.abs(n) >= 1000) {
    const v = n / 1000
    const s = new Intl.NumberFormat(locale(lang), { maximumFractionDigits: Math.abs(v) < 10 && v % 1 ? 1 : 0 }).format(v)
    return lang === 'pl' ? `${s} tys.` : `${s}k`
  }
  return new Intl.NumberFormat(locale(lang), { maximumFractionDigits: 0 }).format(n)
}

export function monthYear(d: Date, lang: Lang): string {
  return d.toLocaleDateString(locale(lang), { month: 'long', year: 'numeric' })
}

export function monthShort(d: Date, lang: Lang): string {
  const s = d.toLocaleDateString(locale(lang), { month: 'short' }).replace('.', '')
  return s
}

export function dayMonth(iso: string, lang: Lang): string {
  return parseDate(iso).toLocaleDateString(locale(lang), { day: 'numeric', month: 'short' }).replace('.', '')
}

export function fullDate(iso: string, lang: Lang): string {
  return parseDate(iso).toLocaleDateString(locale(lang), { day: 'numeric', month: 'long', year: 'numeric' })
}

export function parseDate(iso: string): Date {
  const [y, m, d] = iso.slice(0, 10).split('-').map(Number)
  return new Date(y, m - 1, d)
}

export function todayISO(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

/** liczebniki: 1 wpłata, 2 wpłaty, 5 wpłat */
export function plural(lang: Lang, n: number, forms: { pl: [string, string, string]; en: [string, string] }): string {
  if (lang === 'en') return `${n} ${n === 1 ? forms.en[0] : forms.en[1]}`
  const [one, few, many] = forms.pl
  if (n === 1) return `${n} ${one}`
  const m10 = n % 10
  const m100 = n % 100
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return `${n} ${few}`
  return `${n} ${many}`
}

export const W = {
  deposits: { pl: ['wpłata', 'wpłaty', 'wpłat'] as [string, string, string], en: ['deposit', 'deposits'] as [string, string] },
  withdrawals: { pl: ['wypłata', 'wypłaty', 'wypłat'] as [string, string, string], en: ['withdrawal', 'withdrawals'] as [string, string] },
  goals: { pl: ['cel', 'cele', 'celów'] as [string, string, string], en: ['goal', 'goals'] as [string, string] },
}

/** parsuje "1 234,50" / "1234.5" */
export function parseAmount(s: string): number {
  const clean = s.replace(/\s|zł|PLN/gi, '').replace(',', '.')
  const n = Number(clean)
  return Number.isFinite(n) ? Math.round(n * 100) / 100 : NaN
}
