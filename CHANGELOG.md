# Diario delle versioni

Tutte le modifiche degne di nota. Il formato segue
[Keep a Changelog](https://keepachangelog.com/it/1.1.0/) e la numerazione segue
[SemVer](https://semver.org/lang/it/): `MAGGIORE.MINORE.CORREZIONE`.

Che cosa vuol dire qui, in concreto:

- **MAGGIORE** — cambia il formato dei dati salvati o il modo in cui si misura, e i numeri
  di prima non sono più confrontabili con quelli di dopo.
- **MINORE** — funzioni nuove, i dati vecchi continuano a valere.
- **CORREZIONE** — errori risolti, niente di nuovo.

Le voci sono scritte per chi usa l'app, non per chi scrive il codice.

## [Non ancora rilasciato]

### Aggiunto

- `test.sh` riscritto per la nuova struttura: gli harness veloci girano da soli, quelli che
  usano microfono e modello di sistema solo con `--all`.

## [0.1.0] — 2026-08-27

Prima versione di MirrorScopio, nata dal tachistoscopio sperimentale e riscritta come app
della Fight The Stroke Foundation.

### Aggiunto

- **Sessione automatica**: una parola lampeggia, chi legge la dice ad alta voce, il Mac
  ascolta e decide da solo se è giusta. Nessun adulto deve segnare le risposte.
- **Modalità Scrivi**: il Mac detta la parola e la si scrive. Utile con le non-parole, dove
  il riconoscimento vocale non può essere affidabile.
- **Prova iniziale**: otto parole a velocità calante misurano da dove partire, poi l'app
  imposta un punto di partenza gentile (soglia × 1,25).
- **Riscaldamento**: le prime parole restano visibili il triplo e non contano per la misura.
- **Difficoltà che si adatta**: la velocità sale e scende inseguendo chi legge, e a fine
  sessione l'app *propone* di cambiare livello fuori dalla fascia 60–90% di parole prese.
  Propone, non decide.
- **Tempi al fotogramma**: l'esposizione si chiude sul fotogramma più vicino al bersaglio
  via `CVDisplayLink`, non su un timer di sistema.
- **Progressi**: livello, punti, giorni di fila, nove obiettivi, andamento sessione per
  sessione.
- **Profili di accessibilità**: dislessia, autismo, ADHD, ipovisione, paralisi cerebrale.
  Ogni profilo imposta tutto in un colpo solo, poi ogni manopola resta regolabile.
- **Caratteri per la dislessia** inclusi nell'app: OpenDyslexic, Atkinson Hyperlegible,
  Lexend (SIL OFL 1.1).
- **Temi**: chiaro, scuro, altissimo contrasto, carta color crema; palette per deuteranopia,
  protanopia, tritanopia e monocromia. Giusto e sbagliato non si distinguono mai solo dal
  colore: c'è sempre anche un simbolo e una parola.
- **Modalità calma** senza esclamazioni, possibilità di nascondere i punteggi, pause
  automatiche senza conto alla rovescia, animazioni disattivabili.
- **Referto** in PDF e dati grezzi in CSV, dal pannello dell'adulto.
- **Parametri clinici** completi (lista, maschera, scala adattiva, passo, fissazione,
  timeout) dietro "Per l'adulto".
- **Analisi del tipo di errore** con i Foundation Models di Apple, in locale. L'app funziona
  anche senza.
- Firma con il certificato **Developer ID della Fight The Stroke Foundation**, con ripiego
  ad-hoc perché un clone fresco compili su qualunque Mac.
- Documentazione: architettura, accessibilità, basi cliniche, gamification, versioning.

### Scelte deliberate

- **Niente rete.** Nessun account, nessuna telemetria, nessun servizio esterno. I dati
  stanno in JSON leggibile in `~/Library/Application Support/MirrorScopio/`.
- **Il verdetto giusto/sbagliato è deterministico**, mai deciso dal modello linguistico. In
  prova libera il modello aveva dichiarato corretta la risposta "volato" per lo stimolo
  "tavolo": un falso positivo così, in ambito clinico, è peggio di nessuna analisi.
- **Nessuna dipendenza esterna**, nessun progetto Xcode: solo `swiftc` e i framework di
  sistema.

[Non ancora rilasciato]: https://github.com/FightTheStroke/MirrorScopio/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/FightTheStroke/MirrorScopio/releases/tag/v0.1.0
