import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

/**
 * true solo se entrambe le variabili sono presenti. Niente `throw` qui: un errore
 * a livello di modulo impedirebbe a React di montare qualsiasi cosa, risultando
 * in una pagina bianca senza nessun messaggio utile per chi deve fare debug.
 */
export const supabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

/**
 * Diagnostica temporanea: un header HTTP non accetta caratteri fuori ISO-8859-1.
 * Se una delle due env var contiene un carattere "sporco" (spazio/virgoletta
 * tipografica finita lì per un copia-incolla), lo individuiamo qui invece di
 * lasciare che fetch() fallisca con un errore generico senza dire dove.
 */
function findInvalidChars(label: string, value: string | undefined): string | null {
  if (!value) return null;
  for (let i = 0; i < value.length; i++) {
    const code = value.codePointAt(i)!;
    if (code > 255) {
      return `${label}: carattere non valido in posizione ${i}: "${value[i]}" (U+${code.toString(16).toUpperCase().padStart(4, '0')})`;
    }
  }
  return null;
}

export const supabaseConfigDiagnostic =
  findInvalidChars('VITE_SUPABASE_URL', supabaseUrl) ||
  findInvalidChars('VITE_SUPABASE_ANON_KEY', supabaseAnonKey) ||
  (supabaseAnonKey ? `VITE_SUPABASE_ANON_KEY: lunghezza ${supabaseAnonKey.length} (attesa 208)` : null);

/**
 * detectSessionInUrl disattivato: leggiamo noi il token dall'hash in AuthContext
 * (il rilevamento automatico non scatta in modo affidabile dietro il Service Worker
 * della PWA in produzione).
 */
export const supabase = supabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, { auth: { detectSessionInUrl: false } })
  : null;
