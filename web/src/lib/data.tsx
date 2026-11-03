import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import type { CatalogItem, Deposit, Goal, Profile } from './types'
import { PHOTO_BUCKET, supabase } from './supabase'
import { goalBalance } from './stats'
import { blobToDataUrl, resizeToJpeg } from './photo'
import { demoData } from './demo'
import { fallbackCatalog } from './catalogFallback'

type Mode = 'loading' | 'signedOut' | 'local' | 'remote'

interface LocalData {
  profile: Profile
  goals: Goal[]
  deposits: Deposit[]
}

const LOCAL_KEY = 'mp:local:v1'
const LOCAL_MODE_KEY = 'mp:mode'

function readLocal(): LocalData {
  try {
    const raw = localStorage.getItem(LOCAL_KEY)
    if (raw) return JSON.parse(raw) as LocalData
  } catch {
    /* brak dostępu do localStorage */
  }
  return { profile: { display_name: '', onboarded: false }, goals: [], deposits: [] }
}

function writeLocal(d: LocalData) {
  try {
    localStorage.setItem(LOCAL_KEY, JSON.stringify(d))
  } catch {
    /* pełne albo zablokowane */
  }
}

const uuid = () => (crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(16).slice(2)}`)
const nowIso = () => new Date().toISOString()

const numGoal = (g: Goal): Goal => ({ ...g, target_amount: Number(g.target_amount) })
const numDep = (d: Deposit): Deposit => ({ ...d, amount: Number(d.amount) })
const numCat = (c: CatalogItem): CatalogItem => ({ ...c, price_pln: Number(c.price_pln), screen_inches: Number(c.screen_inches) })

export interface GoalDraft {
  name: string
  target_amount: number
  catalog_id: string | null
  photo_position?: string
  /** nowy plik zdjęcia albo link https:// */
  photoFile?: Blob | null
  photoLink?: string | null
  removePhoto?: boolean
}

export interface DataApi {
  mode: Mode
  email: string | null
  profile: Profile
  goals: Goal[]
  deposits: Deposit[]
  catalog: CatalogItem[]
  config: Record<string, unknown>
  error: string | null
  photoSrc: (g: Goal) => string | null
  signIn: (email: string, password: string) => Promise<void>
  signUp: (email: string, password: string, name: string) => Promise<'session' | 'confirm'>
  useLocal: () => void
  signOut: () => Promise<void>
  updateProfile: (p: Partial<Profile>) => Promise<void>
  createGoal: (d: GoalDraft, makeDefault?: boolean) => Promise<Goal>
  updateGoal: (id: string, d: Partial<GoalDraft>) => Promise<void>
  setPhotoPosition: (id: string, pos: string) => Promise<void>
  changePrice: (id: string, price: number) => Promise<void>
  deleteGoal: (id: string) => Promise<void>
  setDefaultGoal: (id: string) => Promise<void>
  saveDeposit: (d: { id?: string; goal_id: string; amount: number; deposit_date: string; note: string | null }) => Promise<void>
  deleteDeposit: (id: string) => Promise<void>
  exportJson: () => void
  deleteAccount: () => Promise<void>
  reload: () => Promise<void>
}

const Ctx = createContext<DataApi | null>(null)

export function useData(): DataApi {
  const c = useContext(Ctx)
  if (!c) throw new Error('DataProvider missing')
  return c
}

export function DataProvider({ children }: { children: ReactNode }) {
  const [mode, setMode] = useState<Mode>('loading')
  const [email, setEmail] = useState<string | null>(null)
  const [uid, setUid] = useState<string | null>(null)
  const [profile, setProfile] = useState<Profile>({ display_name: '', onboarded: false })
  const [goals, setGoals] = useState<Goal[]>([])
  const [deposits, setDeposits] = useState<Deposit[]>([])
  const [catalog, setCatalog] = useState<CatalogItem[]>(fallbackCatalog)
  const [config, setConfig] = useState<Record<string, unknown>>({})
  const [error, setError] = useState<string | null>(null)
  const [signed, setSigned] = useState<Record<string, string>>({})
  const modeRef = useRef<Mode>('loading')
  modeRef.current = mode

  // ── katalog i konfiguracja (dla wszystkich) ──
  const loadPublic = useCallback(async () => {
    if (!supabase) return
    const [cat, cfg] = await Promise.all([
      supabase.from('macbook_catalog').select('*').eq('is_active', true).order('popularity', { ascending: false }),
      supabase.from('app_config').select('key,value'),
    ])
    if (cat.data?.length) setCatalog((cat.data as CatalogItem[]).map(numCat))
    if (cfg.data) setConfig(Object.fromEntries((cfg.data as { key: string; value: unknown }[]).map((r) => [r.key, r.value])))
  }, [])

  // ── dane użytkownika ──
  const loadRemote = useCallback(async (userId: string) => {
    if (!supabase) return
    const [p, g, d] = await Promise.all([
      supabase.from('profiles').select('display_name,onboarded').eq('id', userId).maybeSingle(),
      supabase.from('goals').select('*').is('deleted_at', null).order('created_at'),
      supabase.from('deposits').select('*').is('deleted_at', null).order('deposit_date'),
    ])
    const err = p.error || g.error || d.error
    if (err) {
      setError(err.message)
      return
    }
    setError(null)
    if (p.data) setProfile(p.data as Profile)
    setGoals((g.data as Goal[]).map(numGoal))
    setDeposits((d.data as Deposit[]).map(numDep))
  }, [])

  // przeniesienie danych z trybu bez konta po zalogowaniu (gdy konto jest puste)
  const migrateLocal = useCallback(async (userId: string) => {
    if (!supabase) return
    const local = readLocal()
    if (!local.goals.length) return
    const { count } = await supabase.from('goals').select('id', { count: 'exact', head: true })
    if ((count ?? 0) > 0) return
    const goalsRows = local.goals.map((g) => ({
      id: g.id, user_id: userId, name: g.name, target_amount: g.target_amount, photo_url: g.photo_url?.startsWith('http') ? g.photo_url : null,
      photo_position: g.photo_position, catalog_id: g.catalog_id, is_default: g.is_default, created_at: g.created_at, deleted_at: g.deleted_at,
    }))
    const { error: e1 } = await supabase.from('goals').insert(goalsRows)
    if (e1) return
    const depRows = local.deposits.map((d) => ({
      id: d.id, user_id: userId, goal_id: d.goal_id, amount: d.amount, deposit_date: d.deposit_date, note: d.note, created_at: d.created_at, deleted_at: d.deleted_at,
    }))
    if (depRows.length) await supabase.from('deposits').insert(depRows)
    await supabase.from('profiles').update({ onboarded: true, ...(local.profile.display_name ? { display_name: local.profile.display_name } : {}) }).eq('id', userId)
    writeLocal({ profile: { display_name: '', onboarded: false }, goals: [], deposits: [] })
  }, [])

  const enterLocal = useCallback(() => {
    const l = readLocal()
    setProfile(l.profile)
    setGoals(l.goals.filter((g) => !g.deleted_at))
    setDeposits(l.deposits.filter((d) => !d.deleted_at))
    setEmail(null)
    setUid(null)
    setMode('local')
  }, [])

  useEffect(() => {
    void loadPublic()
    // podgląd z przykładowymi danymi: ?demo
    if (new URLSearchParams(window.location.search).has('demo')) {
      writeLocal(demoData())
      localStorage.setItem(LOCAL_MODE_KEY, '1')
      window.history.replaceState(null, '', window.location.pathname + window.location.hash)
      enterLocal()
      return
    }
    if (!supabase) {
      enterLocal()
      return
    }
    let active = true
    supabase.auth.getSession().then(async ({ data }) => {
      if (!active) return
      const s = data.session
      if (s) {
        setEmail(s.user.email ?? null)
        setUid(s.user.id)
        await loadRemote(s.user.id)
        setMode('remote')
      } else if (localStorage.getItem(LOCAL_MODE_KEY) === '1') {
        enterLocal()
      } else {
        setMode('signedOut')
      }
    })
    const { data: sub } = supabase.auth.onAuthStateChange((event, s) => {
      if (event === 'SIGNED_OUT') {
        setUid(null)
        setEmail(null)
        setGoals([])
        setDeposits([])
        setProfile({ display_name: '', onboarded: false })
        if (modeRef.current === 'remote') setMode('signedOut')
      }
      if (event === 'SIGNED_IN' && s && modeRef.current !== 'remote') {
        setEmail(s.user.email ?? null)
        setUid(s.user.id)
      }
    })
    return () => {
      active = false
      sub.subscription.unsubscribe()
    }
  }, [enterLocal, loadPublic, loadRemote])

  // ── Realtime: zmiany z iPhone'a pojawiają się same ──
  useEffect(() => {
    if (!supabase || mode !== 'remote' || !uid) return
    let timer: number | undefined
    const refresh = () => {
      window.clearTimeout(timer)
      timer = window.setTimeout(() => void loadRemote(uid), 300)
    }
    const ch = supabase
      .channel(`user-${uid}`)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'goals', filter: `user_id=eq.${uid}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'deposits', filter: `user_id=eq.${uid}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles', filter: `id=eq.${uid}` }, refresh)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'macbook_catalog' }, () => void loadPublic())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'app_config' }, () => void loadPublic())
      .subscribe()
    const onFocus = () => refresh()
    window.addEventListener('focus', onFocus)
    return () => {
      window.removeEventListener('focus', onFocus)
      window.clearTimeout(timer)
      void supabase!.removeChannel(ch)
    }
  }, [mode, uid, loadRemote, loadPublic])

  // ── podpisane adresy zdjęć z prywatnego Storage ──
  useEffect(() => {
    if (!supabase || mode !== 'remote') return
    const paths = goals.map((g) => g.photo_url).filter((p): p is string => !!p && !p.startsWith('http') && !p.startsWith('data:') && !signed[p])
    if (!paths.length) return
    void supabase.storage.from(PHOTO_BUCKET).createSignedUrls(paths, 60 * 60 * 6).then(({ data }) => {
      if (!data) return
      setSigned((prev) => {
        const next = { ...prev }
        for (const r of data) if (r.signedUrl && r.path) next[r.path] = r.signedUrl
        return next
      })
    })
  }, [goals, mode, signed])

  const photoSrc = useCallback(
    (g: Goal) => {
      const p = g.photo_url
      if (!p) return null
      if (p.startsWith('http') || p.startsWith('data:')) return p
      return signed[p] ?? null
    },
    [signed],
  )

  // ── zapis lokalny ──
  const persistLocal = useCallback((next: Partial<LocalData>) => {
    const cur = readLocal()
    const merged: LocalData = { ...cur, ...next }
    writeLocal(merged)
  }, [])

  // ── auth ──
  const signIn = useCallback(async (em: string, pw: string) => {
    if (!supabase) throw new Error('Supabase not configured')
    const { data, error: e } = await supabase.auth.signInWithPassword({ email: em, password: pw })
    if (e) throw e
    localStorage.removeItem(LOCAL_MODE_KEY)
    setEmail(data.user.email ?? null)
    setUid(data.user.id)
    await migrateLocal(data.user.id)
    await loadRemote(data.user.id)
    setMode('remote')
  }, [loadRemote, migrateLocal])

  const signUp = useCallback(async (em: string, pw: string, name: string) => {
    if (!supabase) throw new Error('Supabase not configured')
    const { data, error: e } = await supabase.auth.signUp({
      email: em,
      password: pw,
      options: { data: { display_name: name.trim() }, emailRedirectTo: window.location.origin },
    })
    if (e) throw e
    if (!data.session || !data.user) return 'confirm'
    localStorage.removeItem(LOCAL_MODE_KEY)
    setEmail(data.user.email ?? null)
    setUid(data.user.id)
    await migrateLocal(data.user.id)
    await loadRemote(data.user.id)
    setMode('remote')
    return 'session'
  }, [loadRemote, migrateLocal])

  const useLocal = useCallback(() => {
    localStorage.setItem(LOCAL_MODE_KEY, '1')
    enterLocal()
  }, [enterLocal])

  const signOut = useCallback(async () => {
    localStorage.removeItem(LOCAL_MODE_KEY)
    if (supabase && mode === 'remote') await supabase.auth.signOut()
    setGoals([])
    setDeposits([])
    setProfile({ display_name: '', onboarded: false })
    setMode(supabase ? 'signedOut' : 'local')
  }, [mode])

  // ── profil ──
  const updateProfile = useCallback(async (p: Partial<Profile>) => {
    const next = { ...profile, ...p }
    setProfile(next)
    if (mode === 'local') persistLocal({ profile: next })
    else if (supabase && uid) {
      const { error: e } = await supabase.from('profiles').upsert({ id: uid, ...next })
      if (e) throw e
    }
  }, [profile, mode, uid, persistLocal])

  // ── zdjęcia ──
  const storePhoto = useCallback(async (goalId: string, file: Blob): Promise<string> => {
    if (mode === 'local' || !supabase || !uid) {
      const small = await resizeToJpeg(file, 1000, 0.8)
      return blobToDataUrl(small)
    }
    const jpg = await resizeToJpeg(file)
    const path = `${uid}/${goalId}.jpg`
    const { error: e } = await supabase.storage.from(PHOTO_BUCKET).upload(path, jpg, { upsert: true, contentType: 'image/jpeg', cacheControl: '60' })
    if (e) throw e
    const { data } = await supabase.storage.from(PHOTO_BUCKET).createSignedUrl(path, 60 * 60 * 6)
    if (data?.signedUrl) setSigned((s) => ({ ...s, [path]: `${data.signedUrl}&v=${Date.now()}` }))
    return path
  }, [mode, uid])

  const removeStoredPhoto = useCallback(async (g: Goal) => {
    if (supabase && mode === 'remote' && g.photo_url && !g.photo_url.startsWith('http')) {
      await supabase.storage.from(PHOTO_BUCKET).remove([g.photo_url])
    }
  }, [mode])

  // ── cele ──
  const writeGoal = useCallback(async (g: Goal, isNew: boolean) => {
    if (mode === 'local') {
      setGoals((prev) => {
        const next = isNew ? [...prev, g] : prev.map((x) => (x.id === g.id ? g : x))
        persistLocal({ goals: next })
        return next
      })
      return
    }
    if (!supabase) return
    const row = { id: g.id, name: g.name, target_amount: g.target_amount, photo_url: g.photo_url, photo_position: g.photo_position, catalog_id: g.catalog_id, is_default: g.is_default, deleted_at: g.deleted_at }
    const { data, error: e } = isNew
      ? await supabase.from('goals').insert(row).select().single()
      : await supabase.from('goals').update(row).eq('id', g.id).select().single()
    if (e) throw e
    const saved = numGoal(data as Goal)
    setGoals((prev) => (isNew ? [...prev, saved] : prev.map((x) => (x.id === saved.id ? saved : x))))
  }, [mode, persistLocal])

  const createGoal = useCallback(async (d: GoalDraft, makeDefault?: boolean) => {
    const id = uuid()
    const first = goals.filter((g) => !g.deleted_at).length === 0
    let photo_url: string | null = null
    if (d.photoFile) photo_url = await storePhoto(id, d.photoFile)
    else if (d.photoLink) photo_url = d.photoLink
    const g: Goal = {
      id, name: d.name.trim(), target_amount: d.target_amount, photo_url, photo_position: d.photo_position ?? '50% 50%',
      catalog_id: d.catalog_id, is_default: first, created_at: nowIso(), updated_at: nowIso(), deleted_at: null,
    }
    await writeGoal(g, true)
    if (makeDefault && !first) await setDefaultGoalInner(id)
    return g
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [goals, storePhoto, writeGoal])

  const updateGoal = useCallback(async (id: string, d: Partial<GoalDraft>) => {
    const cur = goals.find((g) => g.id === id)
    if (!cur) return
    let photo_url = cur.photo_url
    if (d.removePhoto) {
      await removeStoredPhoto(cur)
      photo_url = null
    }
    if (d.photoFile) photo_url = await storePhoto(id, d.photoFile)
    else if (d.photoLink) {
      if (cur.photo_url && !cur.photo_url.startsWith('http')) await removeStoredPhoto(cur)
      photo_url = d.photoLink
    }
    const g: Goal = {
      ...cur,
      name: d.name !== undefined ? d.name.trim() : cur.name,
      catalog_id: d.catalog_id !== undefined ? d.catalog_id : cur.catalog_id,
      photo_position: d.photo_position ?? cur.photo_position,
      photo_url,
      updated_at: nowIso(),
    }
    await writeGoal(g, false)
  }, [goals, removeStoredPhoto, storePhoto, writeGoal])

  const setPhotoPosition = useCallback(async (id: string, pos: string) => {
    const cur = goals.find((g) => g.id === id)
    if (!cur || cur.photo_position === pos) return
    await writeGoal({ ...cur, photo_position: pos, updated_at: nowIso() }, false)
  }, [goals, writeGoal])

  const changePrice = useCallback(async (id: string, price: number) => {
    const cur = goals.find((g) => g.id === id)
    if (!cur) return
    await writeGoal({ ...cur, target_amount: price, updated_at: nowIso() }, false)
  }, [goals, writeGoal])

  async function setDefaultGoalInner(id: string) {
    if (mode === 'local' || !supabase) {
      setGoals((prev) => {
        const next = prev.map((g) => ({ ...g, is_default: g.id === id }))
        persistLocal({ goals: next })
        return next
      })
      return
    }
    const { error: e } = await supabase.rpc('set_default_goal', { p_goal_id: id })
    if (e) throw e
    setGoals((prev) => prev.map((g) => ({ ...g, is_default: g.id === id })))
  }
  const setDefaultGoal = useCallback(setDefaultGoalInner, [mode, persistLocal]) // eslint-disable-line react-hooks/exhaustive-deps

  const deleteGoal = useCallback(async (id: string) => {
    const cur = goals.find((g) => g.id === id)
    if (!cur) return
    const ts = nowIso()
    const rest = goals.filter((g) => g.id !== id)
    if (mode === 'local' || !supabase) {
      const nextGoals = rest.map((g, i) => (cur.is_default && i === 0 ? { ...g, is_default: true } : g))
      const nextDeps = deposits.filter((d) => d.goal_id !== id)
      setGoals(nextGoals)
      setDeposits(nextDeps)
      persistLocal({ goals: nextGoals, deposits: nextDeps })
      return
    }
    await removeStoredPhoto(cur)
    const { error: e1 } = await supabase.from('deposits').update({ deleted_at: ts }).eq('goal_id', id).is('deleted_at', null)
    if (e1) throw e1
    const { error: e2 } = await supabase.from('goals').update({ deleted_at: ts, is_default: false, photo_url: null }).eq('id', id)
    if (e2) throw e2
    setGoals(rest)
    setDeposits((prev) => prev.filter((d) => d.goal_id !== id))
    if (cur.is_default && rest[0]) await setDefaultGoalInner(rest[0].id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [goals, deposits, mode, persistLocal, removeStoredPhoto])

  // ── wpłaty ──
  const saveDeposit = useCallback(async (d: { id?: string; goal_id: string; amount: number; deposit_date: string; note: string | null }) => {
    if (d.amount < 0) {
      const bal = goalBalance(deposits, d.goal_id, d.id)
      if (bal + d.amount < -0.001) throw new Error('withdrawal_exceeds_balance')
    }
    const existing = d.id ? deposits.find((x) => x.id === d.id) : undefined
    const row: Deposit = existing
      ? { ...existing, amount: d.amount, deposit_date: d.deposit_date, note: d.note, goal_id: d.goal_id, updated_at: nowIso() }
      : { id: uuid(), goal_id: d.goal_id, amount: d.amount, deposit_date: d.deposit_date, note: d.note, created_at: nowIso(), updated_at: nowIso(), deleted_at: null }
    if (mode === 'local' || !supabase) {
      const next = existing ? deposits.map((x) => (x.id === row.id ? row : x)) : [...deposits, row]
      setDeposits(next)
      persistLocal({ deposits: next })
      return
    }
    const payload = { id: row.id, goal_id: row.goal_id, amount: row.amount, deposit_date: row.deposit_date, note: row.note }
    const { data, error: e } = existing
      ? await supabase.from('deposits').update(payload).eq('id', row.id).select().single()
      : await supabase.from('deposits').insert(payload).select().single()
    if (e) throw e
    const saved = numDep(data as Deposit)
    setDeposits((prev) => (existing ? prev.map((x) => (x.id === saved.id ? saved : x)) : [...prev, saved]))
  }, [deposits, mode, persistLocal])

  const deleteDeposit = useCallback(async (id: string) => {
    const target = deposits.find((d) => d.id === id)
    if (!target) return
    // usunięcie wpłaty nie może zostawić ujemnego salda
    if (target.amount > 0 && goalBalance(deposits, target.goal_id, id) < -0.001) throw new Error('withdrawal_exceeds_balance')
    if (mode === 'local' || !supabase) {
      const next = deposits.filter((d) => d.id !== id)
      setDeposits(next)
      persistLocal({ deposits: next })
      return
    }
    const { error: e } = await supabase.from('deposits').update({ deleted_at: nowIso() }).eq('id', id)
    if (e) throw e
    setDeposits((prev) => prev.filter((d) => d.id !== id))
  }, [deposits, mode, persistLocal])

  // ── eksport / usunięcie ──
  const exportJson = useCallback(() => {
    const payload = {
      app: 'macbook progress',
      exported_at: nowIso(),
      account: mode === 'remote' ? { email } : null,
      profile,
      goals: goals.map((g) => ({ ...g, photo_url: g.photo_url?.startsWith('data:') ? '(lokalne zdjęcie)' : g.photo_url })),
      deposits,
    }
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' })
    const a = document.createElement('a')
    a.href = URL.createObjectURL(blob)
    a.download = `macbook-progress-${new Date().toISOString().slice(0, 10)}.json`
    a.click()
    setTimeout(() => URL.revokeObjectURL(a.href), 1000)
  }, [mode, email, profile, goals, deposits])

  const deleteAccount = useCallback(async () => {
    if (mode === 'local' || !supabase || !uid) {
      writeLocal({ profile: { display_name: '', onboarded: false }, goals: [], deposits: [] })
      localStorage.removeItem(LOCAL_MODE_KEY)
      setGoals([])
      setDeposits([])
      setProfile({ display_name: '', onboarded: false })
      setMode(supabase ? 'signedOut' : 'local')
      return
    }
    const { data: files } = await supabase.storage.from(PHOTO_BUCKET).list(uid, { limit: 1000 })
    if (files?.length) await supabase.storage.from(PHOTO_BUCKET).remove(files.map((f) => `${uid}/${f.name}`))
    const { error: e } = await supabase.rpc('delete_account')
    if (e) throw e
    await supabase.auth.signOut()
    setMode('signedOut')
  }, [mode, uid])

  const reload = useCallback(async () => {
    await loadPublic()
    if (mode === 'remote' && uid) await loadRemote(uid)
  }, [loadPublic, loadRemote, mode, uid])

  const api = useMemo<DataApi>(() => ({
    mode, email, profile, goals, deposits, catalog, config, error, photoSrc,
    signIn, signUp, useLocal, signOut, updateProfile, createGoal, updateGoal, setPhotoPosition, changePrice,
    deleteGoal, setDefaultGoal, saveDeposit, deleteDeposit, exportJson, deleteAccount, reload,
  }), [mode, email, profile, goals, deposits, catalog, config, error, photoSrc, signIn, signUp, useLocal, signOut, updateProfile,
    createGoal, updateGoal, setPhotoPosition, changePrice, deleteGoal, setDefaultGoal, saveDeposit, deleteDeposit, exportJson, deleteAccount, reload])

  return <Ctx.Provider value={api}>{children}</Ctx.Provider>
}
