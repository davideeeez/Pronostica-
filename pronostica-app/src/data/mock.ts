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
 * Stato iniziale reale: l'utente parte senza leghe private. L'unica voce
 * sempre presente è la classifica generale della piattaforma (nessuna
 * posizione/punteggio personale finché non ha giocato).
 */
export const leagues: League[] = [
  { id: 'gen', name: 'Classifica generale', members: 0, points: null, position: null, delta: null, isGeneral: true, isPrivate: false },
];

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

// Utente nuovo: nessun nome/username ancora impostato, nessuna statistica maturata.
export const currentUser = {
  name: null as string | null,
  username: null as string | null,
  userNumber: null as number | null,
  leaguePoints: 0,
  totalPoints: 0,
  accuracy: 0,
  matchesPredicted: 0,
  exactResults: 0,
  correctOutcomes: 0,
  crestPattern: 'star' as CrestPattern,
};

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
  home: string;
  away: string;
  homeScore: number | null;
  awayScore: number | null;
  /** Il pronostico dell'utente per questa partita, se già inserito. */
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
  /**
   * Placeholder statico (non calcolato) per "chiude tra"/countdown, in attesa del
   * countdown reale in una fase futura. Valido solo per il round 'upcoming'.
   */
  closesLabel?: string;
  countdownLabel?: string;
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
      { home: 'Atalanta', away: 'Sassuolo', homeScore: null, awayScore: null },
      { home: 'Bologna', away: 'Lazio', homeScore: null, awayScore: null },
      { home: 'Frosinone', away: 'Juventus', homeScore: null, awayScore: null },
      { home: 'Genoa', away: 'Napoli', homeScore: null, awayScore: null },
      { home: 'Inter', away: 'Monza', homeScore: null, awayScore: null },
      { home: 'Parma', away: 'Cagliari', homeScore: null, awayScore: null },
      { home: 'Roma', away: 'Fiorentina', homeScore: null, awayScore: null },
      { home: 'Torino', away: 'Milan', homeScore: null, awayScore: null },
      { home: 'Udinese', away: 'Como', homeScore: null, awayScore: null },
      { home: 'Venezia', away: 'Lecce', homeScore: null, awayScore: null },
    ],
  },
  {
    number: 2,
    dateRangeLabel: '28–31 agosto 2026',
    status: 'played-unverified',
    missingMatches: 1, // manca l'abbinamento Genoa/Lazio: non riportato dalle fonti trovate, non indovinato
    matches: [
      { home: 'Milan', away: 'Venezia', homeScore: null, awayScore: null },
      { home: 'Fiorentina', away: 'Frosinone', homeScore: null, awayScore: null },
      { home: 'Monza', away: 'Udinese', homeScore: null, awayScore: null },
      { home: 'Sassuolo', away: 'Torino', homeScore: null, awayScore: null },
      { home: 'Juventus', away: 'Parma', homeScore: null, awayScore: null },
      { home: 'Napoli', away: 'Como', homeScore: null, awayScore: null },
      { home: 'Cagliari', away: 'Inter', homeScore: null, awayScore: null },
      { home: 'Lecce', away: 'Roma', homeScore: null, awayScore: null },
      { home: 'Atalanta', away: 'Bologna', homeScore: null, awayScore: null },
    ],
  },
  {
    number: 3,
    dateRangeLabel: '4–7 settembre 2026',
    status: 'played',
    matches: [
      { home: 'Genoa', away: 'Como', homeScore: 1, awayScore: 4 },
      { home: 'Fiorentina', away: 'Torino', homeScore: 1, awayScore: 2 },
      { home: 'Inter', away: 'Napoli', homeScore: 3, awayScore: 2 },
      { home: 'Roma', away: 'Atalanta', homeScore: 2, awayScore: 1 },
      { home: 'Frosinone', away: 'Venezia', homeScore: 3, awayScore: 2 },
      { home: 'Juventus', away: 'Milan', homeScore: 1, awayScore: 1 },
      { home: 'Parma', away: 'Monza', homeScore: 1, awayScore: 1 },
      { home: 'Bologna', away: 'Sassuolo', homeScore: 2, awayScore: 2 },
      { home: 'Cagliari', away: 'Lecce', homeScore: 1, awayScore: 0 },
      { home: 'Udinese', away: 'Lazio', homeScore: 1, awayScore: 2 },
    ],
  },
  {
    number: 4,
    dateRangeLabel: '11–14 settembre 2026',
    status: 'played',
    matches: [
      { home: 'Venezia', away: 'Fiorentina', homeScore: 2, awayScore: 4 },
      { home: 'Genoa', away: 'Frosinone', homeScore: 1, awayScore: 1 },
      { home: 'Lazio', away: 'Milan', homeScore: 2, awayScore: 2 },
      { home: 'Atalanta', away: 'Cagliari', homeScore: 1, awayScore: 2 },
      { home: 'Napoli', away: 'Bologna', homeScore: 1, awayScore: 0 },
      { home: 'Sassuolo', away: 'Juventus', homeScore: 3, awayScore: 2 },
      { home: 'Lecce', away: 'Monza', homeScore: 3, awayScore: 2 },
      { home: 'Torino', away: 'Roma', homeScore: 0, awayScore: 2 },
      { home: 'Inter', away: 'Udinese', homeScore: 5, awayScore: 3 },
      { home: 'Como', away: 'Parma', homeScore: 2, awayScore: 1 },
    ],
  },
  {
    number: 5,
    dateRangeLabel: '18–20 settembre 2026',
    status: 'played',
    matches: [
      { home: 'Monza', away: 'Sassuolo', homeScore: 2, awayScore: 1 },
      { home: 'Bologna', away: 'Torino', homeScore: 1, awayScore: 1 },
      { home: 'Udinese', away: 'Cagliari', homeScore: 0, awayScore: 1 },
      { home: 'Roma', away: 'Inter', homeScore: 2, awayScore: 2 },
      { home: 'Venezia', away: 'Lazio', homeScore: 0, awayScore: 2 },
      { home: 'Fiorentina', away: 'Napoli', homeScore: 1, awayScore: 1 },
      { home: 'Frosinone', away: 'Como', homeScore: 2, awayScore: 0 },
      { home: 'Parma', away: 'Genoa', homeScore: 2, awayScore: 1 },
      { home: 'Juventus', away: 'Atalanta', homeScore: 2, awayScore: 0 },
      { home: 'Milan', away: 'Lecce', homeScore: 3, awayScore: 0 },
    ],
  },
  {
    number: 6,
    dateRangeLabel: '10–12 ottobre 2026',
    status: 'upcoming',
    closesLabel: 'VEN 20:45',
    countdownLabel: '04:12:33',
    matches: [
      { home: 'Genoa', away: 'Fiorentina', homeScore: null, awayScore: null },
      { home: 'Inter', away: 'Parma', homeScore: null, awayScore: null },
      { home: 'Napoli', away: 'Frosinone', homeScore: null, awayScore: null },
      { home: 'Como', away: 'Roma', homeScore: null, awayScore: null },
      { home: 'Lazio', away: 'Monza', homeScore: null, awayScore: null },
      { home: 'Lecce', away: 'Bologna', homeScore: null, awayScore: null },
      { home: 'Sassuolo', away: 'Milan', homeScore: null, awayScore: null },
      { home: 'Cagliari', away: 'Juventus', homeScore: null, awayScore: null },
      { home: 'Atalanta', away: 'Venezia', homeScore: null, awayScore: null },
      { home: 'Torino', away: 'Udinese', homeScore: null, awayScore: null },
    ],
  },
];

export const currentRoundNumber =
  serieARounds.find((r) => r.status === 'upcoming')?.number ?? serieARounds[serieARounds.length - 1].number;

export const lastPlayedRound = [...serieARounds].reverse().find((r) => r.status === 'played') ?? null;

export interface LeaderboardEntry {
  position: number;
  name: string;
  points: number;
  delta: number;
  exact: number;
  outcomes: number;
  initials: string;
}

/**
 * Classifica generale: nessun utente ancora iscritto. Man mano che le persone
 * si iscriveranno, questa lista si popolerà in ordine di iscrizione con 0 punti,
 * finché non giocheranno la prima giornata (poi subentra il punteggio da
 * regolamento). Richiede il backend (Fase 2+): per ora resta vuota.
 */
export const generalLeaderboardPodium: LeaderboardEntry[] = [];

export const generalLeaderboardRest: LeaderboardEntry[] = [];

// Nessuna posizione ancora: l'utente non ha pronosticato nulla.
export const yourGeneralPosition = { position: null as number | null, delta: null as number | null, points: 0, exact: 0, outcomes: 0 };
