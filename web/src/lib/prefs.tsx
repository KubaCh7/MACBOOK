import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import type { Lang, ThemePref } from './types'
import { I18nContext, makeT } from './i18n'
import { setSoundEnabled } from './sound'

const read = <T,>(k: string, fallback: T): T => {
  try {
    const v = localStorage.getItem(k)
    return v === null ? fallback : (JSON.parse(v) as T)
  } catch {
    return fallback
  }
}
const write = (k: string, v: unknown) => {
  try {
    localStorage.setItem(k, JSON.stringify(v))
  } catch {
    /* ignore */
  }
}

interface Prefs {
  theme: ThemePref
  setTheme: (t: ThemePref) => void
  sounds: boolean
  setSounds: (s: boolean) => void
}

const PrefsCtx = createContext<Prefs | null>(null)
export const usePrefs = () => useContext(PrefsCtx)!

export function PrefsProvider({ children }: { children: ReactNode }) {
  const [lang, setLangS] = useState<Lang>(() => read<Lang>('mp:lang', 'pl'))
  const [theme, setThemeS] = useState<ThemePref>(() => read<ThemePref>('mp:theme', 'system'))
  const [sounds, setSoundsS] = useState<boolean>(() => read<boolean>('mp:sounds', true))

  useEffect(() => {
    document.documentElement.lang = lang
  }, [lang])
  useEffect(() => {
    const root = document.documentElement
    if (theme === 'system') root.removeAttribute('data-theme')
    else root.setAttribute('data-theme', theme)
    const dark = theme === 'dark' || (theme === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches)
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', dark ? '#0a0a0a' : '#f8f8f8')
  }, [theme])
  useEffect(() => setSoundEnabled(sounds), [sounds])

  const i18n = useMemo(() => ({ lang, t: makeT(lang), setLang: (l: Lang) => { setLangS(l); write('mp:lang', l) } }), [lang])
  const prefs = useMemo<Prefs>(() => ({
    theme,
    setTheme: (t) => { setThemeS(t); write('mp:theme', t) },
    sounds,
    setSounds: (s) => { setSoundsS(s); write('mp:sounds', s) },
  }), [theme, sounds])

  return (
    <I18nContext.Provider value={i18n}>
      <PrefsCtx.Provider value={prefs}>{children}</PrefsCtx.Provider>
    </I18nContext.Provider>
  )
}
