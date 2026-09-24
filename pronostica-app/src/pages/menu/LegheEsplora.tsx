import { useState } from 'react';
import { PageHeader } from '../../components/PageHeader';
import { SearchIcon, ShieldCrest } from '../../components/icons';
import { exploreLeagues } from '../../data/mock';

export function LegheEsplora() {
  const [query, setQuery] = useState('lecco');
  const filtered = exploreLeagues.filter((l) => l.name.toLowerCase().includes(query.toLowerCase()));

  return (
    <div className="page">
      <PageHeader title="Esplora leghe" />

      <div className="page-scroll">
        <div className="card" style={{ borderWidth: 1.5, borderColor: 'var(--color-primary)', padding: '0 14px', display: 'flex', alignItems: 'center', gap: 10, minHeight: 52 }}>
          <SearchIcon />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Cerca una lega pubblica"
            style={{ flex: 1, minWidth: 0, border: 'none', outline: 'none', background: 'transparent', fontSize: 14, color: 'var(--color-text-primary)' }}
          />
        </div>

        <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, padding: '0 4px' }}>
          <span className="section-label" style={{ padding: 0 }}>{filtered.length} LEGHE APERTE</span>
          <span style={{ flex: 1, height: 1, background: 'var(--color-border)' }} />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {filtered.map((l) => (
            <div key={l.id} className="card" style={{ padding: '15px 16px', display: 'flex', alignItems: 'center', gap: 12 }}>
              <ShieldCrest size={26} />
              <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 4 }}>
                <span style={{ fontWeight: 600, fontSize: 14, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{l.name}</span>
                <span style={{ fontSize: 11.5, lineHeight: 1.35, color: 'var(--color-text-secondary)' }}>{l.description}</span>
                <span style={{ font: '400 10px/1 var(--font-mono)', letterSpacing: '.05em', color: 'var(--color-text-secondary)' }}>
                  {l.members.toLocaleString('it-IT')} PARTECIPANTI
                </span>
              </div>
              <span className="badge-accent" style={{ flex: 'none', fontFamily: 'var(--font-body)', fontWeight: 600, padding: '14px 13px', minHeight: 44, display: 'flex', alignItems: 'center', cursor: 'pointer' }}>
                Unisciti
              </span>
            </div>
          ))}
          {filtered.length === 0 && (
            <p style={{ color: 'var(--color-text-secondary)', fontSize: 13, textAlign: 'center', padding: '24px 0' }}>Nessuna lega trovata.</p>
          )}
        </div>
      </div>
    </div>
  );
}
