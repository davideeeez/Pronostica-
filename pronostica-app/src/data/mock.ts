// Le leghe (private/pubbliche, classifica, membri, codici invito) vivono SOLO
// nel database: vedi src/lib/leagues.ts, src/hooks/useMyLeagues.ts. Non
// reintrodurre dati di leghe qui.

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
