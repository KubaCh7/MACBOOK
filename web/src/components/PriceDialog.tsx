import { useState } from 'react'
import { Dialog } from './Dialog'
import { useI18n } from '../lib/i18n'
import { useData } from '../lib/data'
import { money, parseAmount } from '../lib/format'
import { goalBalance } from '../lib/stats'
import { sound } from '../lib/sound'
import type { Goal } from '../lib/types'

/** Zmiana ceny w dwóch krokach: nowa cena → potwierdzenie „z X na Y”. */
export function PriceDialog({ goal, onClose }: { goal: Goal; onClose: () => void }) {
  const { t, lang } = useI18n()
  const { changePrice, deposits } = useData()
  const [step, setStep] = useState<1 | 2>(1)
  const [val, setVal] = useState('')
  const [err, setErr] = useState<string | null>(null)
  const next = parseAmount(val)
  const saved = goalBalance(deposits, goal.id)
  const diff = Math.round((next - goal.target_amount) * 100) / 100
  const left = Math.max(0, Math.round((next - saved) * 100) / 100)

  const go = (e: React.FormEvent) => {
    e.preventDefault()
    if (!Number.isFinite(next) || next <= 0) return setErr(t('amountInvalid'))
    sound.click()
    setStep(2)
  }

  return (
    <Dialog
      title={t('changePriceTitle')}
      onClose={onClose}
      footer={
        step === 1 ? (
          <>
            <button type="button" className="btn" onClick={onClose}>{t('cancel')}</button>
            <button type="submit" form="price-form" className="btn primary">{t('next')}</button>
          </>
        ) : (
          <>
            <button type="button" className="btn" onClick={() => setStep(1)}>{t('back')}</button>
            <button type="button" className="btn primary" onClick={async () => {
              try {
                await changePrice(goal.id, next)
                sound.click()
                onClose()
              } catch (ex) {
                setErr(t('error', { msg: (ex as Error).message }))
              }
            }}>{t('yesChange')}</button>
          </>
        )
      }
    >
      {step === 1 ? (
        <form id="price-form" className="form" onSubmit={go}>
          <p className="muted">{goal.name} · {t('price')} {money(goal.target_amount, lang)}</p>
          <label className="field">
            <span>{t('newPrice')}</span>
            <div className="amount-input">
              <input inputMode="decimal" value={val} onChange={(e) => { setVal(e.target.value); setErr(null) }} aria-invalid={!!err} aria-describedby="price-help" />
              <span className="suffix">zł</span>
            </div>
          </label>
          <p id="price-help" className={`help${err ? ' bad' : ''}`}>{err ?? ' '}</p>
        </form>
      ) : (
        <div className="form">
          <p className="confirm-line">{t('confirmPriceChange', { from: money(goal.target_amount, lang), to: money(next, lang) })}</p>
          <dl className="kv">
            <div><dt>{t('difference')}</dt><dd className="num">{money(diff, lang, { sign: true })}</dd></div>
            <div><dt>{t('saved')}</dt><dd className="num">{money(saved, lang)}</dd></div>
            <div><dt>{t('willBeLeft')}</dt><dd className="num strong">{money(left, lang)}</dd></div>
          </dl>
          {err && <p className="help bad">{err}</p>}
        </div>
      )}
    </Dialog>
  )
}
