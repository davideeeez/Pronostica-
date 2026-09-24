import type { CSSProperties, ReactNode } from 'react';
import { PageHeader } from '../../components/PageHeader';

const listStyle: CSSProperties = { margin: 0, paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 4 };

export function Regolamento() {
  return (
    <div className="page">
      <PageHeader title="Regolamento" />

      <div className="page-scroll">
        <a
          href="/regolamento-pronostica.pdf"
          target="_blank"
          rel="noreferrer"
          className="card"
          style={{ padding: '15px 16px', display: 'flex', alignItems: 'center', gap: 11, minHeight: 48, textDecoration: 'none' }}
        >
          <span style={{ flex: 1, minWidth: 0, fontWeight: 600, fontSize: 14 }}>Apri il PDF completo</span>
          <span style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>↗</span>
        </a>

        <Section title="Pronostici pre-campionato">
          <p style={{ margin: '0 0 6px' }}>Prima dell'inizio del campionato ogni partecipante deve indicare:</p>
          <ul style={listStyle}>
            <li>Squadra vincitrice Serie A</li>
            <li>Capocannoniere Serie A</li>
          </ul>
        </Section>

        <Section title="Pronostici turni Serie A">
          <p>Prima dell'inizio di ogni turno di Serie A ogni partecipante deve indicare il risultato di tutte le partite.</p>
        </Section>

        <Section title="Punteggi">
          <ul style={listStyle}>
            <li>Squadra vincitrice Serie A: da 15 a 100 punti</li>
            <li>Capocannoniere Serie A: da 20 a 100 punti</li>
            <li>Risultato esatto partita: 3 punti</li>
            <li>Esito corretto partita (1-X-2) ma risultato sbagliato: 1 punto</li>
            <li>Pronostico errato partita: 0 punti</li>
          </ul>
        </Section>

        <Section title="Modifica dopo metà campionato">
          <p>Al termine delle prime 19 giornate, ogni partecipante può modificare vincitrice Serie A e capocannoniere. Il punteggio in caso di pronostico modificato usa la quota aggiornata dopo la 19ª giornata.</p>
        </Section>

        <Section title="Capocannoniere">
          <p>In caso di pari merito tra più capocannonieri, il pronostico è considerato corretto se il giocatore indicato è tra i capocannonieri ufficiali del torneo.</p>
        </Section>

        <Section title="In caso di arrivo a pari punti">
          <p style={{ margin: '0 0 6px' }}>La classifica viene determinata, nell'ordine, da:</p>
          <ol style={listStyle}>
            <li>Pronostico corretto della vincitrice della Serie A</li>
            <li>Pronostico corretto del capocannoniere</li>
            <li>Maggior numero di risultati esatti</li>
            <li>Maggior numero di esiti corretti</li>
            <li>Se la parità permane, il premio relativo alle posizioni interessate viene suddiviso equamente</li>
          </ol>
        </Section>
      </div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="card" style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
      <span style={{ fontFamily: 'var(--font-heading)', fontSize: 15 }}>{title}</span>
      <div style={{ fontSize: 13.5, lineHeight: 1.5, color: 'var(--color-text-secondary)' }}>{children}</div>
    </div>
  );
}
