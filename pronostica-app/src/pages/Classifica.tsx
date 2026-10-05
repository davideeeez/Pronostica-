import { Link } from 'react-router-dom';
import { PlusIcon, CodeIcon, SearchIcon } from '../components/icons';

/**
 * Classifica generale sospesa fino a gennaio: si gioca solo in leghe (private
 * con codice, pubbliche senza). Finché l'utente non è in nessuna lega, questa
 * schermata mostra solo lo stato vuoto con i tre ingressi verso Leghe — niente
 * podio né liste. Il collegamento reale al database delle leghe arriva nella
 * fase successiva.
 */
export function Classifica() {
  return (
    <div className="page">
      <div style={{ flex: 'none', padding: '16px 18px 12px' }}>
        <span style={{ fontFamily: 'var(--font-heading)', fontSize: 20 }}>Classifica</span>
      </div>

      <div className="page-scroll" style={{ justifyContent: 'center', alignItems: 'center', textAlign: 'center' }}>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16, padding: '24px 8px' }}>
          <span style={{ fontFamily: 'var(--font-heading)', fontSize: 19 }}>Non fai ancora parte di nessuna lega</span>
          <p style={{ margin: 0, fontSize: 13.5, lineHeight: 1.5, color: 'var(--color-text-secondary)', maxWidth: 280 }}>
            La classifica generale è sospesa fino a gennaio. Per ora si gioca solo in leghe tra amici o pubbliche.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 9, width: '100%', maxWidth: 280, marginTop: 8 }}>
            <Link to="/menu/leghe/crea" className="btn btn-primary" style={{ gap: 10 }}>
              <PlusIcon color="#101A33" />
              Crea una lega
            </Link>
            <Link to="/menu/leghe" className="btn btn-outline" style={{ gap: 10 }}>
              <CodeIcon color="var(--color-text-primary)" />
              Ho un codice
            </Link>
            <Link to="/menu/leghe/esplora" className="btn btn-outline" style={{ gap: 10 }}>
              <SearchIcon size={18} />
              Esplora leghe pubbliche
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
