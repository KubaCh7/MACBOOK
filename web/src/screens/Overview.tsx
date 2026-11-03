import { useMemo, useState } from 'react'
import { useI18n } from '../lib/i18n'
import { useData } from '../lib/data'
import { computeStats, activeDeposits } from '../lib/stats'
import { dayMonth, money, monthYear } from '../lib/format'
import { CumulativeChart } from '../components/Charts'
import { PhotoBox } from '../components/PhotoBox'
import { PriceDialog } from '../components/PriceDialog'
import { DepositDialog } from '../components/DepositDialog'
import { routeHash } from '../components/Shell'
import { PlusIcon } from '../components/Icons'
import type { Deposit, Goal } from '../lib/types'

export function forecastSentence(goal: Goal, deposits: Deposit[], t: ReturnType<typeof useI18n>['t'], lang: ReturnType<typeof useI18n>['lang']) {
  const s = computeStats(goal, deposits)
  if (s.left === 0 && s.saved > 0) return t('forecastDone')
  if (!s.forecast || s.pace <= 0) return t('forecastNone')
  return t('forecast', { month: monthYear(s.forecast, lang), pace: money(Math.round(s.pace), lang) })
}

export function Overview({ goal, onAddDeposit }: { goal: Goal; onAddDeposit: () => void }) {
  const { t, lang } = useI18n()
  const { deposits, photoSrc, updateGoal, setPhotoPosition } = useData()
  const s = useMemo(() => computeStats(goal, deposits), [goal, deposits])
  const recent = useMemo(() => activeDeposits(deposits, goal.id).slice(-5).reverse(), [deposits, goal.id])
  const [price, setPrice] = useState(false)
  const [edit, setEdit] = useState<Deposit | null>(null)
  const [photoErr, setPhotoErr] = useState<string | null>(null)
  const pct = Math.round(s.ratio * 1000) / 10

  const photoRun = (p: Promise<void>) => p.catch((e: Error) => setPhotoErr(t('error', { msg: e.message })))

  return (
    <>
      <div className="title-row">
        <div>
          <h1>{goal.name}</h1>
          <p className="sub">{forecastSentence(goal, deposits, t, lang)}</p>
        </div>
        <button type="button" className="btn primary hide-phone" onClick={onAddDeposit}>
          <PlusIcon size={14} /> {t('addDeposit')}
        </button>
      </div>

      <div className="ov-grid">
        <section className="panel progress-panel" aria-labelledby="h-progress">
          <header>
            <h2 id="h-progress">{t('progress')}</h2>
            <button type="button" className="btn sm" onClick={() => setPrice(true)}>{t('changePrice')}</button>
          </header>
          <div className="figures">
            <div className="fig lead">
              <span className="label">{t('saved')}</span>
              <span className="value num money">{money(s.saved, lang)}</span>
            </div>
            <div className="fig">
              <span className="label">{t('price')}</span>
              <span className="value num money">{money(s.target, lang)}</span>
            </div>
            <div className="fig">
              <span className="label">{t('left')}</span>
              <span className="value num money">{money(s.left, lang)}</span>
            </div>
          </div>
          <div className="bar-wrap">
            <div className="bar" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={pct} aria-label={t('progress')}>
              {s.ratio > 0 && <span style={{ width: `${s.ratio * 100}%` }} />}
            </div>
            <div className="bar-ends num">
              <span>{pct.toLocaleString(lang === 'pl' ? 'pl-PL' : 'en-GB')}%</span>
              <span>{money(s.target, lang)}</span>
            </div>
          </div>
          <dl className="strip">
            <div>
              <dt>{t('thisMonth')}</dt>
              <dd className={`num money${s.thisMonth === 0 ? ' zero' : ''}`}>{money(s.thisMonth, lang, { sign: s.thisMonth > 0 })}</dd>
            </div>
            <div>
              <dt>{t('pace')}</dt>
              <dd className={`num money${s.pace === 0 ? ' zero' : ''}`}>{money(Math.round(s.pace), lang)}<small>{t('perMonth')}</small></dd>
            </div>
            <div>
              <dt>{t('avgDeposit')}</dt>
              <dd className="num money">{s.depositCount ? money(s.avgDeposit, lang) : <span className="dash">—</span>}</dd>
            </div>
            <div>
              <dt>{t('depositCount')}</dt>
              <dd className="num">{s.depositCount}</dd>
            </div>
          </dl>
        </section>

        <section className="panel photo-panel" aria-label={t('photo')}>
          <PhotoBox
            compact
            src={photoSrc(goal)}
            position={goal.photo_position}
            alt={goal.name}
            onFile={(f) => photoRun(updateGoal(goal.id, { photoFile: f, photo_position: '50% 50%' }))}
            onLink={(u) => photoRun(updateGoal(goal.id, { photoLink: u, photo_position: '50% 50%' }))}
            onRemove={() => photoRun(updateGoal(goal.id, { removePhoto: true }))}
            onPosition={(p) => photoRun(setPhotoPosition(goal.id, p))}
          />
          {photoErr && <p className="help bad">{photoErr}</p>}
        </section>

        <section className="panel chart-panel" aria-labelledby="h-cum">
          <header>
            <h2 id="h-cum">{t('cumulative')}</h2>
            <span className="legend">
              <span className="key"><i className="sw-line" />{t('saved')}</span>
              <span className="key"><i className="sw-dash" />{t('forecastLegend')}</span>
            </span>
          </header>
          <CumulativeChart months={s.months} target={s.target} pace={s.pace} lang={lang}
            labels={{ forecast: t('forecastLegend'), price: t('priceLine'), saved: t('saved') }} />
        </section>

        <section className="panel recent-panel" aria-labelledby="h-recent">
          <header>
            <h2 id="h-recent">{t('recent')}</h2>
            {recent.length > 0 && <a className="card-link" href={routeHash.deposits}>{t('viewAll')}</a>}
          </header>
          {recent.length ? (
            <ul className="rows">
              {recent.map((d) => (
                <li key={d.id}>
                  <button type="button" className="row-btn" onClick={() => setEdit(d)}>
                    <span className="row-main">
                      <span className="strong-line">{d.note || (d.amount < 0 ? t('withdrawal') : t('deposit'))}</span>
                      <span className="sub-line">{dayMonth(d.deposit_date, lang)}</span>
                    </span>
                    <span className={`num money${d.amount < 0 ? ' neg' : ''}`}>{money(d.amount, lang, { sign: true })}</span>
                  </button>
                </li>
              ))}
            </ul>
          ) : (
            <div className="empty">
              <p>{t('noDeposits')}</p>
              <button type="button" className="btn primary" onClick={onAddDeposit}><PlusIcon size={14} /> {t('addDeposit')}</button>
            </div>
          )}
        </section>
      </div>

      {price && <PriceDialog goal={goal} onClose={() => setPrice(false)} />}
      {edit && <DepositDialog goalId={goal.id} existing={edit} onClose={() => setEdit(null)} />}
    </>
  )
}
