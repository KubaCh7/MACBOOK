import { useEffect, useLayoutEffect, useMemo, useRef, useState, type PointerEvent as RPointerEvent } from 'react'
import type { MonthPoint } from '../lib/stats'
import { addMonths, monthKey } from '../lib/stats'
import { compactMoney, money, monthShort, monthYear } from '../lib/format'
import type { Lang } from '../lib/types'

function useWidth<T extends HTMLElement>() {
  const ref = useRef<T>(null)
  const [w, setW] = useState(0)
  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    setW(el.clientWidth)
    const ro = new ResizeObserver(() => setW(el.clientWidth))
    ro.observe(el)
    return () => ro.disconnect()
  }, [])
  return [ref, w] as const
}

function niceStep(range: number, count: number) {
  const raw = range / count
  const mag = Math.pow(10, Math.floor(Math.log10(raw || 1)))
  const n = raw / mag
  const s = n <= 1 ? 1 : n <= 2 ? 2 : n <= 2.5 ? 2.5 : n <= 5 ? 5 : 10
  return s * mag
}

/** ticki od 0 do wartości powyżej max (max nigdy nie dotyka krawędzi) */
function ticksUp(max: number, count = 4) {
  if (max <= 0) return [0, 100, 200, 300, 400]
  const step = niceStep(max * 1.08, count)
  const out: number[] = []
  for (let v = 0; v <= max * 1.08 + step * 0.999; v += step) out.push(Math.round(v * 100) / 100)
  if (out[out.length - 1] <= max * 1.04) out.push(out[out.length - 1] + step)
  return out
}

// wspólne marginesy: górny pas na podpowiedź, dolny pas na miesiące — nigdy się nie nakładają
const TIP_BAND = 30
const X_BAND = 24

interface Tip {
  x: number
  title: string
  lines: { label: string; value: string; tone?: 'data' | 'neg' | 'muted' }[]
}

function Tooltip({ tip, width }: { tip: Tip | null; width: number }) {
  const ref = useRef<HTMLDivElement>(null)
  const [w, setW] = useState(0)
  useLayoutEffect(() => {
    if (ref.current) setW(ref.current.offsetWidth)
  }, [tip?.title, tip?.lines.length])
  if (!tip) return null
  const left = Math.max(0, Math.min(width - w, tip.x - w / 2))
  return (
    <div className="chart-tip" ref={ref} style={{ left }} role="status">
      <span className="tip-title">{tip.title}</span>
      {tip.lines.map((l) => (
        <span key={l.label} className={`tip-val ${l.tone ?? ''}`}>
          {l.label && <span className="tip-label">{l.label}</span>} {l.value}
        </span>
      ))}
    </div>
  )
}

function usePointerIndex(xs: number[], enabled: boolean) {
  const [idx, setIdx] = useState<number | null>(null)
  const pick = (e: RPointerEvent<SVGSVGElement>) => {
    if (!enabled || !xs.length) return
    const r = e.currentTarget.getBoundingClientRect()
    const x = e.clientX - r.left
    let best = 0
    for (let i = 1; i < xs.length; i++) if (Math.abs(xs[i] - x) < Math.abs(xs[best] - x)) best = i
    setIdx(best)
  }
  const handlers = {
    onPointerMove: pick,
    onPointerDown: pick,
    onPointerLeave: (e: RPointerEvent<SVGSVGElement>) => {
      if (e.pointerType === 'mouse') setIdx(null)
    },
  }
  return [idx, setIdx, handlers] as const
}

// ───────────────────────── narastająco + prognoza ─────────────────────────

