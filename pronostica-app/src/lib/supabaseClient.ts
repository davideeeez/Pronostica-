import { createClient } from '@supabase/supabase-js';

/**
 * L'anon key e l'URL del progetto Supabase sono valori PUBBLICI per progettazione
 * (finiscono comunque nel bundle del browser): nessun motivo per passarli da env
 * var su Vercel, il cui campo "Value" mascherato ha ripetutamente corrotto il
 * valore incollato (un carattere veniva sostituito da un pallino "•", probabilmente
 * per interferenza di un password manager del browser sul campo stile-password).
 * Scritti qui, il valore non passa mai da un campo UI mascherato.
 */
const SUPABASE_URL = 'https://fhkhtnkhrtgxncowyqwj.supabase.co';
const SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZoa2h0bmtocnRneG5jb3d5cXdqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzNjQ3MTYsImV4cCI6MjEwNTk0MDcxNn0.ZPt6-UwSZ2zANLLJAbdHcUzjfZZZ6fzCYtfdwZnl21Y';

export const supabaseConfigured = true;

/**
 * detectSessionInUrl disattivato: leggiamo noi il token dall'hash in AuthContext
 * (il rilevamento automatico non scatta in modo affidabile dietro il Service Worker
 * della PWA in produzione).
 */
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { detectSessionInUrl: false },
});
