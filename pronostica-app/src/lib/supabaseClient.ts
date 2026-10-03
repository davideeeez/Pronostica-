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
 * detectSessionInUrl disattivato: leggiamo noi il token dall'hash in AuthContext
 * (il rilevamento automatico non scatta in modo affidabile dietro il Service Worker
 * della PWA in produzione).
 */
export const supabase = supabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, { auth: { detectSessionInUrl: false } })
  : null;
