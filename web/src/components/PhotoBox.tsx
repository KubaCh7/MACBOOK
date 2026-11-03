import { useRef, useState, type PointerEvent as RPointerEvent } from 'react'
import { useI18n } from '../lib/i18n'
import { formatPos, parsePos } from '../lib/photo'
import { ImageIcon, LaptopIcon, MoveIcon } from './Icons'

/** Zdjęcie celu w proporcji 4:3 z kadrem ustawianym palcem/myszką (photo_position „x% y%”). */
export function PhotoBox({ src, position, alt, onFile, onLink, onRemove, onPosition, compact }: {
  src: string | null
  position: string
  alt: string
  onFile: (f: File) => void
  onLink: (url: string) => void
  onRemove: () => void
  onPosition: (pos: string) => void
  compact?: boolean
}) {
  const { t } = useI18n()
  const gallery = useRef<HTMLInputElement>(null)
  const camera = useRef<HTMLInputElement>(null)
  const imgRef = useRef<HTMLImageElement>(null)
  const [editing, setEditing] = useState(false)
  const [linkOpen, setLinkOpen] = useState(false)
  const [link, setLink] = useState('')
  const [pos, setPos] = useState(parsePos(position))
  const [lastProp, setLastProp] = useState(position)
  const drag = useRef<{ x: number; y: number; px: number; py: number; ox: number; oy: number } | null>(null)

  if (position !== lastProp) {
    setLastProp(position)
    setPos(parsePos(position))
  }

  const pickFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0]
    e.target.value = ''
    if (f) {
      setPos({ x: 50, y: 50 })
      onFile(f)
    }
  }

  const down = (e: RPointerEvent<HTMLDivElement>) => {
    if (!editing || !imgRef.current) return
    const box = e.currentTarget.getBoundingClientRect()
    const img = imgRef.current
    const scale = Math.max(box.width / img.naturalWidth, box.height / img.naturalHeight)
    e.currentTarget.setPointerCapture(e.pointerId)
    drag.current = {
      x: e.clientX, y: e.clientY, px: pos.x, py: pos.y,
      ox: img.naturalWidth * scale - box.width, oy: img.naturalHeight * scale - box.height,
    }
  }
  const move = (e: RPointerEvent<HTMLDivElement>) => {
    const d = drag.current
    if (!d) return
    const nx = d.ox > 1 ? d.px - ((e.clientX - d.x) / d.ox) * 100 : d.px
    const ny = d.oy > 1 ? d.py - ((e.clientY - d.y) / d.oy) * 100 : d.py
    setPos({ x: Math.min(100, Math.max(0, nx)), y: Math.min(100, Math.max(0, ny)) })
  }
  const up = () => {
    if (!drag.current) return
    drag.current = null
    onPosition(formatPos(pos))
  }
  const nudge = (dx: number, dy: number) => {
    const next = { x: Math.min(100, Math.max(0, pos.x + dx)), y: Math.min(100, Math.max(0, pos.y + dy)) }
    setPos(next)
    onPosition(formatPos(next))
  }

  return (
    <div className={`photo-box${compact ? ' compact' : ''}`}>
      <input ref={gallery} type="file" accept="image/*" hidden onChange={pickFile} />
      <input ref={camera} type="file" accept="image/*" capture="environment" hidden onChange={pickFile} />
      {src ? (
        <div
          className={`photo-frame${editing ? ' editing' : ''}`}
          onPointerDown={down}
          onPointerMove={move}
          onPointerUp={up}
          onPointerCancel={up}
          tabIndex={editing ? 0 : -1}
          aria-label={editing ? t('adjustCrop') : undefined}
          onKeyDown={(e) => {
            if (!editing) return
            const k = { ArrowLeft: [-5, 0], ArrowRight: [5, 0], ArrowUp: [0, -5], ArrowDown: [0, 5] }[e.key]
            if (k) {
              e.preventDefault()
              nudge(k[0], k[1])
            }
          }}
        >
          <img ref={imgRef} src={src} alt={alt} draggable={false} style={{ objectPosition: `${pos.x}% ${pos.y}%` }} />
          {editing && (
            <span className="crop-badge">
              <MoveIcon size={14} />
            </span>
          )}
        </div>
      ) : (
        <button type="button" className="photo-empty" onClick={() => gallery.current?.click()}>
          <LaptopIcon size={32} />
          <span>{t('addPhoto')}</span>
        </button>
      )}
      <div className="photo-actions">
        {src && (
          <button type="button" className={`btn sm${editing ? ' primary' : ''}`} onClick={() => setEditing((v) => !v)}>
            {editing ? t('done') : t('adjustCrop')}
          </button>
        )}
        <button type="button" className="btn sm" onClick={() => gallery.current?.click()}>
          <ImageIcon size={14} /> {t('fromGallery')}
        </button>
        <button type="button" className="btn sm only-touch" onClick={() => camera.current?.click()}>{t('fromCamera')}</button>
        <button type="button" className="btn sm" onClick={() => setLinkOpen((v) => !v)} aria-expanded={linkOpen}>{t('fromLink')}</button>
        {src && (
          <button type="button" className="btn sm ghost" onClick={() => { setEditing(false); onRemove() }}>{t('removePhoto')}</button>
        )}
      </div>
      {linkOpen && (
        <form
          className="joined"
          onSubmit={(e) => {
            e.preventDefault()
            const u = link.trim()
            if (/^https:\/\/\S+$/i.test(u)) {
              setPos({ x: 50, y: 50 })
              onLink(u)
              setLink('')
              setLinkOpen(false)
            }
          }}
        >
          <input type="url" inputMode="url" placeholder={t('linkPlaceholder')} value={link} onChange={(e) => setLink(e.target.value)} aria-label={t('fromLink')} />
          <button type="submit" className="btn">{t('use')}</button>
        </form>
      )}
    </div>
  )
}
