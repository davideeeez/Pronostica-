import { useContext } from 'react';
import { MyLeaguesContext, type MyLeaguesValue } from '../contexts/myLeaguesContext';

/** Le mie leghe e la lega selezionata: stato condiviso del MyLeaguesProvider. */
export function useMyLeagues(): MyLeaguesValue {
  const value = useContext(MyLeaguesContext);
  if (!value) throw new Error('useMyLeagues va usato dentro MyLeaguesProvider.');
  return value;
}
