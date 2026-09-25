import { useId, type ReactNode } from 'react';
import type { CrestPattern } from '../data/mock';

interface IconProps {
  color?: string;
  size?: number;
}

export function HomeIcon({ color = '#5B6785', size = 22 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 22 22" fill="none" stroke={color} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M3.6 9.4 11 3.6l7.4 5.8v8.6h-4.9v-5.4H8.5v5.4H3.6z" />
    </svg>
  );
}

export function PronosticiIcon({ color = '#5B6785', size = 22 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="12" cy="12" r="9.2" />
      <path d="M12 7.4l4.38 3.18-1.68 5.14H9.3l-1.68-5.14z" />
      <path d="M12 7.4V2.8M16.38 10.58l4.37-1.42M14.7 15.72l2.71 3.72M9.3 15.72l-2.71 3.72M7.62 10.58 3.25 9.16" />
    </svg>
  );
}

export function ClassificaIcon({ color = '#5B6785', size = 22 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 22 22" fill="none" stroke={color} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M8.2 6.6h5.6v11.4H8.2z" />
      <path d="M3.2 10.4h5v7.6h-5zM13.8 12.8h5v5.2h-5z" />
    </svg>
  );
}

export function MenuIcon({ color = '#5B6785', size = 22 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 22 22" fill="none" stroke={color} strokeWidth="1.7" strokeLinecap="round" aria-hidden="true">
      <path d="M4.2 7h13.6M4.2 11h13.6M4.2 15h13.6" />
    </svg>
  );
}

export function ChevronDownIcon({ color = '#101A33', size = 13 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M3.4 5.8 8 10.4l4.6-4.6" />
    </svg>
  );
}

export function ChevronRightIcon({ color = '#101A33', size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none" stroke={color} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M5.8 3.2 10.6 8l-4.8 4.8" />
    </svg>
  );
}

export function ChevronRightThinIcon({ color = '#5B6785', size = 8 }: IconProps) {
  return (
    <svg width={size} height="14" viewBox="0 0 8 14" fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M1.6 1.6 6.4 7l-4.8 5.4" />
    </svg>
  );
}

export function BackIcon({ color = '#101A33', size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" fill="none" stroke={color} strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M10.6 3.4 5 9l5.6 5.6" />
    </svg>
  );
}

export function InfoCircleIcon({ color = '#C6FF3D', size = 14 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="none" stroke={color} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="10" cy="10" r="8" />
      <path d="M10 9v5" />
      <path d="M10 6.2v.1" />
    </svg>
  );
}

export function CheckIcon({ color = '#101A33', size = 10 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 12 12" fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M2 6.4 4.7 9 10 3.4" />
    </svg>
  );
}

const SHIELD_PATH = 'M2 3h36v22c0 11-11.5 16.5-18 19C13.5 41.5 2 36 2 25z';

interface CrestProps {
  size?: number;
  accent?: string;
  base?: string;
  pattern?: CrestPattern;
}

export function ShieldCrest({ size = 36, accent = '#C6FF3D', base = '#101A33', pattern = 'star' }: CrestProps) {
  const clipId = useId();
  let inner: ReactNode;

  switch (pattern) {
    case 'stripes':
      inner = (
        <g clipPath={`url(#${clipId})`}>
          <rect x="9" y="0" width="6" height="46" fill={accent} />
          <rect x="25" y="0" width="6" height="46" fill={accent} />
        </g>
      );
      break;
    case 'band':
      inner = (
        <>
          <path d="M2 3h36v11H2z" fill={accent} />
          <circle cx="20" cy="26" r="6.5" fill="none" stroke={accent} strokeWidth="2.4" />
        </>
      );
      break;
    case 'leaf':
      inner = (
        <>
          <path d="M2 25c0 11 11.5 16.5 18 19 6.5-2.5 18-8 18-19z" fill={accent} />
          <path d="M20 8.5l3.2 6.6L20 21.7l-3.2-6.6z" fill="#fff" />
        </>
      );
      break;
    case 'diamond':
      inner = <path d="M20 6.5 33 19.5 20 32.5 7 19.5z" fill={accent} />;
      break;
    case 'arrow':
      inner = <path d="M20 7.5 31.5 25h-8v9h-7v-9h-8z" fill={accent} />;
      break;
    case 'compass':
      inner = (
        <>
          <circle cx="20" cy="22" r="9.5" fill={accent} />
          <path d="M20 15.4l3.6 2.6-1.4 4.3h-4.4L16.4 18z" fill={base} />
          <path d="M20 15.4v-3.8M23.6 18l3.6-1.2M22.2 22.3l2.2 3.1M17.8 22.3l-2.2 3.1M16.4 18l-3.6-1.2" stroke={base} strokeWidth="1.5" strokeLinecap="round" />
        </>
      );
      break;
    case 'quarters':
      inner = (
        <g clipPath={`url(#${clipId})`}>
          <rect x="0" y="0" width="20" height="23" fill={accent} />
          <rect x="20" y="23" width="20" height="23" fill={accent} />
        </g>
      );
      break;
    default:
      inner = <path d="M20 12.6l2.9 5.9 6.5.95-4.7 4.6 1.1 6.45L20 27.45l-5.8 3.05 1.1-6.45-4.7-4.6 6.5-.95z" fill={accent} />;
  }

  return (
    <svg width={size} height={size * 1.15} viewBox="0 0 40 46" aria-hidden="true">
      <defs>
        <clipPath id={clipId}>
          <path d={SHIELD_PATH} />
        </clipPath>
      </defs>
      <path d={SHIELD_PATH} fill={base} />
      <path d="M20 3h18v22c0 11-11.5 16.5-18 19z" fill="#1B2745" />
      {inner}
    </svg>
  );
}

