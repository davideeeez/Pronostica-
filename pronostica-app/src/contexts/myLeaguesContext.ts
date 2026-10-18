import { createContext } from 'react';
import type { MyLeague } from '../lib/leagues';

export interface MyLeaguesValue {
  /** Le leghe dell'utente. Vuoto durante il primo caricamento e senza leghe: distinguere con `loading`. */
  leagues: MyLeague[];
  /** True solo finché l'elenco non è mai stato caricato (i ricaricamenti successivi non lo riaccendono). */
  loading: boolean;
  error: string | null;
  /** La lega selezionata, sempre tra le mie leghe; `null` durante il caricamento o se non ne ho. */
  selectedLeague: MyLeague | null;
  /** Cambia la lega selezionata (solo tra le mie leghe) e la salva sul dispositivo. */
  selectLeague: (id: string) => void;
  /** Ricarica l'elenco delle leghe; se la selezionata non c'è più ripiega sulla prima (o su nessuna). */
  refreshLeagues: () => Promise<void>;
}

export const MyLeaguesContext = createContext<MyLeaguesValue | null>(null);
