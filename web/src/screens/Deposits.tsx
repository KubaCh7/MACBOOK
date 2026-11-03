import { useMemo, useState } from 'react'
import { useI18n } from '../lib/i18n'
import { useData } from '../lib/data'
import { activeDeposits, computeStats } from '../lib/stats'
import { dayMonth, money, monthYear, parseDate, plural, W } from '../lib/format'
import { MonthlyChart } from '../components/Charts'
import { DepositDialog } from '../components/DepositDialog'
import { Confirm } from '../components/Dialog'
import { PencilIcon, PlusIcon, TrashIcon } from '../components/Icons'
import { sound } from '../lib/sound'
import type { Deposit, Goal } from '../lib/types'

export function Deposits({ goal, onAddDeposit }: { goal: Goal; onAddDeposit: () => void }) {
  const { t, lang } = useI18n()
  const { deposits, deleteDeposit } = useData()
  const s = useMemo(() => computeStats(goal, deposits), [goal, deposits])
  const [edit, setEdit] = useState<Deposit | null>(null)
  const [del, setDel] = useState<Deposit | null>(null)
  const [err, setErr] = useState<string | null>(null)

  const groups = useMemo(() => {
    const list = activeDeposits(deposits, goal.id).reverse()
    const map = new Map<string, Deposit[]>()
    for (const d of list) {
      const k = d.deposit_date.slice(0, 7)
      map.set(k, [...(map.get(k) ?? []), d])
    }
    return [...map.entries()].map(([k, items]) => ({
      key: k,
      date: parseDate(`${k}-01`),
      items,
      net: Math.round(items.reduce((a, d) => a + d.amount, 0) * 100) / 100,
    }))
  }, [deposits, goal.id])

  return (
    <>
      <div className="title-row">
        <div>
          <h1>{t('navDeposits')}</h1>
          <p className="sub">
            {goal.name} · {plural(lang, s.depositCount, W.deposits)} · {plural(lang, s.withdrawalCount, W.withdrawals)}
          </p>
        </div>
        <button type="button" className="btn primary hide-phone" onClick={onAddDeposit}>
          <PlusIcon size={14} /> {t('addDeposit')}
        </button>
      </div>

      <div className="dep-grid">
        <section className="panel" aria-labelledby="h-monthly">
          <header>
            <h2 id="h-monthly">{t('monthly')}</h2>
            <span className="legend">
              <span className="key"><i className="sw-bar" />{t('depositsWord')}</span>
              {s.withdrawalCount > 0 && <span className="key"><i className="sw-bar neg" />{t('withdrawalsWord')}</span>}
            </span>
          </header>
          <MonthlyChart months={s.months} lang={lang} labels={{ deposits: t('depositsWord'), withdrawals: t('withdrawalsWord') }} />
        </section>

        <section className="panel summary-panel" aria-labelledby="h-summary">
          <header><h2 id="h-summary">{t('summary')}</h2></header>
          <dl className="kv">
            <div><dt>{t('saved')}</dt><dd className="num money strong">{money(s.saved, lang)}</dd></div>
            <div><dt>{t('totalIn')}</dt><dd className="num money">{money(s.totalIn, lang)}</dd></div>
            <div><dt>{t('totalOut')}</dt><dd className={`num money${s.totalOut ? ' neg' : ' zero'}`}>{money(s.totalOut, lang)}</dd></div>
            <div><dt>{t('avgDeposit')}</dt><dd className="num money">{s.depositCount ? money(s.avgDeposit, lang) : <span className="dash">—</span>}</dd></div>
            <div><dt>{t('depositCount')}</dt><dd className="num">{s.depositCount}</dd></div>
            <div><dt>{t('largest')}</dt><dd className="num money">{s.depositCount ? money(s.largest, lang) : <span className="dash">—</span>}</dd></div>
          </dl>
        </section>
        <section className="panel history-panel span-all" aria-labelledby="h-history">
          <header>
            <h2 id="h-history">{t('history')}</h2>
            <span className="meta">{plural(lang, s.depositCount + s.withdrawalCount, { pl: ['wpis', 'wpisy', 'wpisów'], en: ['entry', 'entries'] })}</span>
          </header>
          {err && <p className="help bad">{err}</p>}
          {groups.length ? (
            <table className="ledger">
              <thead>
                <tr>
                  <th scope="col">{t('date')}</th>
                  <th scope="col">{t('note')}</th>
                  <th scope="col" className="num">{t('amount')}</th>
                  <th scope="col"><span className="sr-only">{t('edit')}</span></th>
                </tr>
              </thead>
              {groups.map((g) => (
                <tbody key={g.key}>
                  <tr className="month-row">
                    <th scope="rowgroup" colSpan={2}>{monthYear(g.date, lang)}</th>
                    <td className="num">{money(g.net, lang, { sign: g.net > 0 })}</td>
                    <td />
                  </tr>
                  {g.items.map((d) => (
                    <tr key={d.id}>
                      <td className="date-cell">{dayMonth(d.deposit_date, lang)}</td>
                      <td className="note-cell">{d.note || <span className="muted">{d.amount < 0 ? t('withdrawal') : t('deposit')}</span>}</td>
                      <td className={`num money${d.amount < 0 ? ' neg' : ''}`}>{money(d.amount, lang, { sign: true })}</td>
                      <td className="actions">
                        <button type="button" className="icon-btn" aria-label={`${t('edit')} ${money(d.amount, lang)}`} onClick={() => setEdit(d)}><PencilIcon size={14} /></button>
                        <button type="button" className="icon-btn" aria-label={`${t('delete')} ${money(d.amount, lang)}`} onClick={() => setDel(d)}><TrashIcon size={14} /></button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              ))}
            </table>
          ) : (
            <div className="empty">
              <p>{t('noDeposits')}</p>
              <button type="button" className="btn primary" onClick={onAddDeposit}><PlusIcon size={14} /> {t('addDeposit')}</button>
            </div>
          )}
        </section>

      </div>

      {edit && <DepositDialog goalId={goal.id} existing={edit} onClose={() => setEdit(null)} />}
      {del && (
        <Confirm
          title={t('delete')}
          text={t('deleteDepositQ', { amount: money(del.amount, lang, { sign: true }), date: dayMonth(del.deposit_date, lang) })}
          confirmLabel={t('delete')}
          danger
          onClose={() => setDel(null)}
          onConfirm={async () => {
            try {
              await deleteDeposit(del.id)
              sound.remove()
              setErr(null)
            } catch (e) {
              const m = (e as Error).message
              setErr(m.includes('withdrawal_exceeds_balance') ? t('maxWithdraw', { max: money(s.saved, lang) }) : t('error', { msg: m }))
            }
          }}
        />
      )}
    </>
  )
}
