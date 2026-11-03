import { useEffect, useState } from 'react'
import { Dialog, Confirm } from './Dialog'
import { CatalogPicker } from './CatalogPicker'
import { PhotoBox } from './PhotoBox'
import { PriceDialog } from './PriceDialog'
import { useI18n } from '../lib/i18n'
import { useData } from '../lib/data'
import { money, parseAmount } from '../lib/format'
import { sound } from '../lib/sound'
import type { CatalogItem, Goal } from '../lib/types'
import { StarIcon } from './Icons'

interface Draft {
  name: string
  price: string
  catalog_id: string | null
  file: Blob | null
  link: string | null
  preview: string | null
  pos: string
}

const emptyDraft: Draft = { name: '', price: '', catalog_id: null, file: null, link: null, preview: null, pos: '50% 50%' }

/** Krok 1: wybór z katalogu albo własny cel; krok 2: nazwa, cena, zdjęcie. */
export function NewGoalFlow({ onDone, onCancel, submitLabel, inline }: { onDone: () => void; onCancel?: () => void; submitLabel: string; inline?: boolean }) {
  const { t, lang } = useI18n()
  const { catalog, createGoal } = useData()
  const [step, setStep] = useState<'pick' | 'form'>('pick')
  const [d, setD] = useState<Draft>(emptyDraft)
  const [err, setErr] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  useEffect(() => () => { if (d.preview?.startsWith('blob:')) URL.revokeObjectURL(d.preview) }, [d.preview])

  const pick = (c: CatalogItem | null) => {
    setD(c ? { ...emptyDraft, name: c.name, price: String(c.price_pln), catalog_id: c.id } : emptyDraft)
    setStep('form')
  }

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    const price = parseAmount(d.price)
    if (!d.name.trim()) return setErr(t('goalName'))
    if (!Number.isFinite(price) || price <= 0) return setErr(t('amountInvalid'))
    setBusy(true)
    try {
      await createGoal({ name: d.name, target_amount: price, catalog_id: d.catalog_id, photoFile: d.file, photoLink: d.link, photo_position: d.pos })
      sound.chord()
      onDone()
    } catch (ex) {
      setErr(t('error', { msg: (ex as Error).message }))
    } finally {
      setBusy(false)
    }
  }

  if (step === 'pick') {
    return (
      <div className="flow">
        <CatalogPicker items={catalog} onPick={pick} />
        <div className={inline ? 'flow-actions' : 'flow-actions'}>
          {onCancel && <button type="button" className="btn" onClick={onCancel}>{t('cancel')}</button>}
          <button type="button" className="btn" onClick={() => pick(null)}>{t('customGoal')}</button>
        </div>
      </div>
    )
  }

  return (
    <form className="form flow" onSubmit={submit}>
      <label className="field">
        <span>{t('goalName')}</span>
        <input value={d.name} maxLength={120} onChange={(e) => setD({ ...d, name: e.target.value })} required />
      </label>
      <label className="field">
        <span>{t('goalPrice')}</span>
        <div className="amount-input">
          <input inputMode="decimal" value={d.price} onChange={(e) => { setD({ ...d, price: e.target.value }); setErr(null) }} required aria-describedby="goal-help" />
          <span className="suffix">zł</span>
        </div>
      </label>
      <div className="field">
        <span>{t('photo')}</span>
        <PhotoBox
          compact
          src={d.preview}
          position={d.pos}
          alt={d.name}
          onFile={(f) => setD({ ...d, file: f, link: null, preview: URL.createObjectURL(f), pos: '50% 50%' })}
          onLink={(u) => setD({ ...d, file: null, link: u, preview: u, pos: '50% 50%' })}
          onRemove={() => setD({ ...d, file: null, link: null, preview: null })}
          onPosition={(p) => setD((x) => ({ ...x, pos: p }))}
        />
      </div>
      <p id="goal-help" className={`help${err ? ' bad' : ''}`}>{err ?? (d.catalog_id ? t('priceNote') : ' ')}</p>
      <div className="flow-actions">
        <button type="button" className="btn" onClick={() => setStep('pick')}>{t('back')}</button>
        <button type="submit" className="btn primary" disabled={busy}>{submitLabel}</button>
      </div>
      {d.price && Number.isFinite(parseAmount(d.price)) && <span className="sr-only">{money(parseAmount(d.price), lang)}</span>}
    </form>
  )
}

