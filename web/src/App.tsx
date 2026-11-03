import { useEffect, useState } from 'react'
import { useI18n } from './lib/i18n'
import { useData } from './lib/data'
import { Shell, parseRoute, type Route } from './components/Shell'
import { DepositDialog } from './components/DepositDialog'
import { Overview } from './screens/Overview'
import { Deposits } from './screens/Deposits'
import { Goals } from './screens/Goals'
import { Settings } from './screens/Settings'
import { Auth, Onboarding } from './screens/Auth'
import { Legal } from './screens/Legal'
import { sound } from './lib/sound'
import { Mark } from './components/Icons'

function useRoute(): Route {
  const [r, setR] = useState<Route>(() => parseRoute(window.location.hash || '#/'))
  useEffect(() => {
    const on = () => {
      setR(parseRoute(window.location.hash || '#/'))
      window.scrollTo(0, 0)
    }
    window.addEventListener('hashchange', on)
    return () => window.removeEventListener('hashchange', on)
  }, [])
  return r
}

export default function App() {
  const { t } = useI18n()
  const data = useData()
  const route = useRoute()
  const [goalId, setGoalId] = useState<string | null>(null)
  const [adding, setAdding] = useState(false)

  const goals = data.goals
  const current = goals.find((g) => g.id === goalId) ?? goals.find((g) => g.is_default) ?? goals[0] ?? null
  useEffect(() => {
    if (goalId && !goals.some((g) => g.id === goalId)) setGoalId(null)
  }, [goals, goalId])

  const titles: Record<Route, string> = {
    overview: t('navOverview'), deposits: t('navDeposits'), goals: t('navGoals'), settings: t('navSettings'),
    privacy: t('privacy'), terms: t('terms'), info: t('info'),
  }
  useEffect(() => {
    document.title = route === 'overview' ? t('appName') : `${titles[route]} · ${t('appName')}`
  })

  const isDoc = route === 'privacy' || route === 'terms' || route === 'info'

  if (data.mode === 'loading') {
    return (
      <div className="loading-screen" aria-busy="true">
        <Mark size={40} />
        <span className="sr-only">{t('appName')}</span>
      </div>
    )
  }

  if (isDoc && (data.mode === 'signedOut' || !current)) {
    return (
      <div className="doc-page">
        <Legal doc={route} />
      </div>
    )
  }

  if (data.mode === 'signedOut') return <Auth />
  if (!current) return <Onboarding />

  const openAdd = () => {
    sound.click()
    setAdding(true)
  }

  return (
    <Shell route={route} title={titles[route]} goalId={current.id} onGoal={setGoalId} onAddDeposit={route === 'overview' || route === 'deposits' ? openAdd : null}>
      {data.error && (
        <div className="notice" role="status">
          {t('error', { msg: data.error })}{' '}
          <button type="button" className="card-link" onClick={() => void data.reload()}>{t('retry')}</button>
        </div>
      )}
      {route === 'overview' && <Overview goal={current} onAddDeposit={openAdd} />}
      {route === 'deposits' && <Deposits goal={current} onAddDeposit={openAdd} />}
      {route === 'goals' && <Goals onOpen={(id) => { setGoalId(id); window.location.hash = '#/' }} />}
      {route === 'settings' && <Settings />}
      {isDoc && <Legal doc={route} />}
      {adding && <DepositDialog goalId={current.id} onClose={() => setAdding(false)} />}
    </Shell>
  )
}
