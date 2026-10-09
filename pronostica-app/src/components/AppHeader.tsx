import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { useMyLeagues } from '../hooks/useMyLeagues';
import { getSelectedLeagueId, setSelectedLeagueId } from '../lib/selectedLeague';
import { ChevronDownIcon, PlusIcon } from './icons';
import './AppHeader.css';

interface AppHeaderProps {
  /** Chiamata quando la lega selezionata è nota o cambia (anche al primo render). */
  onSelectionChange?: (leagueId: string | null) => void;
}

export function AppHeader({ onSelectionChange }: AppHeaderProps) {
  const { session } = useAuth();
  const { leagues } = useMyLeagues(session?.user.id);
  const [open, setOpen] = useState(false);
  const [selectedId, setSelectedId] = useState<string | null>(() => getSelectedLeagueId());

  // Se la lega salvata non è (più) tra quelle dell'utente, ricadi sulla prima disponibile.
  useEffect(() => {
    if (leagues.length === 0) {
      if (selectedId !== null) {
        setSelectedId(null);
        setSelectedLeagueId(null);
      }
      return;
    }
    const stillValid = leagues.some((l) => l.id === selectedId);
    if (!stillValid) {
      const fallback = leagues[0].id;
      setSelectedId(fallback);
      setSelectedLeagueId(fallback);
    }
  }, [leagues, selectedId]);

  useEffect(() => {
    onSelectionChange?.(selectedId);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedId]);

  const selected = leagues.find((l) => l.id === selectedId) ?? null;

  function selectLeague(id: string) {
    setSelectedId(id);
    setSelectedLeagueId(id);
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
