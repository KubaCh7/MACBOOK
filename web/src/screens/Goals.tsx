import { useState } from 'react'
import { useI18n } from '../lib/i18n'
import { useData } from '../lib/data'
import { computeStats } from '../lib/stats'
import { money, plural, W } from '../lib/format'
import { forecastSentence } from './Overview'
import { EditGoalDialog, NewGoalDialog } from '../components/GoalForms'
import { CatalogPicker } from '../components/CatalogPicker'
import { LaptopIcon, PlusIcon, StarIcon } from '../components/Icons'
import { parsePos } from '../lib/photo'
import { sound } from '../lib/sound'
import type { Goal } from '../lib/types'

export function Goals({ onOpen }: { onOpen: (id: string) => void }) {
  const { t, lang } = useI18n()
  const { goals, deposits, photoSrc, setDefaultGoal, catalog, createGoal } = useData()
  const [adding, setAdding] = useState(false)
  const [edit, setEdit] = useState<Goal | null>(null)
  const [err, setErr] = useState<string | null>(null)
  const def = goals.find((g) => g.is_default)

  return (
    <>
      <div className="title-row">
        <div>
          <h1>{t('navGoals')}</h1>
          <p className="sub">{plural(lang, goals.length, W.goals)}{def ? ` · ${t('main').toLowerCase()}: ${def.name}` : ''}</p>
        </div>
        <button type="button" className="btn primary" onClick={() => setAdding(true)}>
          <PlusIcon size={14} /> {t('addGoal')}
        </button>
      </div>

      <div className="goals-grid">
        <section className="panel" aria-labelledby="h-goals">
          <header><h2 id="h-goals">{t('yourGoals')}</h2></header>
          {err && <p className="help bad">{err}</p>}
          <ul className="goal-list">
            {goals.map((g) => {
              const s = computeStats(g, deposits)
              const src = photoSrc(g)
              const p = parsePos(g.photo_position)
              return (
                <li key={g.id} className="goal-row">
                  <button type="button" className="goal-open" onClick={() => { sound.tab(); onOpen(g.id) }}>
                    <span className="thumb">
                      {src ? <img src={src} alt="" style={{ objectPosition: `${p.x}% ${p.y}%` }} /> : <LaptopIcon size={20} />}
                    </span>
                    <span className="goal-text">
                      <span className="strong-line">{g.name}</span>
                      <span className="sub-line num">{money(s.saved, lang)} {t('ofPrice', { price: money(s.target, lang) })} · {t('left').toLowerCase()} {money(s.left, lang)}</span>
                      <span className="mini-bar"><span style={{ width: `${s.ratio * 100}%` }} /></span>
                      <span className="sub-line">{forecastSentence(g, deposits, t, lang)}</span>
                    </span>
                  </button>
                  <div className="goal-actions">
                    <button
                      type="button"
                      className={`icon-btn star${g.is_default ? ' on' : ''}`}
                      aria-pressed={g.is_default}
                      aria-label={g.is_default ? t('main') : t('setMain')}
                      title={g.is_default ? t('main') : t('setMain')}
                      onClick={() => {
                        if (g.is_default) return
                        sound.click()
                        setDefaultGoal(g.id).catch((e: Error) => setErr(t('error', { msg: e.message })))
                      }}
                    >
                      <StarIcon size={16} filled={g.is_default} />
                    </button>
                    <button type="button" className="btn sm" onClick={() => setEdit(g)}>{t('edit')}</button>
                  </div>
                </li>
              )
            })}
          </ul>
          <button type="button" className="add-slot" onClick={() => setAdding(true)}>
            <PlusIcon size={14} /> {t('addGoal')}
          </button>
        </section>

        <section className="panel" aria-labelledby="h-sugg">
          <header><h2 id="h-sugg">{t('suggestions')}</h2></header>
          <CatalogPicker
            items={catalog}
            limit={4}
            onPick={(c) =>
              createGoal({ name: c.name, target_amount: c.price_pln, catalog_id: c.id })
                .then(() => sound.chord())
                .catch((e: Error) => setErr(t('error', { msg: e.message })))
            }
          />
        </section>
      </div>

      {adding && <NewGoalDialog onClose={() => setAdding(false)} />}
      {edit && <EditGoalDialog goal={goals.find((g) => g.id === edit.id) ?? edit} onClose={() => setEdit(null)} />}
    </>
  )
}
