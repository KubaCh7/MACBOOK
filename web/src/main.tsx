import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { registerSW } from 'virtual:pwa-register'
import App from './App'
import { DataProvider } from './lib/data'
import { PrefsProvider } from './lib/prefs'
import { sound } from './lib/sound'
import './styles.css'

registerSW({ immediate: true })

// ciche kliknięcie na każdym przycisku, który nie gra własnego dźwięku
document.addEventListener('pointerdown', (e) => {
  const el = (e.target as HTMLElement).closest('button.btn:not(.primary), .icon-btn')
  if (el && !(el as HTMLButtonElement).disabled) sound.click()
})

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <PrefsProvider>
      <DataProvider>
        <App />
      </DataProvider>
    </PrefsProvider>
  </StrictMode>,
)
