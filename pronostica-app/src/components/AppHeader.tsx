import { useState } from 'react';
import { Link } from 'react-router-dom';
import { leagues } from '../data/mock';
import { ChevronDownIcon } from './icons';
import './AppHeader.css';

interface AppHeaderProps {
  selectedLeagueId: string;
  onSelectLeague: (id: string) => void;
}

export function AppHeader({ selectedLeagueId, onSelectLeague }: AppHeaderProps) {
  const [open, setOpen] = useState(false);
  const selected = leagues.find((l) => l.id === selectedLeagueId) ?? leagues[0];

  return (
    <div className="app-header">
      <div className="app-header__row">
        <Link to="/" className="app-header__logo">P!</Link>
        <div className="app-header__selector" onClick={() => setOpen((v) => !v)}>
          <span className="app-header__selector-name">{selected.name}</span>
          <ChevronDownIcon />
        </div>
      </div>

      {open && (
        <div className="app-header__dropdown">
          {leagues.map((l) => (
            <div
              key={l.id}
              className={l.id === selected.id ? 'app-header__dropdown-item app-header__dropdown-item--active' : 'app-header__dropdown-item'}
              onClick={() => {
                onSelectLeague(l.id);
                setOpen(false);
              }}
            >
              <div className="app-header__dropdown-text">
                <span className={l.id === selected.id ? 'app-header__dropdown-name app-header__dropdown-name--active' : 'app-header__dropdown-name'}>
                  {l.name}
                </span>
                <span className="app-header__dropdown-meta">
                  {l.members.toLocaleString('it-IT')} {l.isGeneral ? 'utenti' : 'giocatori'}
                </span>
              </div>
            </div>
          ))}
          <div className="app-header__dropdown-divider" />
          <div className="app-header__dropdown-new">+ Nuova lega</div>
        </div>
      )}
    </div>
  );
}