export function NewGoalDialog({ onClose }: { onClose: () => void }) {
  const { t } = useI18n()
  return (
    <Dialog title={t('newGoal')} onClose={onClose} wide>
      <NewGoalFlow onDone={onClose} onCancel={onClose} submitLabel={t('addGoal')} />
    </Dialog>
  )
}

export function EditGoalDialog({ goal, onClose }: { goal: Goal; onClose: () => void }) {
  const { t, lang } = useI18n()
  const { updateGoal, setDefaultGoal, deleteGoal, photoSrc, setPhotoPosition } = useData()
  const [name, setName] = useState(goal.name)
  const [err, setErr] = useState<string | null>(null)
  const [price, setPrice] = useState(false)
  const [del, setDel] = useState(false)
  const [busy, setBusy] = useState(false)

  const run = async (fn: () => Promise<void>) => {
    setBusy(true)
    setErr(null)
    try {
      await fn()
    } catch (ex) {
      setErr(t('error', { msg: (ex as Error).message }))
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      <Dialog
        title={t('editGoal')}
        onClose={onClose}
        wide
        footer={
          <>
            <button type="button" className="btn danger-text" onClick={() => setDel(true)}>{t('deleteGoal')}</button>
            <span className="spacer" />
            <button type="button" className="btn" onClick={onClose}>{t('cancel')}</button>
            <button type="submit" form="edit-goal" className="btn primary" disabled={busy}>{t('save')}</button>
          </>
        }
      >
        <form id="edit-goal" className="form" onSubmit={(e) => { e.preventDefault(); void run(async () => { await updateGoal(goal.id, { name }); onClose() }) }}>
          <label className="field">
            <span>{t('goalName')}</span>
            <input value={name} maxLength={120} onChange={(e) => setName(e.target.value)} required />
          </label>
          <div className="field">
            <span>{t('price')}</span>
            <div className="price-row">
              <strong className="num money">{money(goal.target_amount, lang)}</strong>
              <button type="button" className="btn" onClick={() => setPrice(true)}>{t('changePrice')}</button>
            </div>
          </div>
          <div className="field">
            <span>{t('photo')}</span>
            <PhotoBox
              src={photoSrc(goal)}
              position={goal.photo_position}
              alt={goal.name}
              onFile={(f) => void run(() => updateGoal(goal.id, { photoFile: f, photo_position: '50% 50%' }))}
              onLink={(u) => void run(() => updateGoal(goal.id, { photoLink: u, photo_position: '50% 50%' }))}
              onRemove={() => void run(() => updateGoal(goal.id, { removePhoto: true }))}
              onPosition={(p) => void run(() => setPhotoPosition(goal.id, p))}
            />
          </div>
          <div className="field">
            <span>{t('main')}</span>
            <button type="button" className="btn fit" disabled={goal.is_default || busy} onClick={() => void run(async () => { await setDefaultGoal(goal.id); sound.click() })}>
              <StarIcon size={14} filled={goal.is_default} /> {goal.is_default ? t('main') : t('setMain')}
            </button>
          </div>
          {err && <p className="help bad">{err}</p>}
        </form>
      </Dialog>
      {price && <PriceDialog goal={goal} onClose={() => setPrice(false)} />}
      {del && (
        <Confirm
          title={t('deleteGoal')}
          text={t('deleteGoalQ', { name: goal.name })}
          confirmLabel={t('delete')}
          danger
          onClose={() => setDel(false)}
          onConfirm={async () => {
            await deleteGoal(goal.id)
            sound.remove()
            onClose()
          }}
        />
      )}
    </>
  )
}
