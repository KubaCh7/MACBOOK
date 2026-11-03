import { useState } from 'react'
import { useI18n } from '../lib/i18n'
import { useData } from '../lib/data'
import { usePrefs } from '../lib/prefs'
import { Dialog } from '../components/Dialog'
import { routeHash } from '../components/Shell'
import { sound } from '../lib/sound'
import type { Lang, ThemePref } from '../lib/types'

export function LangSwitch() {
  const { lang, setLang, t } = useI18n()
  return (
    <div className="segmented" role="radiogroup" aria-label={t('language')}>
      {(['pl', 'en'] as Lang[]).map((l) => (
        <button key={l} type="button" role="radio" aria-checked={lang === l} className={lang === l ? 'on' : ''} onClick={() => { sound.tab(); setLang(l) }}>
          {l === 'pl' ? 'Polski' : 'English'}
        </button>
      ))}
    </div>
  )
}

function Section({ title, desc, children }: { title: string; desc: string; children: React.ReactNode }) {
  return (
    <section className="set-row">
      <div className="set-label">
        <h2>{title}</h2>
        <p>{desc}</p>
      </div>
      <div className="set-panel">{children}</div>
    </section>
  )
}

export function Settings() {
  const { t } = useI18n()
  const { theme, setTheme, sounds, setSounds } = usePrefs()
  const { profile, updateProfile, mode, email, exportJson, signOut, deleteAccount } = useData()
  const [name, setName] = useState(profile.display_name)
  const [stamp, setStamp] = useState(false)
  const [err, setErr] = useState<string | null>(null)
  const [del, setDel] = useState(false)
  const [typed, setTyped] = useState('')

  return (
    <>
      <div className="title-row">
        <div>
          <h1>{t('navSettings')}</h1>
          <p className="sub">{mode === 'remote' && email ? t('signedInAs', { email }) : t('noAccount')}</p>
        </div>
      </div>

      <div className="settings">
        <Section title={t('profile')} desc={t('profileDesc')}>
          <form
            className="form"
            onSubmit={async (e) => {
              e.preventDefault()
              try {
                await updateProfile({ display_name: name.trim() })
                sound.click()
                setStamp(true)
                setTimeout(() => setStamp(false), 2000)
              } catch (ex) {
                setErr(t('error', { msg: (ex as Error).message }))
              }
            }}
          >
            <label className="field">
              <span>{t('yourName')}</span>
              <input value={name} maxLength={60} onChange={(e) => setName(e.target.value)} autoComplete="given-name" />
            </label>
            {mode === 'remote' && (
              <label className="field">
                <span>{t('email')}</span>
                <input value={email ?? ''} readOnly />
              </label>
            )}
            <div className="panel-foot">
              <span className="stamp" aria-live="polite">{stamp ? t('saved_') : ''}</span>
              <button type="submit" className="btn primary">{t('save')}</button>
            </div>
            {err && <p className="help bad">{err}</p>}
          </form>
        </Section>

        <Section title={t('appearance')} desc={t('appearanceDesc')}>
          <div className="form">
            <div className="field">
              <span>{t('language')}</span>
              <LangSwitch />
            </div>
            <div className="field">
              <span>{t('theme')}</span>
              <div className="segmented" role="radiogroup" aria-label={t('theme')}>
                {(['system', 'light', 'dark'] as ThemePref[]).map((m) => (
                  <button key={m} type="button" role="radio" aria-checked={theme === m} className={theme === m ? 'on' : ''} onClick={() => { sound.tab(); setTheme(m) }}>
                    {m === 'system' ? t('themeSystem') : m === 'light' ? t('themeLight') : t('themeDark')}
                  </button>
                ))}
              </div>
            </div>
            <div className="switch-row">
              <div>
                <span className="switch-title">{t('sounds')}</span>
                <span className="switch-desc">{t('soundsDesc')}</span>
              </div>
              <button type="button" role="switch" aria-checked={sounds} aria-label={t('sounds')} className="switch" onClick={() => { setSounds(!sounds); if (!sounds) setTimeout(sound.coin, 30) }}>
                <span />
              </button>
            </div>
          </div>
        </Section>

        <Section title={t('data')} desc={t('dataDesc')}>
          <div className="form">
            <button type="button" className="btn fit" onClick={() => { sound.click(); exportJson() }}>{t('exportJson')}</button>
          </div>
        </Section>

        <Section title={t('documents')} desc={t('documentsDesc')}>
          <ul className="doc-links">
            <li><a className="card-link" href={routeHash.privacy}>{t('privacy')}</a></li>
            <li><a className="card-link" href={routeHash.terms}>{t('terms')}</a></li>
            <li><a className="card-link" href={routeHash.info}>{t('info')}</a></li>
          </ul>
        </Section>

        <Section title={t('account')} desc={mode === 'remote' ? t('accountDesc') : t('localAccountDesc')}>
          <div className="form">
            <div className="btn-row">
              {mode === 'remote' ? (
                <button type="button" className="btn" onClick={() => void signOut()}>{t('signOut')}</button>
              ) : (
                <button type="button" className="btn primary" onClick={() => void signOut()}>{t('createAccount')}</button>
              )}
              <button type="button" className="btn danger-text" onClick={() => setDel(true)}>{mode === 'remote' ? t('deleteAccount') : t('deleteLocal')}</button>
            </div>
          </div>
        </Section>
      </div>

      {del && (
        <Dialog
          title={mode === 'remote' ? t('deleteAccount') : t('deleteLocal')}
          onClose={() => setDel(false)}
          footer={
            <>
              <button type="button" className="btn" onClick={() => setDel(false)}>{t('cancel')}</button>
              <button
                type="button"
                className="btn danger"
                disabled={typed.trim().toUpperCase() !== t('deleteWord')}
                onClick={async () => {
                  try {
                    await deleteAccount()
                    sound.remove()
                  } catch (ex) {
                    setErr(t('error', { msg: (ex as Error).message }))
                    setDel(false)
                  }
                }}
              >
                {t('delete')}
              </button>
            </>
          }
        >
          <div className="form">
            <p>{t('deleteAccountQ')}</p>
            <label className="field">
              <span>{t('typeDelete')}</span>
              <input value={typed} onChange={(e) => setTyped(e.target.value)} autoComplete="off" />
            </label>
          </div>
        </Dialog>
      )}
    </>
  )
}
