import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

/**
 * true solo se entrambe le variabili sono presenti. Niente `throw` qui: un errore
 * a livello di modulo impedirebbe a React di montare qualsiasi cosa, risultando
 * in una pagina bianca senza nessun messaggio utile per chi deve fare debug.
 */
export const supabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey);

export const supabase = supabaseConfigured ? createClient(supabaseUrl, supabaseAnonKey) : null;
