/**
 * Stato "nessun turno aperto": il database non ha un turno con blocco nel futuro
 * (`open_round_number()` è NULL). Non è un errore: succede tra un turno e il
 * successivo se il calendario non è ancora stato pubblicato.
 */
export function WaitingNextRound() {
  return (
    <div className="card" style={{ padding: 18, display: 'flex', flexDirection: 'column', gap: 8 }}>
      <span style={{ font: '600 10.5px/1 var(--font-mono)', letterSpacing: '.12em', color: 'var(--color-text-secondary)' }}>SERIE A</span>
      <span style={{ fontFamily: 'var(--font-heading)', fontSize: 18, lineHeight: 1.2 }}>In attesa del prossimo turno</span>
      <p style={{ margin: 0, fontSize: 13, lineHeight: 1.4, color: 'var(--color-text-secondary)' }}>
        Al momento nessuna giornata è aperta ai pronostici. La prossima comparirà qui appena sarà pubblicata.
      </p>
    </div>
  );
}
