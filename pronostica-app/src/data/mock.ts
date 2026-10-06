export interface League {
  id: string;
  name: string;
  members: number;
  points: number | null;
  position: number | null;
  delta: number | null;
  isGeneral?: boolean;
  isPrivate: boolean;
  code?: string;
  description?: string;
  createdByMe?: boolean;
  maxMembers?: number;
}

/**
 * Classifica generale sospesa fino a gennaio (si riattiva dopo la giornata 19):
 * nessuna voce "sempre presente" in selettore/Leghe finché non si gioca solo
 * in leghe private/pubbliche. Il collegamento reale al database arriva nella
 * fase Leghe successiva.
 */
export const leagues: League[] = [];

export interface LeagueMember {
  position: number;
  name: string;
  points: number;
  initials: string;
  isYou?: boolean;
  isCreator?: boolean;
}

// Nessuna lega privata/pubblica dell'utente allo stato iniziale, quindi nessun elenco membri.
export const leagueMembers: Record<string, LeagueMember[]> = {};

export interface ExploreLeague {
  id: string;
  name: string;
  description: string;
  members: number;
}

export const exploreLeagues: ExploreLeague[] = [
  { id: 'e1', name: 'Lecco Calcio Club', description: 'Tifosi lecchesi, pronostici commentati ogni giornata.', members: 342 },
  { id: 'e2', name: 'Lario Pronostici', description: "Lega aperta del lago: si gioca dalla prima all'ultima giornata.", members: 128 },
  { id: 'e3', name: 'Valle San Martino', description: 'Gruppo di paese, clima tranquillo e nessuna pressione.', members: 57 },
  { id: 'e4', name: 'Lecco Under 25', description: 'Solo giovani, classifica azzerata a metà stagione.', members: 91 },
];

export const crestPatterns = ['star', 'stripes', 'band', 'leaf', 'diamond', 'arrow', 'compass', 'quarters'] as const;
export type CrestPattern = (typeof crestPatterns)[number];

export interface SeasonalPrediction {
  label: string;
  value: string | null;
  points: number | null;
}

/** Pronostici stagionali dell'utente: non ancora scelti finché non chiude il mercato estivo. */
export const seasonalPredictions: SeasonalPrediction[] = [
  { label: 'Vincitore Serie A', value: null, points: null },
  { label: 'Capocannoniere', value: null, points: null },
];

// Calendario (squadre, orari, risultati, stato dei turni): vive SOLO nel
// database (tabelle `matches`/`rounds`, vista `calendar`). Mai duplicato qui:
// vedi src/lib/calendar.ts e src/hooks/useCalendar.ts. Non reintrodurre dati
// di calendario in questo file.
