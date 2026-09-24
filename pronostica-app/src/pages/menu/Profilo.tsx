import { useState } from 'react';
import { PageHeader } from '../../components/PageHeader';
import { ShieldCrest, EditIcon, ChevronRightThinIcon, CameraIcon } from '../../components/icons';
import { currentUser, crestPatterns, type CrestPattern } from '../../data/mock';

export function Profilo() {
  const [galleryOpen, setGalleryOpen] = useState(false);
  const [crest, setCrest] = useState<CrestPattern>(currentUser.crestPattern);
  const [draftCrest, setDraftCrest] = useState<CrestPattern>(crest);

  function openGallery() {
    setDraftCrest(crest);
    setGalleryOpen(true);
  }

  return (
    <div className="page">
      <PageHeader title="Profilo" />

      <div className="page-scroll">
        <div className="card" style={{ padding: '20px 16px 18px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
          <div style={{ position: 'relative', cursor: 'pointer' }} onClick={openGallery}>
            <ShieldCrest size={104} pattern={crest} />
            <div style={{ position: 'absolute', right: -4, bottom: 2, width: 32, height: 32, borderRadius: 11, background: 'var(--color-accent)', border: '2.5px solid var(--color-surface)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <EditIcon color="var(--color-text-primary)" size={15} />
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
            <span style={{ fontFamily: 'var(--font-heading)', fontSize: 19, color: currentUser.username ? 'var(--color-text-primary)' : 'var(--color-text-secondary)' }}>
              {currentUser.username ?? 'Imposta un nome utente'}
            </span>
            <EditIcon />
          </div>
          {currentUser.userNumber !== null && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, background: 'var(--color-bg)', border: '1px solid var(--color-border)', borderRadius: 99, padding: '6px 11px' }}>
              <ShieldCrest size={12} pattern={crest} />
              <span style={{ font: '600 10px/1 var(--font-mono)', letterSpacing: '.09em' }}>UTENTE #{currentUser.userNumber}</span>
            </div>
          )}
          <span style={{ font: '600 9px/1 var(--font-mono)', letterSpacing: '.1em', color: 'var(--color-text-secondary)' }}>
            TOCCA LO STEMMA PER CAMBIARLO
          </span>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="section-label">STATISTICHE</span>
          <div style={{ display: 'grid', gridTemplateColumns: '1.35fr 1fr', gap: 8 }}>
            <div className="card-dark" style={{ padding: '14px 16px', display: 'flex', flexDirection: 'column', gap: 5 }}>
              <span style={{ font: '600 9px/1 var(--font-mono)', letterSpacing: '.1em', color: '#A9B4CC' }}>PUNTI TOTALI</span>
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: 30, color: 'var(--color-accent)' }}>{currentUser.totalPoints.toLocaleString('it-IT')}</span>
              <span style={{ fontSize: 11, color: '#A9B4CC' }}>storico completo</span>
            </div>
            <div className="card" style={{ padding: '14px 16px', display: 'flex', flexDirection: 'column', gap: 5 }}>
              <span className="stat-tile__label" style={{ fontSize: 9 }}>PRECISIONE</span>
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: 30 }}>{currentUser.accuracy}%</span>
              <span style={{ fontSize: 11, color: 'var(--color-text-secondary)' }}>esiti indovinati</span>
            </div>
          </div>
          <div className="card" style={{ padding: '2px 16px', display: 'flex', flexDirection: 'column' }}>
            <StatRow label="Hai pronosticato" value={`${currentUser.matchesPredicted} partite`} first />
            <StatRow label="Risultati esatti totali" value={String(currentUser.exactResults)} />
            <StatRow label="Esiti corretti totali" value={String(currentUser.correctOutcomes)} />
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          <span className="section-label">IMPOSTAZIONI</span>
          <div className="card" style={{ padding: '0 16px', display: 'flex', flexDirection: 'column' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '13px 0', minHeight: 48 }}>
              <span style={{ flex: 1, minWidth: 0, fontWeight: 600, fontSize: 14.5 }}>Tema</span>
              <div style={{ flex: 'none', display: 'flex', background: 'var(--color-bg)', borderRadius: 99, padding: 3 }}>
                <span style={{ font: '600 11px/1 var(--font-body)', background: 'var(--color-accent)', borderRadius: 99, padding: '8px 12px', cursor: 'pointer' }}>Chiaro</span>
                <span style={{ font: '600 11px/1 var(--font-body)', color: 'var(--color-text-secondary)', borderRadius: 99, padding: '8px 12px', cursor: 'not-allowed' }} title="In arrivo in una fase successiva">Scuro</span>
              </div>
            </div>
            <MenuRow label="Modifica email e password" />
            <MenuRow label="Elimina account" />
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '2px 4px 0' }}>
          <div style={{ height: 1, background: 'var(--color-border)' }} />
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, minHeight: 44 }}>
            <span style={{ font: '400 10px/1 var(--font-mono)', letterSpacing: '.08em', color: 'var(--color-text-secondary)' }}>VERSIONE 1.4.2 (218)</span>
            <span style={{ font: '600 12px/1 var(--font-body)', letterSpacing: '.02em', color: '#C0304A', cursor: 'pointer' }}>Esci</span>
          </div>
        </div>
      </div>

      {galleryOpen && (
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(16,26,51,.55)', display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', zIndex: 20 }}>
          <div style={{ background: 'var(--color-surface)', borderTop: '1px solid var(--color-border)', borderRadius: '28px 28px 0 0', padding: '12px 18px 22px', display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div style={{ width: 44, height: 4, borderRadius: 3, background: 'var(--color-border)', alignSelf: 'center' }} />
            <div style={{ display: 'flex', flexDirection: 'column', gap: 3 }}>
              <span style={{ fontFamily: 'var(--font-heading)', fontSize: 18 }}>Scegli il tuo stemma</span>
              <span style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>Otto stemmi predefiniti o una tua foto. Puoi cambiarlo quando vuoi.</span>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4,minmax(0,1fr))', gap: 6 }}>
              {crestPatterns.map((p) => {
                const active = p === draftCrest;
                return (
                  <div
                    key={p}
                    onClick={() => setDraftCrest(p)}
                    style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 7, padding: '10px 4px', borderRadius: 16, background: active ? 'var(--color-bg)' : 'transparent', border: active ? '1.5px solid var(--color-primary)' : '1.5px solid transparent', cursor: 'pointer' }}
                  >
                    <ShieldCrest size={52} pattern={p} />
                  </div>
                );
              })}
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ flex: 1, height: 1, background: 'var(--color-bg)' }} />
              <span style={{ font: '600 9px/1 var(--font-mono)', letterSpacing: '.12em', color: 'var(--color-text-secondary)' }}>OPPURE</span>
              <span style={{ flex: 1, height: 1, background: 'var(--color-bg)' }} />
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, border: '1.5px dashed #B9C4DC', borderRadius: 16, padding: '13px 14px', cursor: 'pointer', minHeight: 48 }}>
              <span style={{ flex: 'none', width: 38, height: 38, borderRadius: 11, background: 'var(--color-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <CameraIcon />
              </span>
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 2, minWidth: 0 }}>
                <span style={{ fontFamily: 'var(--font-heading)', fontSize: 13 }}>Scegli una foto dalla galleria</span>
                <span style={{ fontSize: 11.5, color: 'var(--color-text-secondary)' }}>JPG o PNG, ritagliata a forma di stemma</span>
              </div>
              <ChevronRightThinIcon color="var(--color-text-primary)" />
            </div>
            <div style={{ display: 'flex', gap: 10 }}>
              <span
                onClick={() => setGalleryOpen(false)}
                style={{ flex: 'none', font: '600 13px/1 var(--font-body)', background: 'var(--color-bg)', borderRadius: 14, padding: '15px 18px', cursor: 'pointer' }}
              >
                Annulla
              </span>
              <span
                onClick={() => { setCrest(draftCrest); setGalleryOpen(false); }}
                style={{ flex: 1, textAlign: 'center', fontFamily: 'var(--font-heading)', fontSize: 13.5, background: 'var(--color-accent)', borderRadius: 14, padding: '15px 18px', cursor: 'pointer' }}
              >
                Conferma stemma
              </span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function StatRow({ label, value, first }: { label: string; value: string; first?: boolean }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '13px 0', borderTop: first ? 'none' : '1px solid var(--color-bg)' }}>
      <span style={{ flex: 1, minWidth: 0, fontSize: 13.5, color: 'var(--color-text-secondary)' }}>{label}</span>
      <span style={{ fontFamily: 'var(--font-heading)', fontSize: 15 }}>{value}</span>
    </div>
  );
}

function MenuRow({ label }: { label: string }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '15px 0', minHeight: 48, cursor: 'pointer', borderTop: '1px solid var(--color-bg)' }}>
      <span style={{ flex: 1, minWidth: 0, fontWeight: 600, fontSize: 14.5 }}>{label}</span>
      <ChevronRightThinIcon />
    </div>
  );
}