export function SearchIcon({ color = '#101A33', size = 19 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 22 22" fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="9.8" cy="9.8" r="6.4" />
      <path d="M14.6 14.6l4 4" />
    </svg>
  );
}

export function PlusIcon({ color = '#C6FF3D', size = 20 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" aria-hidden="true">
      <path d="M10 4.4v11.2M4.4 10h11.2" />
    </svg>
  );
}

export function CodeIcon({ color = '#101A33', size = 22 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 22 22" fill="none" stroke={color} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <rect x="2.6" y="6.4" width="16.8" height="9.2" rx="2.4" />
      <path d="M6.6 11h.02M10.4 11h.02M14.2 11h.02" />
    </svg>
  );
}

export function LockIcon({ color = '#C6FF3D', size = 22 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 22 22" fill="none" stroke={color} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M7 9.4V7.2a4 4 0 0 1 8 0v2.2" />
      <rect x="5.4" y="9.4" width="11.2" height="8" rx="2.2" />
    </svg>
  );
}

export function GlobeIcon({ color = '#101A33', size = 22 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 22 22" fill="none" stroke={color} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <circle cx="11" cy="11" r="7.6" />
      <path d="M3.4 11h15.2M11 3.4c2 2.3 3 4.9 3 7.6s-1 5.3-3 7.6c-2-2.3-3-4.9-3-7.6s1-5.3 3-7.6z" />
    </svg>
  );
}

export function ShareIcon({ color = '#101A33', size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M9 12V3.4M5.8 6.2 9 3 12.2 6.2" />
      <path d="M3.6 11.4v2.4a1.6 1.6 0 0 0 1.6 1.6h7.6a1.6 1.6 0 0 0 1.6-1.6v-2.4" />
    </svg>
  );
}

export function FlagIcon({ color = '#101A33', size = 21 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 22 22" fill="none" stroke={color} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M5.4 3.2v15.6" />
      <path d="M5.4 4.2h11.2l-2.4 4 2.4 4H5.4z" />
    </svg>
  );
}

export function CameraIcon({ color = '#101A33', size = 20 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 22 22" fill="none" stroke={color} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <rect x="2.6" y="4.4" width="16.8" height="13.2" rx="2.6" />
      <circle cx="7.8" cy="9" r="1.6" />
      <path d="M3.4 15.2 8.4 11l4 3.2 2.8-2.4 4.4 3.8" />
    </svg>
  );
}

export function EditIcon({ color = '#5B6785', size = 13 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" fill="none" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M11.4 3.2 14.8 6.6 7 14.4 3.2 15.2 4 11.4z" />
    </svg>
  );
}

export function CheckCircleIcon({ color = '#C6FF3D', size = 18 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" fill="none" aria-hidden="true">
      <circle cx="9" cy="9" r="8" fill={color} />
      <path d="M5.6 9.2 8 11.6l4.4-4.6" stroke="#101A33" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

export function GoogleIcon({ size = 18 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" aria-hidden="true">
      <path d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.72v2.26h2.9c1.7-1.57 2.68-3.87 2.68-6.62z" fill="#4285F4" />
      <path d="M9 18c2.43 0 4.47-.8 5.96-2.18l-2.9-2.26c-.8.54-1.84.86-3.06.86-2.35 0-4.34-1.59-5.05-3.72H.9v2.33A9 9 0 0 0 9 18z" fill="#34A853" />
      <path d="M3.95 10.7A5.4 5.4 0 0 1 3.66 9c0-.59.1-1.17.29-1.7V4.97H.9A9 9 0 0 0 0 9c0 1.45.35 2.83.9 4.03z" fill="#FBBC05" />
      <path d="M9 3.58c1.32 0 2.51.46 3.44 1.35l2.58-2.58C13.46.89 11.43 0 9 0A9 9 0 0 0 .9 4.97l3.05 2.33C4.66 5.17 6.65 3.58 9 3.58z" fill="#EA4335" />
    </svg>
  );
}

export function MinusIcon({ color = '#101A33', size = 16 }: IconProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" aria-hidden="true">
      <path d="M4.2 9h9.6" />
    </svg>
  );
}