export function CumulativeChart({ months, target, pace, lang, labels, height = 272, now = new Date() }: {
  months: MonthPoint[]
  target: number
  pace: number
  lang: Lang
  labels: { forecast: string; price: string; saved: string }
  height?: number
  now?: Date
}) {
  const [ref, width] = useWidth<HTMLDivElement>()
  const phone = width < 480

  const model = useMemo(() => {
    const cur = new Date(now.getFullYear(), now.getMonth(), 1)
    const actual: { d: Date; v: number }[] = []
    if (months.length) {
      actual.push({ d: addMonths(months[0].date, -1), v: 0 })
      for (const m of months) actual.push({ d: m.date, v: m.cumulative })
    }
    const last = actual[actual.length - 1]
    const forecast: { d: Date; v: number }[] = []
    if (last && pace > 0 && last.v < target) {
      const need = Math.ceil((target - last.v) / pace)
      const shown = Math.min(need, 36)
      const start = last.d < cur ? cur : last.d
      forecast.push({ d: last.d, v: last.v })
      for (let i = 1; i <= shown; i++) forecast.push({ d: addMonths(start, i), v: Math.min(target, last.v + pace * i) })
    }
    const all = [...actual, ...forecast.slice(1)]
    if (!all.length) {
      for (let i = -2; i <= 3; i++) all.push({ d: addMonths(cur, i), v: NaN })
    }
    return { actual, forecast, all }
  }, [months, target, pace, now])

  const padL = 56
  const padR = 8
  const plotTop = TIP_BAND
  const plotBottom = height - X_BAND
  const maxV = Math.max(target, ...model.actual.map((p) => p.v), 0)
  const ticks = ticksUp(maxV, phone ? 3 : 4)
  const top = ticks[ticks.length - 1]
  const n = model.all.length
  const x = (i: number) => padL + (n <= 1 ? (width - padL - padR) / 2 : (i * (width - padL - padR)) / (n - 1))
  const y = (v: number) => plotBottom - (v / top) * (plotBottom - plotTop)
  const idxOf = (d: Date) => model.all.findIndex((p) => monthKey(p.d) === monthKey(d))
  const xs = model.all.map((_, i) => x(i))

  const hasData = model.actual.length > 0
  const [idx, setIdx, handlers] = usePointerIndex(xs, hasData)
  useEffect(() => setIdx(null), [months, setIdx])

  const actualPath = model.actual.map((p, i) => `${i ? 'L' : 'M'}${x(idxOf(p.d)).toFixed(1)},${y(p.v).toFixed(1)}`).join(' ')
  const forecastPath = model.forecast.map((p, i) => `${i ? 'L' : 'M'}${x(idxOf(p.d)).toFixed(1)},${y(p.v).toFixed(1)}`).join(' ')

  // podpisy osi X: krok tak, by było 4–7 etykiet
  const maxLabels = phone ? 4 : 7
  const step = Math.max(1, Math.ceil(n / maxLabels))
  const xLabels = model.all.map((p, i) => ({ i, p })).filter(({ i }) => i % step === 0)

  let tip: Tip | null = null
  if (idx != null && hasData) {
    const p = model.all[idx]
    const isForecast = idx >= model.actual.length
    tip = {
      x: xs[idx],
      title: monthYear(p.d, lang),
      lines: [{ label: isForecast ? labels.forecast : labels.saved, value: money(p.v, lang, { decimals: isForecast ? 0 : 'auto' }), tone: isForecast ? 'muted' : 'data' }],
    }
  }

  const priceLabel = `${labels.price} ${money(target, lang)}`

  return (
    <div className="chart" ref={ref} style={{ height }}>
      <Tooltip tip={tip} width={width} />
      <svg width={width} height={height} {...handlers} style={{ touchAction: 'pan-y' }} role="img"
        aria-label={`${labels.saved}: ${hasData ? money(model.actual[model.actual.length - 1].v, lang) : money(0, lang)} · ${priceLabel}`}>
        {ticks.map((tv) => (
          <g key={tv}>
            <line x1={padL} x2={width - padR} y1={y(tv)} y2={y(tv)} className={tv === 0 ? 'baseline' : 'grid'} />
            <text x={padL - 8} y={y(tv) + 4} textAnchor="end" className="tick">{compactMoney(tv, lang)}</text>
          </g>
        ))}
        {/* linia ceny */}
        <line x1={padL} x2={width - padR} y1={y(target)} y2={y(target)} className="ref-line" />
        <text x={width - padR} y={y(target) - 6} textAnchor="end" className="ref-label">{priceLabel}</text>
        {forecastPath && <path d={forecastPath} className="line-forecast" />}
        {actualPath && <path d={actualPath} className="line-data" />}
        {model.actual.length === 1 && <circle cx={x(0)} cy={y(model.actual[0].v)} r={3} className="dot-data" />}
        {idx != null && hasData && (
          <g>
            <line x1={xs[idx]} x2={xs[idx]} y1={plotTop} y2={plotBottom} className="guide" />
            {Number.isFinite(model.all[idx].v) && <circle cx={xs[idx]} cy={y(model.all[idx].v)} r={4} className={idx >= model.actual.length ? 'dot-forecast' : 'dot-data'} />}
          </g>
        )}
        {xLabels.map(({ i, p }) => {
          const anchor = i === 0 && xs[i] - padL < 20 ? 'start' : i === n - 1 && width - padR - xs[i] < 20 ? 'end' : 'middle'
          const jan = p.d.getMonth() === 0 || i === 0
          return (
            <text key={i} x={xs[i]} y={height - 6} textAnchor={anchor} className="tick">
              {monthShort(p.d, lang)}{jan ? ` ${String(p.d.getFullYear()).slice(2)}` : ''}
            </text>
          )
        })}
      </svg>
    </div>
  )
}

