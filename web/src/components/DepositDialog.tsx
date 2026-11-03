import { useState } from 'react'
import { Dialog } from './Dialog'
import { useI18n } from '../lib/i18n'
import { useData } from '../lib/data'
import { money, parseAmount, todayISO } from '../lib/format'
import { goalBalance } from '../lib/stats'
import { sound } from '../lib/sound'
import type { Deposit } from '../lib/types'

const QUICK = [50, 100, 200, 500]

export function DepositDialog({ goalId, existing, onClose }: { goalId: string; existing?: Deposit; onClose: () => void }) {
  const { t, lang } = useI18n()
  const { saveDeposit, deposits } = useData()
  const [kind, setKind] = useState<'in' | 'out'>(existing && existing.amount < 0 ? 'out' : 'in')
  const [amount, setAmount] = useState(existing ? String(Math.abs(existing.amount)).replace('.', lang === 'pl' ? ',' : '.') : '')
  const [date, setDate] = useState(existing?.deposit_date ?? todayISO())
  const [note, setNote] = useState(existing?.note ?? '')
  const [err, setErr] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const gid = existing?.goal_id ?? goalId
  const available = goalBalance(deposits, gid, existing?.id)

  const value = parseAmount(amount)
  const tooMuch = kind === 'out' && value > available + 0.001

  const add = (n: number) => {
    sound.click()
    const cur = parseAmount(amount)
    const next = (Number.isFinite(cur) ? cur : 0) + n
    setAmount(String(next).replace('.', lang === 'pl' ? ',' : '.'))
    setErr(null)
  }

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!Number.isFinite(value) || value <= 0) return setErr(t('amountInvalid'))
    if (tooMuch) return setErr(t('maxWithdraw', { max: money(available, lang) }))
    setBusy(true)
    try {
      await saveDeposit({ id: existing?.id, goal_id: gid, amount: kind === 'out' ? -value : value, deposit_date: date, note: note.trim() || null })
      if (kind === 'out') sound.withdraw()
      else sound.coin()
      onClose()
    } catch (ex) {
      const m = (ex as Error).message
      setErr(m.includes('withdrawal_exceeds_balance') ? t('maxWithdraw', { max: money(available, lang) }) : t('error', { msg: m }))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog
      title={existing ? t('editDeposit') : t('newDeposit')}
      onClose={onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={onClose}>{t('cancel')}</button>
          <button type="submit" form="deposit-form" className="btn primary" disabled={busy}>{t('save')}</button>
        </>
      }
    >
      <form id="deposit-form" className="form" onSubmit={submit}>
        <div className="segmented full" role="radiogroup" aria-label={t('amount')}>
          {(['in', 'out'] as const).map((k) => (
            <button key={k} type="button" role="radio" aria-checked={kind === k} className={kind === k ? 'on' : ''}
              onClick={() => { sound.tab(); setKind(k); setErr(null) }}>
              {k === 'in' ? t('deposit') : t('withdrawal')}
            </button>
          ))}
        </div>
        <label className="field">
          <span>{t('amount')}</span>
          <div className="amount-input">
            <input inputMode="decimal" autoComplete="off" value={amount} onChange={(e) => { setAmount(e.target.value); setErr(null) }}
              aria-describedby="amount-help" aria-invalid={!!err || tooMuch} placeholder="0" />
            <span className="suffix">zł</span>
          </div>
        </label>
        <div className="quick" aria-label="+">
          {QUICK.map((n) => (
            <button key={n} type="button" className="btn" onClick={() => add(n)}>+{n} zł</button>
          ))}
        </div>
        <p id="amount-help" className={`help${err || tooMuch ? ' bad' : ''}`}>
          {err ?? (kind === 'out' ? t('maxWithdraw', { max: money(available, lang) }) : ' ')}
        </p>
        <label className="field">
          <span>{t('date')}</span>
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} required />
        </label>
        <label className="field">
          <span>{t('note')}</span>
          <input value={note} maxLength={200} onChange={(e) => setNote(e.target.value)} />
        </label>
      </form>
    </Dialog>
  )
}
