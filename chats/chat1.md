# # Identità visiva Pronostica!

_Started 2026-08-26 12:32 UTC_

---

## User

Sto sviluppando l'identità visiva per "Pronostica!", un'app mobile di pronostici calcistici per il mercato italiano (target iniziale: tifosi di Serie A). Il modello è simile a Fantacalcio: lega pubblica globale + leghe private tra amici, gratuita, nessun flusso di denaro sulla piattaforma.

Pubblico: uomini e donne 18-45 anni, appassionati di calcio, utenti di app come Fantacalcio, DAZN, Sofascore. Tono desiderato: giovanile ma affidabile, competitivo, non infantile — deve trasmettere sia il pathos della partita che la serietà di una classifica che conta.

Riferimento visivo: stile Fantamondiale (Fantacalcio x DAZN), hero banner, stat card, bottom navigation.

Genera 3-4 direzioni distinte di brand identity (non una sola versione definitiva), ognuna con:
- palette colori (colore primario, secondario, accento, sfondo)
- abbinamento tipografico (titoli + testo corpo)
- 2-3 aggettivi che descrivono il tono di ciascuna direzione
- un piccolo esempio applicato (es. una card statistica o un bottone) per vedere la direzione "in azione"

Voglio poter confrontare le direzioni fianco a fianco prima di sceglierne una.

## User

Check didn’t complete

## User

Check didn’t complete

## Assistant

## User

Ti allego uno screenshot di riferimento visivo (stile Fantamondiale: hero banner, stat card, bottom navigation). Usalo come base per palette e struttura, non copiarlo 1:1 — voglio un'identità distinta ma nello stesso registro visivo.

## Assistant

_[tool: read_file]_

_[tool: ready_for_verification]_

Le quattro direzioni sono pronte e confrontabili fianco a fianco (pan/zoom libero sul canvas):

- **1a Notturna** — blu notte + verde acido, Archivo Black. Elettrica, la più vicina al riferimento.
- **1b Tabellino** — verde campo su carta + rosso rotativa, Instrument Serif + Work Sans. Autorevole, invecchia meglio.
- **1c Diretta** — blu elettrico + magenta live, Space Grotesk + Space Mono. Tecnica, registro Sofascore.
- **1d Curva** — arancio serigrafia su nero caldo, Bebas Neue + Barlow. Viscerale e divisiva.

Ogni scheda ha palette con hex, saggio tipografico e un mockup applicato (hero, stat card, bottone, bottom nav). Il toggle nei Tweaks nasconde i mockup se vuoi confrontare solo palette e type. Dimmi quale id vuoi approfondire.

## User

Ti allego uno screenshot di riferimento visivo (stile Fantamondiale: hero banner, stat card, bottom navigation). Usalo come base per palette e struttura, non copiarlo 1:1 — voglio un'identità distinta ma nello stesso registro visivo.

## Assistant

Il riferimento è lo stesso già usato per costruire le quattro direzioni — sono nel canvas che hai aperto, confrontabili fianco a fianco.

In particolare **1a Notturna** riprende quel registro (blu notte, hero banner con countdown, stat card a tre metriche, bottom nav) ma con accento verde acido invece del giallo, per distinguersi da Fantamondiale.

Dimmi se vuoi che approfondisca una direzione (logo, schermate complete, stati) o se preferisci una quinta più vicina al riferimento.

## User

ne vorrei altre 2 più vicine al riferimento che ti ho dato, magari con combinazioni sempre di blu e giallo differenti ma che stiano comunque bene insieme, lettering fresco, che stia bene con questo genere di app

## Assistant

_[tool: dc_html_str_replace]_

_[tool: dc_html_str_replace]_

_[tool: ready_for_verification]_

Due nuove direzioni in cima al canvas, entrambe con la struttura del riferimento (tre stat card in alto, hero banner con CTA, bottom nav a quattro voci):

- **2a Tribuna** — navy #0E1B47 + blu #2E5BE8 + giallo caldo #FFC93C su fondo chiaro. Sora ExtraBold + Manrope: lettering arrotondato, fresco. Il giallo compare solo dove si agisce.
- **2b Prima Fila** — cobalto #1B36D8 + giallo limone #F2E63A su fondo notte. Chivo Black + Figtree: grottesca larga, maiuscole, numeri grossi. Giallo come co-protagonista, non dettaglio.

I turni 1 restano sotto invariati.

## User

Convert this design into a slide deck using the deck-stage starter component, then export it as a PPTX: `Pronostica Brand Directions.dc.html`

## Assistant

_[tool: read_file]_

_[tool: read_skill_prompt]_

_[tool: copy_starter_component]_

_[tool: dc_write]_

_[tool: run_script]_

_[tool: show_html]_

_[tool: show_html]_

_[tool: multi_screenshot]_

_[tool: run_script]_

_[tool: show_to_user]_

_[tool: gen_pptx]_

_[tool: ready_for_verification]_

Deck creato (`Pronostica Brand Deck.dc.html`, 8 slide 1920×1080) e PPTX scaricato — testo e forme nativi, note del relatore incluse.

Struttura: copertina, una slide per direzione (2a, 2b, 1a, 1b, 1c, 1d) con palette, tipografia, aggettivi e il mockup applicato a destra, più una slide finale di confronto. Il canvas originale resta intatto.

