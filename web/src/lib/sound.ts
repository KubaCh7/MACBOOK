// Ciche dźwięki przez Web Audio. Bez plików, bez przesady.
let ctx: AudioContext | null = null
let enabled = true

export function setSoundEnabled(on: boolean) {
  enabled = on
}

function ac(): AudioContext | null {
  if (!enabled) return null
  try {
    if (!ctx) ctx = new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)()
    if (ctx.state === 'suspended') void ctx.resume()
    return ctx
  } catch {
    return null
  }
}

function tone(freq: number, start: number, dur: number, gain = 0.05, type: OscillatorType = 'sine') {
  const c = ac()
  if (!c) return
  const t0 = c.currentTime + start
  const o = c.createOscillator()
  const g = c.createGain()
  o.type = type
  o.frequency.setValueAtTime(freq, t0)
  g.gain.setValueAtTime(0.0001, t0)
  g.gain.exponentialRampToValueAtTime(gain, t0 + 0.008)
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur)
  o.connect(g).connect(c.destination)
  o.start(t0)
  o.stop(t0 + dur + 0.02)
}

// jeden klik na gest (kilka wywołań w tej samej chwili = jeden dźwięk)
let last = 0
function once(fn: () => void) {
  const n = performance.now()
  if (n - last < 120) return
  last = n
  fn()
}

export const sound = {
  /** kliknięcie przycisku / zmiana zakładki */
  click: () => once(() => tone(1800, 0, 0.03, 0.025, 'triangle')),
  tab: () => once(() => tone(1200, 0, 0.04, 0.025, 'triangle')),
  /** moneta przy wpłacie */
  coin: () => {
    tone(1568, 0, 0.09, 0.05)
    tone(2093, 0.07, 0.22, 0.045)
  },
  /** nuty w dół przy wypłacie */
  withdraw: () => {
    tone(784, 0, 0.12, 0.04)
    tone(587, 0.1, 0.12, 0.04)
    tone(440, 0.2, 0.2, 0.035)
  },
  /** stuk przy usunięciu */
  remove: () => tone(140, 0, 0.08, 0.08, 'square'),
  /** krótki akord przy dodaniu celu */
  chord: () => {
    tone(523, 0, 0.45, 0.03)
    tone(659, 0.03, 0.45, 0.03)
    tone(784, 0.06, 0.5, 0.03)
  },
}
