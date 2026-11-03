import type { SVGProps } from 'react'

type P = SVGProps<SVGSVGElement> & { size?: number }

const base = (size = 16): SVGProps<SVGSVGElement> => ({
  width: size,
  height: size,
  viewBox: '0 0 16 16',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.5,
  strokeLinecap: 'round',
  strokeLinejoin: 'round',
  'aria-hidden': true,
})

/** otwarty MacBook — obrys (ikona „Start” i znak aplikacji) */
export const LaptopIcon = ({ size, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <rect x="3" y="3.25" width="10" height="7" rx="1" />
    <path d="M1.25 12.25h13.5l-.75 1H2z" />
  </svg>
)

export const ArrowsIcon = ({ size, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M5 13V3M2.5 5.5 5 3l2.5 2.5M11 3v10M8.5 10.5 11 13l2.5-2.5" />
  </svg>
)

export const FlagIcon = ({ size, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M3.5 14V2.5M3.5 3h8.5l-1.75 3 1.75 3H3.5" />
  </svg>
)

export const SlidersIcon = ({ size, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M2.5 4.5h7M12.5 4.5h1M2.5 11.5h1M6.5 11.5h7" />
    <circle cx="11" cy="4.5" r="1.5" />
    <circle cx="5" cy="11.5" r="1.5" />
  </svg>
)

export const MenuIcon = ({ size, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M2.5 5h11M2.5 11h11" />
  </svg>
)

export const CloseIcon = ({ size, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M4 4l8 8M12 4l-8 8" />
  </svg>
)

export const PlusIcon = ({ size, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M8 3v10M3 8h10" />
  </svg>
)

export const StarIcon = ({ size, filled, ...p }: P & { filled?: boolean }) => (
  <svg {...base(size)} {...p} fill={filled ? 'currentColor' : 'none'}>
    <path d="M8 1.9l1.85 3.85 4.2.55-3.07 2.92.78 4.17L8 11.35l-3.76 2.04.78-4.17L1.95 6.3l4.2-.55z" />
  </svg>
)

export const PencilIcon = ({ size, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M10.5 2.5l3 3L6 13H3v-3z" />
  </svg>
)

export const TrashIcon = ({ size, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M2.5 4.5h11M6.5 4.5V2.75h3V4.5M4 4.5l.6 9h6.8l.6-9" />
  </svg>
)

export const ImageIcon = ({ size, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <rect x="2" y="3" width="12" height="10" rx="1.5" />
    <circle cx="6" cy="6.5" r="1.25" />
    <path d="M2.5 11.5l3.5-3 2.5 2 2-1.5 3 2.5" />
  </svg>
)

export const SearchIcon = ({ size, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <circle cx="7" cy="7" r="4.25" />
    <path d="M10.25 10.25 13.5 13.5" />
  </svg>
)

export const MoveIcon = ({ size, ...p }: P) => (
  <svg {...base(size)} {...p}>
    <path d="M8 1.75v12.5M1.75 8h12.5M6 3.75 8 1.75l2 2M6 12.25l2 2 2-2M3.75 6l-2 2 2 2M12.25 6l2 2-2 2" />
  </svg>
)

/** znak produktu: biały obrys MacBooka na czarnym */
export const Mark = ({ size = 28 }: { size?: number }) => (
  <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true">
    <rect width="32" height="32" rx="7" fill="#0a0a0a" />
    <rect x="8.5" y="9" width="15" height="10.5" rx="1.25" fill="none" stroke="#fff" strokeWidth="1.6" />
    <path d="M5.75 22.5h20.5l-1.1 1.5H6.85z" fill="none" stroke="#fff" strokeWidth="1.6" strokeLinejoin="round" />
  </svg>
)
