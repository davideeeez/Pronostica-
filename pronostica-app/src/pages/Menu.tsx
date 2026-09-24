import type { CSSProperties } from 'react';
import { Link } from 'react-router-dom';
import { ChevronRightThinIcon } from '../components/icons';

const groups: { label: string; items: { label: string; to?: string; badge?: string }[] }[] = [
  {
    label: 'PERSONALE',
    items: [
      { label: 'Profilo', to: '/menu/profilo' },
      { label: 'Leghe', to: '/menu/leghe' },
      { label: 'Traguardi', badge: 'PRESTO DISPONIBILE' },
    ],
  },
  {
    label: 'INFO',
    items: [{ label: 'Regolamento', to: '/menu/regolamento' }, { label: 'Notifiche' }, { label: 'Tutorial' }],
  },
  {
    label: 'LEGALE',
    items: [{ label: 'Privacy' }, { label: 'Termini e Condizioni' }, { label: 'Contatti / Supporto' }, { label: 'Modifica consenso' }],
  },
];

export function Menu() {
  return (
    <div className="page">
      <div style={{ flex: 'none', padding: '6px 18px 12px', display: 'flex', alignItems: 'center', gap: 12 }}>
        <Link to="/" style={{ flex: 'none', width: 36, height: 36, borderRadius: 11, background: 'var(--color-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-heading)', fontSize: 17, color: 'var(--color-accent)' }}>
          P!
        </Link>
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: 20 }}>Menu</span>
      </div>

      <div className="page-scroll" style={{ gap: 22 }}>
        {groups.map((group) => (
          <div key={group.label} style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <span className="section-label">{group.label}</span>
            <div className="card" style={{ padding: '0 16px', display: 'flex', flexDirection: 'column' }}>
              {group.items.map((item, i) => {
                const content = (
                  <>
                    <span style={{ flex: item.badge ? 'none' : 1, minWidth: 0, fontWeight: 600, fontSize: 14.5, color: 'var(--color-text-primary)' }}>
                      {item.label}
                    </span>
                    {item.badge && <span className="badge-neutral">{item.badge}</span>}
                    {item.badge && <span style={{ flex: 1 }} />}
                    <ChevronRightThinIcon />
                  </>
                );
                const style: CSSProperties = {
                  display: 'flex',
                  alignItems: 'center',
                  gap: 10,
                  padding: '15px 0',
                  minHeight: 48,
                  cursor: 'pointer',
                  borderTop: i === 0 ? 'none' : '1px solid var(--color-bg)',
                  textDecoration: 'none',
                  color: 'inherit',
                };
                return item.to ? (
                  <Link key={item.label} to={item.to} style={style}>
                    {content}
                  </Link>
                ) : (
                  <div key={item.label} style={style}>
                    {content}
                  </div>
                );
              })}
            </div>
          </div>
        ))}

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '2px 4px 0' }}>
          <div style={{ height: 1, background: 'var(--color-border)' }} />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, minHeight: 44 }}>
            <span style={{ font: '400 10px/1 var(--font-mono)', letterSpacing: '.08em', color: 'var(--color-text-secondary)' }}>VERSIONE 1.4.2 (218)</span>
            <span style={{ font: '600 12px/1 var(--font-body)', letterSpacing: '.02em', color: '#C0304A', cursor: 'pointer' }}>Esci</span>
          </div>
        </div>
      </div>
    </div>
  );
}
