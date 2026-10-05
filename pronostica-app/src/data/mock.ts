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

/**
 * Calendario reale Serie A 2026/27 (girone unico, 38 giornate, iniziato il
 * 23 agosto 2026), verificato dall'utente giornata per giornata.
 *
 * - 'upcoming'          giornata programmata, non ancora giocata.
 * - 'played'            giocata, risultati verificati per tutte le partite.
 * - 'played-unverified' giocata, ma i risultati non sono stati reperiti/
 *                       verificati (mai fantasia al posto del dato mancante).
 *
 * Giornate 7-38: calendario non ancora disponibile (vedi `SCHEDULE_COMPLETE_THROUGH`).
 */
export const SCHEDULE_COMPLETE_THROUGH = 6;

export interface RealMatch {
  /** Stesso id usato nella tabella `matches` su Supabase (FK di `predictions.match_id`). */
  id: string;
  home: string;
  away: string;
  homeScore: number | null;
  awayScore: number | null;
  /** Il pronostico dell'utente per questa partita: popolato a runtime da Supabase, non da questo file. */
  myPrediction?: string;
}

export type RoundStatus = 'upcoming' | 'played' | 'played-unverified';

export interface SerieARound {
  number: number;
  dateRangeLabel: string;
  status: RoundStatus;
  /** Solo per 'played-unverified': quante partite mancano rispetto alle 10 di una giornata regolare. */
  missingMatches?: number;
  matches: RealMatch[];
  /** Riepilogo punteggio dell'utente per la giornata (valorizzato solo dopo che ha pronosticato). */
  fantasyDemo?: { points: number; average: number; diff: number; progress: number };
}

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

/** Punteggio da regolamento: 3=risultato esatto, 1=solo esito corretto, 0=pronostico sbagliato. */
export function fantasyPointsForMatch(m: RealMatch): number | null {
  if (!m.myPrediction || m.homeScore === null || m.awayScore === null) return null;
  const [ph, pa] = m.myPrediction.split('-').map(Number);
  if (ph === m.homeScore && pa === m.awayScore) return 3;
  const realOutcome = Math.sign(m.homeScore - m.awayScore);
  const predOutcome = Math.sign(ph - pa);
  return realOutcome === predOutcome ? 1 : 0;
}