// ───────────────────────── miesięcznie: wpłaty w górę, wypłaty w dół ─────────────────────────

export function MonthlyChart({ months, lang, labels, height = 220, now = new Date() }: {
  months: MonthPoint[]
  lang: Lang
  labels: { deposits: string; withdrawals: string }
  height?: number
  now?: Date
}) {
  const [ref, width] = useWidth<HTMLDivElement>()
  const phone = width < 480
  const count = phone ? 6 : 12
  const cur = new Date(now.getFullYear(), now.getMonth(), 1)
  const byKey = new Map(months.map((m) => [m.key, m]))
  const lastMonth = months.length ? months[months.length - 1].date : cur
  const end = lastMonth > cur ? lastMonth : cur
  const series: MonthPoint[] = []
  for (let i = count - 1; i >= 0; i--) {
    const d = addMonths(end, -i)
    series.push(byKey.get(monthKey(d)) ?? { key: monthKey(d), date: d, inflow: 0, outflow: 0, net: 0, cumulative: 0 })
  }
  const maxUp = Math.max(0, ...series.map((m) => m.inflow))
  const maxDown = Math.max(0, ...series.map((m) => -m.outflow))
  const padL = 56
  const padR = 8
  const plotTop = TIP_BAND
  const plotBottom = height - X_BAND
  const upTicks = ticksUp(maxUp || 100, maxDown ? 3 : 4)
  const step = upTicks[1] - upTicks[0]
  const downTicks: number[] = []
  if (maxDown > 0) for (let v = -step; v >= -(maxDown * 1.04 + step * 0.999); v -= step) downTicks.push(v)
  if (maxDown > 0 && -downTicks[downTicks.length - 1] <= maxDown * 1.02) downTicks.push(downTicks[downTicks.length - 1] - step)
  const topV = upTicks[upTicks.length - 1]
  const botV = downTicks.length ? downTicks[downTicks.length - 1] : 0
  const y = (v: number) => plotTop + ((topV - v) / (topV - botV)) * (plotBottom - plotTop)
  const band = Math.max(1, (width - padL - padR) / series.length)
  const barW = Math.min(28, band * 0.56)
  const xs = series.map((_, i) => padL + band * i + band / 2)
  const [idx, , handlers] = usePointerIndex(xs, true)

  let tip: Tip | null = null
  if (idx != null) {
    const m = series[idx]
    const lines: Tip['lines'] = [{ label: labels.deposits, value: money(m.inflow, lang, { sign: m.inflow > 0 }), tone: 'data' }]
    if (m.outflow) lines.push({ label: labels.withdrawals, value: money(m.outflow, lang), tone: 'neg' })
    tip = { x: xs[idx], title: monthYear(m.date, lang), lines }
  }

  const labelStep = phone ? 1 : series.length > 8 ? 1 : 1
  return (
    <div className="chart" ref={ref} style={{ height }}>
      <Tooltip tip={tip} width={width} />
      <svg width={width} height={height} {...handlers} style={{ touchAction: 'pan-y' }} role="img" aria-label={labels.deposits}>
        {[...upTicks, ...downTicks].map((tv) => (
          <g key={tv}>
            <line x1={padL} x2={width - padR} y1={y(tv)} y2={y(tv)} className={tv === 0 ? 'baseline' : 'grid'} />
            <text x={padL - 8} y={y(tv) + 4} textAnchor="end" className="tick">{tv < 0 ? '−' : ''}{compactMoney(Math.abs(tv), lang)}</text>
          </g>
        ))}
        {idx != null && <rect x={xs[idx] - band / 2 + 2} y={plotTop} width={Math.max(0, band - 4)} height={plotBottom - plotTop} className="hover-band" />}
        {series.map((m, i) => (
          <g key={m.key}>
            {m.inflow > 0 && <rect x={xs[i] - barW / 2} y={y(m.inflow)} width={barW} height={Math.max(1, y(0) - y(m.inflow))} className="bar-up" />}
            {m.outflow < 0 && <rect x={xs[i] - barW / 2} y={y(0) + 1} width={barW} height={Math.max(1, y(m.outflow) - y(0) - 1)} className="bar-down" />}
          </g>
        ))}
        {series.map((m, i) =>
          i % labelStep === 0 ? (
            <text key={m.key} x={xs[i]} y={height - 6} textAnchor="middle" className="tick">
              {monthShort(m.date, lang)}
            </text>
          ) : null,
        )}
      </svg>
    </div>
  )
}
