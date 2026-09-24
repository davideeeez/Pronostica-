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
 * DATI DEMO TEMPORANEI — richiesti esplicitamente per verificare che ogni
 * schermata funzioni prima di tornare allo stato reale "utente nuovo senza
 * leghe" (vedi commit precedente). Da rimuovere quando il test è concluso:
 * cercare "DATI DEMO TEMPORANEI" in questo file.
 */
export const leagues: League[] = [
  { id: 'gen', name: 'Classifica generale', members: 48312, points: 712, position: 1284, delta: 37, isGeneral: true, isPrivate: false },
  { id: 'l1', name: 'Fantabar Lecco', members: 24, points: 712, position: 3, delta: 1, isPrivate: true, code: 'LEC-4K9P', maxMembers: 30 },
  { id: 'l2', name: 'Ufficio Nord', members: 11, points: 640, position: 5, delta: -2, isPrivate: true, code: 'UFN-8B2X', maxMembers: 20 },
  { id: 'l3', name: 'Cugini FC', members: 6, points: 780, position: 1, delta: 3, isPrivate: true, code: 'CUG-3M7Q', maxMembers: 10, createdByMe: true },
  { id: 'pub1', name: 'Curva Nord Italia', members: 1842, points: 712, position: 96, delta: 0, isPrivate: false, description: 'La lega pubblica dei tifosi più accesi, da Nord a Sud.' },
];

export interface LeagueMember {
  position: number;
  name: string;
  points: number;
  initials: string;
  isYou?: boolean;
  isCreator?: boolean;
}

// DATI DEMO TEMPORANEI (vedi nota sopra su `leagues`).
export const leagueMembers: Record<string, LeagueMember[]> = {
  l1: [
    { position: 1, name: 'giuliarossi', points: 764, initials: 'GR', isCreator: true },
    { position: 2, name: 'davide_c', points: 748, initials: 'DC' },
    { position: 3, name: 'marcobianchi_87 (tu)', points: 712, initials: 'MB', isYou: true },
    { position: 4, name: 'saralupo', points: 706, initials: 'SL' },
    { position: 5, name: 'andreap', points: 694, initials: 'AP' },
  ],
  l2: [
    { position: 1, name: 'fedem', points: 701, initials: 'FM', isCreator: true },
    { position: 2, name: 'lucat', points: 668, initials: 'LT' },
    { position: 3, name: 'elenaf', points: 655, initials: 'EF' },
    { position: 4, name: 'nicolos', points: 649, initials: 'NS' },
    { position: 5, name: 'marcobianchi_87 (tu)', points: 640, initials: 'MB', isYou: true },
  ],
  l3: [
    { position: 1, name: 'marcobianchi_87 (tu)', points: 780, initials: 'MB', isYou: true, isCreator: true },
    { position: 2, name: 'paolod', points: 741, initials: 'PD' },
    { position: 3, name: 'martinag', points: 719, initials: 'MG' },
  ],
  pub1: [
    { position: 1, name: 'lucafontana', points: 861, initials: 'LF' },
    { position: 2, name: 'elemarini', points: 854, initials: 'EM' },
    { position: 3, name: 'robibrambilla', points: 849, initials: 'RB' },
    { position: 4, name: 'silviav_90', points: 843, initials: 'SV' },
    { position: 5, name: 'tommygalli', points: 840, initials: 'TG' },
    { position: 96, name: 'marcobianchi_87 (tu)', points: 712, initials: 'MB', isYou: true },
  ],
};

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