export const serieARounds: SerieARound[] = [
  {
    number: 1,
    dateRangeLabel: '22–24 agosto 2026',
    status: 'played-unverified',
    matches: [
      { id: 'r1-atalanta-sassuolo', home: 'Atalanta', away: 'Sassuolo', homeScore: null, awayScore: null },
      { id: 'r1-bologna-lazio', home: 'Bologna', away: 'Lazio', homeScore: null, awayScore: null },
      { id: 'r1-frosinone-juventus', home: 'Frosinone', away: 'Juventus', homeScore: null, awayScore: null },
      { id: 'r1-genoa-napoli', home: 'Genoa', away: 'Napoli', homeScore: null, awayScore: null },
      { id: 'r1-inter-monza', home: 'Inter', away: 'Monza', homeScore: null, awayScore: null },
      { id: 'r1-parma-cagliari', home: 'Parma', away: 'Cagliari', homeScore: null, awayScore: null },
      { id: 'r1-roma-fiorentina', home: 'Roma', away: 'Fiorentina', homeScore: null, awayScore: null },
      { id: 'r1-torino-milan', home: 'Torino', away: 'Milan', homeScore: null, awayScore: null },
      { id: 'r1-udinese-como', home: 'Udinese', away: 'Como', homeScore: null, awayScore: null },
      { id: 'r1-venezia-lecce', home: 'Venezia', away: 'Lecce', homeScore: null, awayScore: null },
    ],
  },
  {
    number: 2,
    dateRangeLabel: '28–31 agosto 2026',
    status: 'played-unverified',
    matches: [
      { id: 'r2-milan-venezia', home: 'Milan', away: 'Venezia', homeScore: null, awayScore: null },
      { id: 'r2-fiorentina-frosinone', home: 'Fiorentina', away: 'Frosinone', homeScore: null, awayScore: null },
      { id: 'r2-monza-udinese', home: 'Monza', away: 'Udinese', homeScore: null, awayScore: null },
      { id: 'r2-sassuolo-torino', home: 'Sassuolo', away: 'Torino', homeScore: null, awayScore: null },
      { id: 'r2-juventus-parma', home: 'Juventus', away: 'Parma', homeScore: null, awayScore: null },
      { id: 'r2-napoli-como', home: 'Napoli', away: 'Como', homeScore: null, awayScore: null },
      { id: 'r2-cagliari-inter', home: 'Cagliari', away: 'Inter', homeScore: null, awayScore: null },
      { id: 'r2-lecce-roma', home: 'Lecce', away: 'Roma', homeScore: null, awayScore: null },
      { id: 'r2-atalanta-bologna', home: 'Atalanta', away: 'Bologna', homeScore: null, awayScore: null },
      { id: 'r2-lazio-genoa', home: 'Lazio', away: 'Genoa', homeScore: null, awayScore: null },
    ],
  },
  {
    number: 3,
    dateRangeLabel: '4–7 settembre 2026',
    status: 'played',
    matches: [
      { id: 'r3-genoa-como', home: 'Genoa', away: 'Como', homeScore: 1, awayScore: 4 },
      { id: 'r3-fiorentina-torino', home: 'Fiorentina', away: 'Torino', homeScore: 1, awayScore: 2 },
      { id: 'r3-inter-napoli', home: 'Inter', away: 'Napoli', homeScore: 3, awayScore: 2 },
      { id: 'r3-roma-atalanta', home: 'Roma', away: 'Atalanta', homeScore: 2, awayScore: 1 },
      { id: 'r3-frosinone-venezia', home: 'Frosinone', away: 'Venezia', homeScore: 3, awayScore: 2 },
      { id: 'r3-juventus-milan', home: 'Juventus', away: 'Milan', homeScore: 1, awayScore: 1 },
      { id: 'r3-parma-monza', home: 'Parma', away: 'Monza', homeScore: 1, awayScore: 1 },
      { id: 'r3-bologna-sassuolo', home: 'Bologna', away: 'Sassuolo', homeScore: 2, awayScore: 2 },
      { id: 'r3-cagliari-lecce', home: 'Cagliari', away: 'Lecce', homeScore: 1, awayScore: 0 },
      { id: 'r3-udinese-lazio', home: 'Udinese', away: 'Lazio', homeScore: 1, awayScore: 2 },
    ],
  },
  {
    number: 4,
    dateRangeLabel: '11–14 settembre 2026',
    status: 'played',
    matches: [
      { id: 'r4-venezia-fiorentina', home: 'Venezia', away: 'Fiorentina', homeScore: 2, awayScore: 4 },
      { id: 'r4-genoa-frosinone', home: 'Genoa', away: 'Frosinone', homeScore: 1, awayScore: 1 },
      { id: 'r4-lazio-milan', home: 'Lazio', away: 'Milan', homeScore: 2, awayScore: 2 },
      { id: 'r4-atalanta-cagliari', home: 'Atalanta', away: 'Cagliari', homeScore: 1, awayScore: 2 },
      { id: 'r4-napoli-bologna', home: 'Napoli', away: 'Bologna', homeScore: 1, awayScore: 0 },
      { id: 'r4-sassuolo-juventus', home: 'Sassuolo', away: 'Juventus', homeScore: 3, awayScore: 2 },
      { id: 'r4-lecce-monza', home: 'Lecce', away: 'Monza', homeScore: 3, awayScore: 2 },
      { id: 'r4-torino-roma', home: 'Torino', away: 'Roma', homeScore: 0, awayScore: 2 },
      { id: 'r4-inter-udinese', home: 'Inter', away: 'Udinese', homeScore: 5, awayScore: 3 },
      { id: 'r4-como-parma', home: 'Como', away: 'Parma', homeScore: 2, awayScore: 1 },
    ],
  },
  {
    number: 5,
    dateRangeLabel: '18–20 settembre 2026',
    status: 'played',
    matches: [
      { id: 'r5-monza-sassuolo', home: 'Monza', away: 'Sassuolo', homeScore: 2, awayScore: 1 },
      { id: 'r5-bologna-torino', home: 'Bologna', away: 'Torino', homeScore: 1, awayScore: 1 },
      { id: 'r5-udinese-cagliari', home: 'Udinese', away: 'Cagliari', homeScore: 0, awayScore: 1 },
      { id: 'r5-roma-inter', home: 'Roma', away: 'Inter', homeScore: 2, awayScore: 2 },
      { id: 'r5-venezia-lazio', home: 'Venezia', away: 'Lazio', homeScore: 0, awayScore: 2 },
      { id: 'r5-fiorentina-napoli', home: 'Fiorentina', away: 'Napoli', homeScore: 1, awayScore: 1 },
      { id: 'r5-frosinone-como', home: 'Frosinone', away: 'Como', homeScore: 2, awayScore: 0 },
      { id: 'r5-parma-genoa', home: 'Parma', away: 'Genoa', homeScore: 2, awayScore: 1 },
      { id: 'r5-juventus-atalanta', home: 'Juventus', away: 'Atalanta', homeScore: 2, awayScore: 0 },
      { id: 'r5-milan-lecce', home: 'Milan', away: 'Lecce', homeScore: 3, awayScore: 0 },
    ],
  },
  {
    number: 6,
    dateRangeLabel: '10–12 ottobre 2026',
    status: 'upcoming',
    matches: [
      { id: 'r6-genoa-fiorentina', home: 'Genoa', away: 'Fiorentina', homeScore: null, awayScore: null },
      { id: 'r6-inter-parma', home: 'Inter', away: 'Parma', homeScore: null, awayScore: null },
      { id: 'r6-napoli-frosinone', home: 'Napoli', away: 'Frosinone', homeScore: null, awayScore: null },
      { id: 'r6-como-roma', home: 'Como', away: 'Roma', homeScore: null, awayScore: null },
      { id: 'r6-lazio-monza', home: 'Lazio', away: 'Monza', homeScore: null, awayScore: null },
      { id: 'r6-lecce-bologna', home: 'Lecce', away: 'Bologna', homeScore: null, awayScore: null },
      { id: 'r6-sassuolo-milan', home: 'Sassuolo', away: 'Milan', homeScore: null, awayScore: null },
      { id: 'r6-cagliari-juventus', home: 'Cagliari', away: 'Juventus', homeScore: null, awayScore: null },
      { id: 'r6-atalanta-venezia', home: 'Atalanta', away: 'Venezia', homeScore: null, awayScore: null },
      { id: 'r6-torino-udinese', home: 'Torino', away: 'Udinese', homeScore: null, awayScore: null },
    ],
  },
];

export const currentRoundNumber =
  serieARounds.find((r) => r.status === 'upcoming')?.number ?? serieARounds[serieARounds.length - 1].number;

export const lastPlayedRound = [...serieARounds].reverse().find((r) => r.status === 'played') ?? null;
