import { useState } from 'react';
import { PageHeader } from '../../components/PageHeader';
import { LockIcon, GlobeIcon, CheckCircleIcon, MinusIcon, PlusIcon } from '../../components/icons';

export function LegheCrea() {
  const [name, setName] = useState('');
  const [isPrivate, setIsPrivate] = useState(true);
  const [description, setDescription] = useState('');
  const [maxMembers, setMaxMembers] = useState(30);

  return (
    <div className="page">
      <PageHeader title="Crea lega" />

      <div className="page-scroll">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="section-label">NOME LEGA</span>
          <div className="card" style={{ borderWidth: 1.5, borderColor: 'var(--color-primary)', padding: '15px 16px', display: 'flex', alignItems: 'center', gap: 10, minHeight: 52 }}>
            <input
              value={name}
              onChange={(e) => setName(e.target.value.slice(0, 30))}
              placeholder="Es. Amici del lunedì"
              style={{ flex: 1, minWidth: 0, border: 'none', outline: 'none', background: 'transparent', fontFamily: 'var(--font-heading)', fontSize: 16, color: 'var(--color-text-primary)' }}
            />
            <span style={{ flex: 'none', font: '400 10px/1 var(--font-mono)', color: 'var(--color-text-secondary)' }}>{name.length}/30</span>
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="section-label">PRIVACY</span>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2,minmax(0,1fr))', gap: 8 }}>
            <div
              onClick={() => setIsPrivate(true)}
              className={isPrivate ? 'card-dark' : 'card'}
              style={{ padding: 15, display: 'flex', flexDirection: 'column', gap: 8, cursor: 'pointer' }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
                <LockIcon color={isPrivate ? 'var(--color-accent)' : 'var(--color-text-primary)'} />
                {isPrivate ? <CheckCircleIcon /> : <span style={{ width: 18, height: 18, borderRadius: 99, border: '1.8px solid var(--color-border)', display: 'block' }} />}
              </div>
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: 14 }}>Privata</span>
              <span style={{ fontSize: 11, lineHeight: 1.35, color: isPrivate ? '#A9B4CC' : 'var(--color-text-secondary)' }}>Si entra solo con il codice invito</span>
            </div>
            <div
              onClick={() => setIsPrivate(false)}
              className={!isPrivate ? 'card-dark' : 'card'}
              style={{ padding: 15, display: 'flex', flexDirection: 'column', gap: 8, cursor: 'pointer' }}
            >
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
                <GlobeIcon color={!isPrivate ? 'var(--color-accent)' : 'var(--color-text-primary)'} />
                {!isPrivate ? <CheckCircleIcon /> : <span style={{ width: 18, height: 18, borderRadius: 99, border: '1.8px solid var(--color-border)', display: 'block' }} />}
              </div>
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: 14 }}>Pubblica</span>
              <span style={{ fontSize: 11, lineHeight: 1.35, color: !isPrivate ? '#A9B4CC' : 'var(--color-text-secondary)' }}>Visibile a tutti in Esplora</span>
            </div>
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, padding: '0 4px' }}>
            <span className="section-label" style={{ padding: 0 }}>DESCRIZIONE BREVE</span>
            <span className="badge-neutral" style={{ background: '#E4E9F4' }}>SOLO SE PUBBLICA</span>
          </div>
          <div style={{ background: isPrivate ? 'var(--color-bg)' : 'var(--color-surface)', border: `1.5px dashed ${isPrivate ? '#C6CEE0' : 'var(--color-border)'}`, borderRadius: 16, padding: '14px 16px', display: 'flex', flexDirection: 'column', gap: 8, minHeight: 76 }}>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value.slice(0, 90))}
              disabled={isPrivate}
              placeholder="Descrivi la tua lega in una riga, così chi cerca capisce di cosa si tratta."
              rows={2}
              style={{ resize: 'none', border: 'none', outline: 'none', background: 'transparent', fontSize: 13.5, lineHeight: 1.4, color: isPrivate ? 'var(--color-text-secondary)' : 'var(--color-text-primary)', fontFamily: 'inherit' }}
            />
            <span style={{ font: '400 10px/1 var(--font-mono)', color: 'var(--color-text-secondary)', alignSelf: 'flex-end' }}>{description.length}/90</span>
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7, padding: '0 4px' }}>
            <span className="section-label" style={{ padding: 0 }}>MASSIMO PARTECIPANTI</span>
            <span className="badge-neutral" style={{ background: '#E4E9F4' }}>OPZIONALE</span>
          </div>
          <div className="card" style={{ padding: '11px 14px', display: 'flex', alignItems: 'center', gap: 12, minHeight: 52 }}>
            <div
              onClick={() => setMaxMembers((m) => Math.max(2, m - 1))}
              style={{ flex: 'none', width: 40, height: 40, borderRadius: 12, background: 'var(--color-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}
            >
              <MinusIcon />
            </div>
            <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3 }}>
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: 20 }}>{maxMembers}</span>
              <span style={{ font: '600 8.5px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-text-secondary)' }}>PARTECIPANTI</span>
            </div>
            <div
              onClick={() => setMaxMembers((m) => m + 1)}
              style={{ flex: 'none', width: 40, height: 40, borderRadius: 12, background: 'var(--color-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}
            >
              <PlusIcon color="var(--color-text-primary)" />
            </div>
          </div>
          <span style={{ fontSize: 11, lineHeight: 1.35, color: 'var(--color-text-secondary)', padding: '0 4px' }}>Lascia vuoto per non impostare un limite.</span>
        </div>

        <div style={{ paddingTop: 4 }}>
          <button className="btn btn-primary" style={{ width: '100%' }} disabled={!name.trim()}>
            Crea lega
          </button>
        </div>
      </div>
    </div>
  );
}
