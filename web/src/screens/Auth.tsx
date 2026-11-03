import { useState } from 'react'
import { useI18n } from '../lib/i18n'
import { useData } from '../lib/data'
import { Mark } from '../components/Icons'
import { LegalLinks } from '../components/Shell'
import { LangSwitch } from './Settings'
import { NewGoalFlow } from '../components/GoalForms'
import { sound } from '../lib/sound'
import { money } from '../lib/format'

export function Auth() {
  const { t, lang } = useI18n()
  const { signIn, signUp, useLocal, catalog } = useData()
  const [tab, setTab] = useState<'in' | 'up'>('in')
  const [email, setEmail] = useState('')
  const [pw, setPw] = useState('')
  const [name, setName] = useState('')
  const [msg, setMsg] = useState<{ bad: boolean; text: string } | null>(null)
  const [busy, setBusy] = useState(false)
  const top = catalog.slice(0, 3)

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    setBusy(true)
    setMsg(null)
    try {
      if (tab === 'in') await signIn(email.trim(), pw)
      else {
        const r = await signUp(email.trim(), pw, name)
        if (r === 'confirm') {
          setMsg({ bad: false, text: t('checkEmail', { email: email.trim() }) })
          setTab('in')
        }
      }
      sound.click()
    } catch (ex) {
      setMsg({ bad: true, text: t('authError', { msg: (ex as Error).message }) })
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="auth">
      <div className="auth-side">
        <div className="brand big">
          <Mark size={40} />
        </div>
        <h1>{t('appName')}</h1>
        <p className="lead-text">{t('tagline')}</p>
        {top.length > 0 && (
          <dl className="kv auth-prices" aria-label={t('priceNote')}>
            {top.map((c) => (
              <div key={c.id}><dt>{c.name}</dt><dd className="num money">{money(c.price_pln, lang)}</dd></div>
            ))}
          </dl>
        )}
        {top.length > 0 && <p className="meta">{t('priceNote')}</p>}
      </div>

      <div className="auth-main">
        <div className="auth-lang">
          <LangSwitch />
        </div>
        <section className="panel auth-panel" aria-labelledby="h-auth">
          <h2 id="h-auth" className="sr-only">{tab === 'in' ? t('signIn') : t('signUp')}</h2>
          <div className="segmented full" role="tablist">
            <button type="button" role="tab" aria-selected={tab === 'in'} className={tab === 'in' ? 'on' : ''} onClick={() => { sound.tab(); setTab('in'); setMsg(null) }}>{t('signIn')}</button>
            <button type="button" role="tab" aria-selected={tab === 'up'} className={tab === 'up' ? 'on' : ''} onClick={() => { sound.tab(); setTab('up'); setMsg(null) }}>{t('signUp')}</button>
          </div>
          <form className="form" onSubmit={submit}>
            {tab === 'up' && (
              <label className="field">
                <span>{t('yourName')}</span>
                <input value={name} onChange={(e) => setName(e.target.value)} autoComplete="given-name" maxLength={60} required />
              </label>
            )}
            <label className="field">
              <span>{t('email')}</span>
              <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="email" required />
            </label>
            <label className="field">
              <span>{t('password')}</span>
              <input type="password" value={pw} onChange={(e) => setPw(e.target.value)} autoComplete={tab === 'in' ? 'current-password' : 'new-password'} minLength={6} required aria-describedby="pw-help" />
            </label>
            <p id="pw-help" className="help">{tab === 'up' ? t('passwordHint') : ' '}</p>
            {msg && <p className={`help${msg.bad ? ' bad' : ''}`} role="status">{msg.text}</p>}
            <button type="submit" className="btn primary block" disabled={busy}>{tab === 'in' ? t('signIn') : t('signUp')}</button>
          </form>
          <div className="auth-local">
            <button type="button" className="btn block" onClick={() => { sound.click(); useLocal() }}>{t('continueWithout')}</button>
            <p className="help">{t('withoutHint')}</p>
          </div>
        </section>
        <LegalLinks />
      </div>
    </div>
  )
}

export function Onboarding() {
  const { t } = useI18n()
  const { profile, updateProfile } = useData()
  return (
    <div className="onboarding">
      <div className="onb-head">
        <Mark size={32} />
        <div>
          <h1>{t('onbTitle')}</h1>
          <p className="sub">{profile.display_name ? `${profile.display_name}, ` : ''}{t('onbSub').charAt(0).toLowerCase() + t('onbSub').slice(1)}</p>
        </div>
      </div>
      <section className="panel" aria-label={t('onbTitle')}>
        <NewGoalFlow inline submitLabel={t('startSaving')} onDone={() => void updateProfile({ onboarded: true })} />
      </section>
      <LegalLinks />
    </div>
  )
}