// DATI DEMO TEMPORANEI (vedi nota sopra su `leagues`).
export const currentUser = {
  name: 'Marco Rossi' as string | null,
  username: 'marcobianchi_87' as string | null,
  userNumber: 312 as number | null,
  leaguePoints: 1240,
  totalPoints: 3412,
  accuracy: 68,
  matchesPredicted: 760,
  exactResults: 183,
  correctOutcomes: 437,
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
  /** DATO DEMO TEMPORANEO: pronostico finto dell'utente, per testare la UI "fatto/da fare". */
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
  /** DATO DEMO TEMPORANEO: riepilogo fantasy-pronostico per la giornata (solo rounds 'played'). */
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

/** DATI DEMO TEMPORANEI (vedi nota sopra su `leagues`): pronostici stagionali dell'utente, bloccati fino a metà campionato. */
export const seasonalPredictions: SeasonalPrediction[] = [
  { label: 'Vincitore Serie A', value: 'Inter', points: 50 },
  { label: 'Capocannoniere', value: 'Lautaro Martínez', points: 50 },
];

/** DATO DEMO TEMPORANEO: 3=esatto, 1=solo esito corretto, 0=sbagliato. */
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
    fantasyDemo: { points: 61, average: 60, diff: 1, progress: 52 },
    matches: [
      { home: 'Genoa', away: 'Como', homeScore: 1, awayScore: 4, myPrediction: '1-4' },
      { home: 'Fiorentina', away: 'Torino', homeScore: 1, awayScore: 2, myPrediction: '0-1' },
      { home: 'Inter', away: 'Napoli', homeScore: 3, awayScore: 2, myPrediction: '2-1' },
      { home: 'Roma', away: 'Atalanta', homeScore: 2, awayScore: 1, myPrediction: '1-1' },
      { home: 'Frosinone', away: 'Venezia', homeScore: 3, awayScore: 2, myPrediction: '3-2' },
      { home: 'Juventus', away: 'Milan', homeScore: 1, awayScore: 1, myPrediction: '2-0' },
      { home: 'Parma', away: 'Monza', homeScore: 1, awayScore: 1, myPrediction: '1-1' },
      { home: 'Bologna', away: 'Sassuolo', homeScore: 2, awayScore: 2, myPrediction: '1-0' },
      { home: 'Cagliari', away: 'Lecce', homeScore: 1, awayScore: 0, myPrediction: '1-0' },
      { home: 'Udinese', away: 'Lazio', homeScore: 1, awayScore: 2, myPrediction: '0-2' },
    ],
  },
  {
    number: 4,
    dateRangeLabel: '11–14 settembre 2026',
    status: 'played',
    fantasyDemo: { points: 72, average: 58, diff: 14, progress: 62 },
    matches: [
      { home: 'Venezia', away: 'Fiorentina', homeScore: 2, awayScore: 4, myPrediction: '1-3' },
      { home: 'Genoa', away: 'Frosinone', homeScore: 1, awayScore: 1, myPrediction: '1-1' },
      { home: 'Lazio', away: 'Milan', homeScore: 2, awayScore: 2, myPrediction: '2-2' },
      { home: 'Atalanta', away: 'Cagliari', homeScore: 1, awayScore: 2, myPrediction: '2-1' },
      { home: 'Napoli', away: 'Bologna', homeScore: 1, awayScore: 0, myPrediction: '1-0' },
      { home: 'Sassuolo', away: 'Juventus', homeScore: 3, awayScore: 2, myPrediction: '1-2' },
      { home: 'Lecce', away: 'Monza', homeScore: 3, awayScore: 2, myPrediction: '3-2' },
      { home: 'Torino', away: 'Roma', homeScore: 0, awayScore: 2, myPrediction: '0-2' },
      { home: 'Inter', away: 'Udinese', homeScore: 5, awayScore: 3, myPrediction: '2-1' },
      { home: 'Como', away: 'Parma', homeScore: 2, awayScore: 1, myPrediction: '2-1' },
    ],
  },
  {
    number: 5,
    dateRangeLabel: '18–20 settembre 2026',
    status: 'played',
    fantasyDemo: { points: 86, average: 61, diff: 25, progress: 72 },
    matches: [
      { home: 'Monza', away: 'Sassuolo', homeScore: 2, awayScore: 1, myPrediction: '2-1' },
      { home: 'Bologna', away: 'Torino', homeScore: 1, awayScore: 1, myPrediction: '1-1' },
      { home: 'Udinese', away: 'Cagliari', homeScore: 0, awayScore: 1, myPrediction: '1-2' },
      { home: 'Roma', away: 'Inter', homeScore: 2, awayScore: 2, myPrediction: '1-0' },
      { home: 'Venezia', away: 'Lazio', homeScore: 0, awayScore: 2, myPrediction: '0-2' },
      { home: 'Fiorentina', away: 'Napoli', homeScore: 1, awayScore: 1, myPrediction: '2-2' },
      { home: 'Frosinone', away: 'Como', homeScore: 2, awayScore: 0, myPrediction: '1-0' },
      { home: 'Parma', away: 'Genoa', homeScore: 2, awayScore: 1, myPrediction: '0-1' },
      { home: 'Juventus', away: 'Atalanta', homeScore: 2, awayScore: 0, myPrediction: '2-0' },
      { home: 'Milan', away: 'Lecce', homeScore: 3, awayScore: 0, myPrediction: '2-0' },
    ],
  },
  {
    number: 6,
    dateRangeLabel: '10–12 ottobre 2026',
    status: 'upcoming',
    closesLabel: 'VEN 20:45',
    countdownLabel: '04:12:33',
    matches: [
      { home: 'Genoa', away: 'Fiorentina', homeScore: null, awayScore: null, myPrediction: '2-1' },
      { home: 'Inter', away: 'Parma', homeScore: null, awayScore: null, myPrediction: '3-0' },
      { home: 'Napoli', away: 'Frosinone', homeScore: null, awayScore: null, myPrediction: '2-0' },
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

export const generalLeaderboardPodium: LeaderboardEntry[] = [
  { position: 1, name: 'Marco B.', points: 847, delta: 2, exact: 45, outcomes: 99, initials: 'MB' },
  { position: 2, name: 'Giulia R.', points: 812, delta: 1, exact: 43, outcomes: 97, initials: 'GR' },
  { position: 3, name: 'Davide C.', points: 805, delta: -1, exact: 42, outcomes: 95, initials: 'DC' },
];

export const generalLeaderboardRest: LeaderboardEntry[] = [
  { position: 4, name: 'Sara L.', points: 799, delta: 2, exact: 41, outcomes: 96, initials: 'SL' },
  { position: 5, name: 'Andrea P.', points: 794, delta: -1, exact: 39, outcomes: 98, initials: 'AP' },
  { position: 6, name: 'Federico M.', points: 790, delta: 5, exact: 38, outcomes: 99, initials: 'FM' },
  { position: 7, name: 'Chiara V.', points: 786, delta: 0, exact: 40, outcomes: 92, initials: 'CV' },
  { position: 8, name: 'Luca T.', points: 781, delta: -3, exact: 37, outcomes: 97, initials: 'LT' },
  { position: 9, name: 'Elena F.', points: 777, delta: 1, exact: 36, outcomes: 98, initials: 'EF' },
  { position: 10, name: 'Nicolò S.', points: 773, delta: -2, exact: 35, outcomes: 99, initials: 'NS' },
  { position: 11, name: 'Martina G.', points: 768, delta: 4, exact: 34, outcomes: 97, initials: 'MG' },
  { position: 12, name: 'Paolo D.', points: 764, delta: 0, exact: 33, outcomes: 98, initials: 'PD' },
];

// DATO DEMO TEMPORANEO (vedi nota sopra su `leagues`).
export const yourGeneralPosition = { position: 1284 as number | null, delta: 37 as number | null, points: 712, exact: 28, outcomes: 91 };
