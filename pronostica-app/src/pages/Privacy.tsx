import type { CSSProperties, ReactNode } from 'react';
import { PageHeader } from '../components/PageHeader';

const listStyle: CSSProperties = { margin: 0, paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 4 };

/**
 * Pagina pubblica, raggiungibile senza login (route fuori dal gate di autenticazione
 * in App.tsx): deve restare leggibile da chiunque, incluso il link da inserire
 * su Google Cloud Console come privacy policy URL dell'OAuth consent screen.
 */
export function Privacy() {
  return (
    <div className="page">
      <PageHeader title="Privacy Policy" />

      <div className="page-scroll">
        <div className="card" style={{ padding: '15px 16px', display: 'flex', flexDirection: 'column', gap: 4 }}>
          <span style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>Ultimo aggiornamento: 3 ottobre 2026</span>
          <span style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>Titolare del trattamento: Davide Zotti</span>
          <span style={{ fontSize: 12, color: 'var(--color-text-secondary)' }}>Contatto: app.pronostica@gmail.com</span>
        </div>

        <Section title="1. Introduzione">
          <p>
            Questa informativa descrive come "Pronostica!" ("l'app") raccoglie, utilizza e conserva i dati personali
            degli utenti, in conformità al Regolamento (UE) 2016/679 (GDPR). L'app è un servizio gratuito per
            scambiare pronostici sulle partite di Serie A tra gruppi di amici ("leghe"). L'app non gestisce denaro:
            eventuali poste o premi tra i partecipanti restano accordi privati tra loro, esterni alla piattaforma.
          </p>
        </Section>

        <Section title="2. Dati raccolti">
          <p style={{ margin: '0 0 6px' }}>Raccogliamo i seguenti dati personali:</p>
          <ul style={listStyle}>
            <li>Dati dell'account Google usato per l'accesso: nome, indirizzo email, foto profilo</li>
            <li>Username e stemma scelti nell'app</li>
            <li>Pronostici inseriti dall'utente sulle partite di Serie A</li>
            <li>Leghe create o a cui l'utente partecipa, e relativi punteggi</li>
          </ul>
          <p style={{ margin: '6px 0 0' }}>
            Non raccogliamo dati di pagamento, dati bancari o altri dati finanziari: l'app non gestisce transazioni
            economiche di alcun tipo.
          </p>
        </Section>

        <Section title="3. Finalità e base giuridica">
          <ul style={listStyle}>
            <li>Erogazione del servizio (accesso, salvataggio di pronostici, leghe e classifiche): esecuzione di un contratto con l'utente (art. 6.1.b GDPR)</li>
            <li>Autenticazione tramite Google: consenso dell'utente, prestato al momento dell'accesso (art. 6.1.a GDPR)</li>
          </ul>
        </Section>

        <Section title="4. Dove sono conservati i dati">
          <p>
            I dati sono conservati su Supabase, con infrastruttura ospitata nella regione UE di Francoforte,
            Germania. Non trasferiamo dati personali al di fuori dello Spazio Economico Europeo.
          </p>
        </Section>

        <Section title="5. Soggetti terzi coinvolti">
          <ul style={listStyle}>
            <li>Google LLC — fornisce l'autenticazione (Google Sign-In); riceve solo le informazioni necessarie al login</li>
            <li>Supabase Inc. — fornisce hosting del database e dell'infrastruttura di autenticazione, agendo come responsabile del trattamento (art. 28 GDPR)</li>
            <li>Vercel Inc. — ospita l'applicazione web</li>
          </ul>
        </Section>

        <Section title="6. Conservazione dei dati">
          <p>
            I dati sono conservati per tutta la durata dell'account. In caso di cancellazione dell'account, i dati
            personali e i pronostici associati vengono eliminati, salvo quelli necessari per il calcolo di classifiche
            storiche già chiuse, che vengono comunque resi anonimi.
          </p>
        </Section>

        <Section title="7. Diritti dell'utente">
          <p style={{ margin: '0 0 6px' }}>In qualità di interessato, hai diritto a:</p>
          <ul style={listStyle}>
            <li>Accedere ai tuoi dati personali</li>
            <li>Chiederne la rettifica o la cancellazione</li>
            <li>Opporti al trattamento o chiederne la limitazione</li>
            <li>Richiedere la portabilità dei dati</li>
            <li>Proporre reclamo al Garante per la protezione dei dati personali (www.garanteprivacy.it)</li>
          </ul>
          <p style={{ margin: '6px 0 0' }}>
            Per esercitare questi diritti scrivi a <strong>app.pronostica@gmail.com</strong>.
          </p>
        </Section>

        <Section title="8. Cookie e tecnologie simili">
          <p>
            L'app utilizza esclusivamente cookie e storage tecnici necessari al funzionamento del login
            (gestione della sessione di autenticazione). Non utilizziamo cookie di profilazione o di terze parti
            a fini pubblicitari.
          </p>
        </Section>

        <Section title="9. Modifiche a questa informativa">
          <p>
            Questa informativa può essere aggiornata in futuro, ad esempio in caso di nuove funzionalità dell'app
            o cambio del nome del servizio. La data di ultimo aggiornamento è indicata in cima alla pagina.
          </p>
        </Section>
      </div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="card" style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: 8 }}>
      <span style={{ fontFamily: 'var(--font-heading)', fontSize: 15 }}>{title}</span>
      <div style={{ fontSize: 13.5, lineHeight: 1.5, color: 'var(--color-text-secondary)' }}>{children}</div>
    </div>
  );
}
