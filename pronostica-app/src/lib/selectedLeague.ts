/**
 * Lega selezionata, salvata sul dispositivo (localStorage). Nessuno storico
 * né sync con il server: solo una preferenza locale di navigazione.
 */
const STORAGE_KEY = 'pronostica.selectedLeagueId';

export function getSelectedLeagueId(): string | null {
  try {
    return localStorage.getItem(STORAGE_KEY);
  } catch {
    return null;
  }
}

export function setSelectedLeagueId(id: string | null): void {
  try {
    if (id) localStorage.setItem(STORAGE_KEY, id);
    else localStorage.removeItem(STORAGE_KEY);
  } catch {
    // storage non disponibile (es. modalità privata): nessun problema, si rifà al prossimo giro
  }
}
