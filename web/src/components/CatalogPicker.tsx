import { useMemo, useState } from 'react'
import { useI18n } from '../lib/i18n'
import { money } from '../lib/format'
import type { CatalogItem } from '../lib/types'
import { SearchIcon } from './Icons'
import { sound } from '../lib/sound'

type Sort = 'popular' | 'model' | 'price'

export const specLine = (c: CatalogItem) =>
  `${c.chip}${c.gpu_cores ? ` · ${c.gpu_cores}-GPU` : ''} · ${c.memory_gb} GB · ${c.storage_gb >= 1024 ? `${c.storage_gb / 1024} TB` : `${c.storage_gb} GB`}`

export function CatalogPicker({ items, onPick, limit }: { items: CatalogItem[]; onPick: (c: CatalogItem) => void; limit?: number }) {
  const { t, lang } = useI18n()
  const [q, setQ] = useState('')
  const [sort, setSort] = useState<Sort>('popular')
  const list = useMemo(() => {
    const words = q.toLowerCase().split(/\s+/).filter(Boolean)
    const f = items.filter((c) => {
      const hay = `${c.name} ${specLine(c)}`.toLowerCase()
      return words.every((w) => hay.includes(w))
    })
    const s = [...f]
    if (sort === 'popular') s.sort((a, b) => b.popularity - a.popularity)
    if (sort === 'model') s.sort((a, b) => a.name.localeCompare(b.name, 'pl', { numeric: true }) || a.price_pln - b.price_pln)
    if (sort === 'price') s.sort((a, b) => a.price_pln - b.price_pln)
    return limit ? s.slice(0, limit) : s
  }, [items, q, sort, limit])

  return (
    <div className="catalog">
      <div className="catalog-tools">
        <label className="search">
          <SearchIcon size={14} />
          <input type="search" placeholder={t('search')} value={q} onChange={(e) => setQ(e.target.value)} aria-label={t('search')} />
        </label>
        <div className="segmented" role="radiogroup" aria-label="Sort">
          {(['popular', 'model', 'price'] as Sort[]).map((s) => (
            <button key={s} type="button" role="radio" aria-checked={sort === s} className={sort === s ? 'on' : ''} onClick={() => { sound.tab(); setSort(s) }}>
              {s === 'popular' ? t('sortPopular') : s === 'model' ? t('sortModel') : t('sortPrice')}
            </button>
          ))}
        </div>
      </div>
      <ul className="catalog-list">
        {list.map((c) => (
          <li key={c.id}>
            <button type="button" className="catalog-row" onClick={() => { sound.click(); onPick(c) }}>
              <span className="cat-name">
                <span className="strong-line">{c.name}</span>
                <span className="sub-line">{specLine(c)}</span>
              </span>
              <span className="num money">{money(c.price_pln, lang)}</span>
            </button>
          </li>
        ))}
        {!list.length && <li className="empty-line">—</li>}
      </ul>
      <p className="meta">{t('priceNote')}</p>
    </div>
  )
}
