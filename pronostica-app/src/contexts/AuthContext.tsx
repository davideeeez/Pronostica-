import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase, supabaseConfigured } from '../lib/supabaseClient';
import type { CrestPattern } from '../data/mock';

export interface Profile {
  id: string;
  username: string | null;
  crest_pattern: CrestPattern;
  created_at: string;
}

interface AuthContextValue {
  loading: boolean;
  configured: boolean;
  session: Session | null;
  profile: Profile | null;
  authError: string | null;
  clearAuthError: () => void;
  signInWithGoogle: () => Promise<void>;
  signOut: () => Promise<void>;
  saveProfile: (fields: { username: string; crest_pattern: CrestPattern }) => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

/**
 * Supabase/Google rimandano un login fallito (es. consent screen in Testing,
 * provider non abilitato) come parametri `error`/`error_description` in query
 * string o hash: senza leggerli l'utente vede solo un rimbalzo silenzioso al login.
 */
function readOAuthErrorFromUrl(): string | null {
  const params = new URLSearchParams(window.location.search);
  const hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ''));
  const description = params.get('error_description') || hashParams.get('error_description');
  const code = params.get('error') || hashParams.get('error');
  if (!description && !code) return null;
  return description ? decodeURIComponent(description.replace(/\+/g, ' ')) : code;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [loading, setLoading] = useState(true);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [authError, setAuthError] = useState<string | null>(null);

  function clearAuthError() {
    setAuthError(null);
  }

  async function loadProfile(userId: string) {
    if (!supabase) return;
    const { data, error } = await supabase.from('profiles').select('*').eq('id', userId).maybeSingle();
    if (error) setAuthError(error.message);
    setProfile(data);
  }

  useEffect(() => {
    if (!supabase) {
      setLoading(false);
      return;
    }

    const urlError = readOAuthErrorFromUrl();
    if (urlError) {
      setAuthError(urlError);
      window.history.replaceState(null, '', window.location.pathname);
    }

    supabase.auth.getSession().then(async ({ data: { session } }) => {
      setSession(session);
      if (session) await loadProfile(session.user.id);
      setLoading(false);
    });

    const { data: subscription } = supabase.auth.onAuthStateChange(async (_event, session) => {
      setSession(session);
      if (session) {
        await loadProfile(session.user.id);
      } else {
        setProfile(null);
      }
    });

    return () => subscription.subscription.unsubscribe();
  }, []);

  async function signInWithGoogle() {
    if (!supabase) return;
    setAuthError(null);
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: window.location.origin },
    });
    if (error) setAuthError(error.message);
  }

  async function signOut() {
    if (!supabase) return;
    await supabase.auth.signOut();
  }

  async function saveProfile(fields: { username: string; crest_pattern: CrestPattern }) {
    if (!supabase || !session) throw new Error('Nessun utente loggato.');
    const { data, error } = await supabase
      .from('profiles')
      .upsert({ id: session.user.id, ...fields })
      .select()
      .single();
    if (error) throw error;
    setProfile(data);
  }

  return (
    <AuthContext.Provider value={{ loading, configured: supabaseConfigured, session, profile, authError, clearAuthError, signInWithGoogle, signOut, saveProfile }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth va usato dentro <AuthProvider>.');
  return ctx;
}
