import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useMyLeagues } from '../hooks/useMyLeagues';
import { ChevronDownIcon, PlusIcon } from './icons';
import './AppHeader.css';

/** Selettore della lega: legge e scrive la lega selezionata dal MyLeaguesProvider (nessuno stato proprio). */
export function AppHeader() {
  const { leagues, selectedLeague: selected, selectLeague: select } = useMyLeagues();
  const [open, setOpen] = useState(false);

  function selectLeague(id: string) {
    select(id);
    setOpen(false);
  }

  return (
    <div className="app-header">
      <div className="app-header__row">
        <Link to="/" className="app-header__logo">P!</Link>
        {selected && (
          <div className="app-header__selector" onClick={() => setOpen((v) => !v)}>
            <span className="app-header__selector-name">{selected.name}</span>
            <ChevronDownIcon />
          </div>
        )}
      </div>

      {open && selected && (
        <div className="app-header__dropdown">
          {leagues.map((l) => (
            <div
              key={l.id}
              className={l.id === selected.id ? 'app-header__dropdown-item app-header__dropdown-item--active' : 'app-header__dropdown-item'}
              onClick={() => selectLeague(l.id)}
            >
              <div className="app-header__dropdown-text">
                <span className={l.id === selected.id ? 'app-header__dropdown-name app-header__dropdown-name--active' : 'app-header__dropdown-name'}>
                  {l.name}
                </span>
                <span className="app-header__dropdown-meta">
                  {l.memberCount.toLocaleString('it-IT')} giocatori
                </span>
              </div>
            </div>
          ))}
          <div className="app-header__dropdown-divider" />
          <Link to="/menu/leghe/crea" className="app-header__dropdown-new" onClick={() => setOpen(false)}>
            <PlusIcon size={14} />
            Nuova lega
          </Link>
        </div>
      )}
    </div>
  );
}
