import { useEffect, useState, type ReactNode } from 'react'
import { useI18n } from '../lib/i18n'
import { useData } from '../lib/data'
import { sound } from '../lib/sound'
import type { Goal } from '../lib/types'
import { ArrowsIcon, CloseIcon, FlagIcon, LaptopIcon, Mark, MenuIcon, PlusIcon, SlidersIcon } from './Icons'

export type Route = 'overview' | 'deposits' | 'goals' | 'settings' | 'privacy' | 'terms' | 'info'

export const routeHash: Record<Route, string> = {
  overview: '#/',
  deposits: '#/wplaty',
  goals: '#/cele',
  settings: '#/ustawienia',
  privacy: '#/prywatnosc',
  terms: '#/regulamin',
  info: '#/informacje',
}

export function parseRoute(h: string): Route {
  const found = (Object.entries(routeHash) as [Route, string][]).find(([, v]) => v === h)
  return found ? found[0] : 'overview'
}

const NAV: { r: Route; key: 'navOverview' | 'navDeposits' | 'navGoals' | 'navSettings'; Icon: typeof LaptopIcon }[] = [
  { r: 'overview', key: 'navOverview', Icon: LaptopIcon },
  { r: 'deposits', key: 'navDeposits', Icon: ArrowsIcon },
  { r: 'goals', key: 'navGoals', Icon: FlagIcon },
  { r: 'settings', key: 'navSettings', Icon: SlidersIcon },
]

function GoalSwitch({ goals, goalId, onGoal }: { goals: Goal[]; goalId: string | null; onGoal: (id: string) => void }) {
  const { t } = useI18n()
  if (!goals.length) return null
  return (
    <label className="goal-switch">
      <span className="switch-label">{t('goal')}</span>
      <select value={goalId ?? ''} onChange={(e) => { sound.tab(); onGoal(e.target.value) }}>
        {goals.map((g) => (
          <option key={g.id} value={g.id}>{g.name}</option>
        ))}
      </select>
    </label>
  )
}

function Nav({ route, onNav }: { route: Route; onNav: () => void }) {
  const { t } = useI18n()
  return (
    <nav aria-label="Main">
      <ul className="nav">
        {NAV.map(({ r, key, Icon }) => (
          <li key={r}>
            <a href={routeHash[r]} className="nav-item" aria-current={route === r ? 'page' : undefined} onClick={() => { sound.tab(); onNav() }}>
              <Icon /> {t(key)}
            </a>
          </li>
        ))}
      </ul>
    </nav>
  )
}

export function LegalLinks() {
  const { t } = useI18n()
  return (
    <p className="legal-links">
      <a href={routeHash.privacy}>{t('privacy')}</a>
      <a href={routeHash.terms}>{t('terms')}</a>
      <a href={routeHash.info}>{t('info')}</a>
    </p>
  )
}

export function Shell({ route, title, goalId, onGoal, onAddDeposit, children }: {
  route: Route
  title: string
  goalId: string | null
  onGoal: (id: string) => void
  onAddDeposit: (() => void) | null
  children: ReactNode
}) {
  const { t } = useI18n()
  const { goals, profile, email, mode } = useData()
  const [menu, setMenu] = useState(false)
  useEffect(() => {
    document.body.classList.toggle('menu-open', menu)
  }, [menu])
  useEffect(() => setMenu(false), [route])
  const who = profile.display_name || (mode === 'local' ? t('noAccount') : email ?? '')

  return (
    <div className="app">
      <aside className="sidebar">
        <a className="brand" href={routeHash.overview}>
          <Mark size={28} />
          <span>{t('appName')}</span>
        </a>
        <GoalSwitch goals={goals} goalId={goalId} onGoal={onGoal} />
        <Nav route={route} onNav={() => {}} />
        <div className="sidebar-bottom">
          <p className="user-row">
            <span className="avatar" aria-hidden="true">{(who || '·').slice(0, 1).toUpperCase()}</span>
            <span className="user-name">{who}</span>
          </p>
        </div>
      </aside>

      <header className="topbar">
        <button type="button" className="icon-btn" aria-label={t('menu')} aria-expanded={menu} onClick={() => { sound.click(); setMenu(true) }}>
          <MenuIcon size={18} />
        </button>
        <span className="topbar-title">{title}</span>
        {onAddDeposit ? (
          <button type="button" className="btn primary sm" onClick={onAddDeposit} aria-label={t('addDeposit')}>
            <PlusIcon size={14} /> {t('deposit')}
          </button>
        ) : <span className="topbar-spacer" />}
      </header>

      {menu && (
        <div className="menu-sheet" role="dialog" aria-modal="true" aria-label={t('menu')}>
          <div className="menu-head">
            <a className="brand" href={routeHash.overview} onClick={() => setMenu(false)}>
              <Mark size={28} />
              <span>{t('appName')}</span>
            </a>
            <button type="button" className="icon-btn" aria-label={t('close')} onClick={() => setMenu(false)}>
              <CloseIcon size={18} />
            </button>
          </div>
          <GoalSwitch goals={goals} goalId={goalId} onGoal={(id) => { onGoal(id); setMenu(false) }} />
          <Nav route={route} onNav={() => setMenu(false)} />
          <div className="sidebar-bottom">
            <p className="user-row">
              <span className="avatar" aria-hidden="true">{(who || '·').slice(0, 1).toUpperCase()}</span>
              <span className="user-name">{who}</span>
            </p>
            <LegalLinks />
          </div>
        </div>
      )}

      <main className="canvas">
        {children}
        <footer className="page-foot">
          <span>{t('appName')}</span>
          <LegalLinks />
        </footer>
      </main>
    </div>
  )
}
