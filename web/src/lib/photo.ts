/** "x% y%" <-> {x, y} — wspólny format dla webu, iPhone'a i widżetów */
export function parsePos(s: string | null | undefined): { x: number; y: number } {
  const m = /^\s*([\d.]+)%\s+([\d.]+)%\s*$/.exec(s ?? '')
  if (!m) return { x: 50, y: 50 }
  return { x: clamp(Number(m[1])), y: clamp(Number(m[2])) }
}

export function formatPos(p: { x: number; y: number }): string {
  return `${Math.round(clamp(p.x))}% ${Math.round(clamp(p.y))}%`
}

const clamp = (n: number) => Math.min(100, Math.max(0, Number.isFinite(n) ? n : 50))

/** zmniejsza zdjęcie do JPEG (dłuższy bok max `max` px) */
export async function resizeToJpeg(file: Blob, max = 1600, quality = 0.85): Promise<Blob> {
  const url = URL.createObjectURL(file)
  try {
    const img = await new Promise<HTMLImageElement>((res, rej) => {
      const i = new Image()
      i.onload = () => res(i)
      i.onerror = () => rej(new Error('image'))
      i.src = url
    })
    const scale = Math.min(1, max / Math.max(img.naturalWidth, img.naturalHeight))
    const w = Math.round(img.naturalWidth * scale)
    const h = Math.round(img.naturalHeight * scale)
    const canvas = document.createElement('canvas')
    canvas.width = w
    canvas.height = h
    canvas.getContext('2d')!.drawImage(img, 0, 0, w, h)
    return await new Promise<Blob>((res, rej) => canvas.toBlob((b) => (b ? res(b) : rej(new Error('blob'))), 'image/jpeg', quality))
  } finally {
    URL.revokeObjectURL(url)
  }
}

export function blobToDataUrl(b: Blob): Promise<string> {
  return new Promise((res, rej) => {
    const r = new FileReader()
    r.onload = () => res(String(r.result))
    r.onerror = () => rej(r.error)
    r.readAsDataURL(b)
  })
}
