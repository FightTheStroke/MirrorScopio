# Roadmap multipiattaforma e pubblicazione Apple

Stato al 27 agosto 2026. Questo documento è la fonte operativa per portare
MirrorScopio su iPhone e iPad e pubblicarlo sugli store Apple, senza perdere
la precisione dell'esercizio, la privacy locale e l'accessibilità.

## Come si monitora

Ogni attività ha un identificativo stabile, un responsabile, una dipendenza,
un criterio di uscita e un'evidenza. Gli stati ammessi sono:

- `DA FARE` — non iniziata.
- `IN CORSO` — in lavorazione, con una issue o una pull request collegata.
- `BLOCCATA` — non può proseguire; il motivo va scritto nella colonna Note.
- `FATTA` — il criterio di uscita è dimostrato dall'evidenza indicata.

Regole di aggiornamento:

1. Una attività diventa `IN CORSO` solo quando esiste una issue tracciabile.
2. Una attività diventa `FATTA` solo quando il criterio di uscita è verificato.
3. Le decisioni che cambiano privacy, misura, dispositivi supportati o dati
   salvati vanno registrate nel diario decisioni.
4. Una misura fatta su un dispositivo non va presentata come equivalente a
   macOS finché la verifica di comparabilità non è `FATTA`.
5. Le issue devono usare l'identificativo dell'attività nel titolo o nel corpo:
   `[MOB-04] Audio iOS: AVAudioSession`.

## Stato sintetico

| Area | Stato | Uscita richiesta |
|---|---|---|
| Perimetro prodotto e requisiti | DA FARE | `MOB-01` |
| Nucleo clinico condiviso | DA FARE | `MOB-02` |
| Progetto Xcode e firma | DA FARE | `MOB-03` |
| Audio e riconoscimento locale | DA FARE | `MOB-04`, `MOB-05` |
| Temporizzazione misurabile | DA FARE | `MOB-06` |
| UI e accessibilità mobile | DA FARE | `MOB-07` |
| Dati ed esportazione | DA FARE | `MOB-08` |
| Test su dispositivi reali | DA FARE | `MOB-09` |
| Account e materiali Apple | DA FARE | `STORE-01`–`STORE-05` |
| TestFlight | DA FARE | `STORE-06`, `STORE-07` |
| App Review e pubblicazione | DA FARE | `STORE-08`, `STORE-09` |
| Sorveglianza dopo il rilascio | DA FARE | `STORE-10` |

## Principi che non cambiano

- L'utente principale è il ragazzo, non il clinico.
- Giusto o ancora è deciso dal confronto deterministico, mai dal modello
  linguistico.
- Voce, risposte, progressi e referti restano sul dispositivo.
- Nessun account, pubblicità, telemetria o servizio esterno.
- Le parole che non sono venute si chiamano sempre **ancora**.
- La modalità Scrivi deve funzionare anche senza riconoscimento vocale.
- Una sessione interrotta da audio, sistema o perdita del frame clock non va
  registrata come misura valida.
- MirrorScopio resta uno strumento di esercizio e osservazione, non diagnostico.

## Fasi di prodotto

### MOB-01 — Fissare perimetro e requisiti

**Stato:** DA FARE
**Dipendenze:** nessuna
**Responsabile:** prodotto + area clinica
**Stima:** 2–3 giorni

Decisioni da chiudere:

- target minimo: iOS/iPadOS 26;
- iPad come dispositivo di riferimento;
- iPhone supportato con layout dedicato;
- modalità Leggi e Scrivi nella prima versione;
- Foundation Models facoltativo;
- riconoscimento vocale locale, con preparazione esplicita;
- rete disattivata durante l'uso;
- lista ufficiale di modelli iPhone/iPad supportati;
- regola per dichiarare una misura come valida, educativa o da ripetere;
- scelta iniziale di non usare la categoria Kids senza verifica dedicata.

**Criterio di uscita:** requisiti approvati in una issue e matrice iniziale dei
dispositivi pubblicata nella issue.

### MOB-02 — Estrarre il nucleo clinico condiviso

**Stato:** DA FARE
**Dipendenze:** `MOB-01`
**Responsabile:** sviluppo
**Stima:** 5–7 giorni

Estrarre in `CoreDomain`:

- `SessionConfig`;
- `Trial`;
- `Scoring`;
- `Staircase`;
- `StimulusSet`;
- `Gamification`;
- `SessionRecord` e modelli Codable;
- regole deterministiche di `SessionEngine`.

Il modulo non deve importare SwiftUI, AppKit, CoreAudio, AVFoundation,
Speech, FoundationModels o usare rete e file picker.

**Criterio di uscita:** gli stessi input producono gli stessi esiti su Mac e
iOS/iPadOS; test di punteggio, scala e formato dati passano su entrambe le
piattaforme.

### MOB-03 — Creare il progetto Apple condiviso

**Stato:** DA FARE
**Dipendenze:** `MOB-02`
**Responsabile:** sviluppo
**Stima:** 3–5 giorni

Creare un progetto Xcode con target:

```text
MirrorScopio macOS
MirrorScopio iOS
MirrorScopio iPadOS
CoreDomain
```

Configurare Bundle ID, Team, Debug/Release, asset catalog, icone, orientamenti,
versione, numero build e firma. Mantenere temporaneamente `build.sh` per non
interrompere il rilascio Mac; il nuovo progetto diventa la strada per Apple
mobile.

Il file `VERSION` resta la fonte di verità e alimenta
`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`. Ogni upload deve avere un numero
build nuovo.

**Criterio di uscita:** una build Release installabile su iPhone e iPad reali,
firmata dal team della fondazione; Mac continua a compilare.

### MOB-04 — Sostituire audio e route su iOS/iPadOS

**Stato:** DA FARE
**Dipendenze:** `MOB-03`
**Responsabile:** sviluppo
**Stima:** 5–8 giorni

Creare `IOSAudioInput` con `AVAudioSession` per:

- permesso microfono;
- ingresso e uscita;
- livello RMS;
- route corrente;
- cuffie cablate;
- Bluetooth;
- microfono USB su iPad;
- cambio route;
- interruzioni da telefonata e Siri;
- riattivazione sicura.

Non promettere su iPhone la stessa selezione manuale del microfono del Mac.
Mostrare sempre quale route è effettivamente attiva.

**Criterio di uscita:** la sessione rileva e comunica ogni stato audio; una
interruzione ripete la parola invece di salvare una misura falsata; funzionano
microfono interno, cuffie e almeno un ingresso USB su iPad.

### MOB-05 — Portare il riconoscimento vocale locale

**Stato:** DA FARE
**Dipendenze:** `MOB-04`
**Responsabile:** sviluppo
**Stima:** 5–8 giorni

Adattare `SpeechListener` a `SpeechAnalyzer`/`SpeechTranscriber` su iOS 26 e
iPadOS 26. Verificare:

- locale `it-IT`;
- disponibilità del modello;
- installazione prima della sessione;
- vocabolario contestuale;
- risultati volatili;
- `audioTimeRange`;
- `finalize(through:)`;
- risposte vuote;
- bassa confidenza;
- non-parole;
- frasi;
- funzionamento offline.

**Criterio di uscita:** 100 prove su iPhone e 100 su iPad, senza rete, con
traccia di dispositivo, modello, trascrizione, confidenza, onset e tempo di
flush; nessun errore silenzioso.

### MOB-06 — Rendere misurabile il tempo sul display mobile

**Stato:** DA FARE
**Dipendenze:** `MOB-03`
**Responsabile:** sviluppo + validazione
**Stima:** 4–6 giorni

Estrarre `DisplayClock` e creare:

```text
MacDisplayClock
IOSDisplayClock
```

Usare `CADisplayLink`, gestire 60/120 Hz e ProMotion, sospendere la sessione
quando l'app perde la scena attiva e registrare frequenza, tempo richiesto,
tempo osservato, dispositivo e orientamento.

**Criterio di uscita:** report dell'errore per iPhone 60 Hz, iPhone ProMotion,
iPad 60 Hz e iPad ProMotion; ogni prova interrotta è marcata come non valida.

### MOB-07 — Adattare UI e accessibilità

**Stato:** DA FARE
**Dipendenze:** `MOB-03`, `MOB-04`
**Responsabile:** design + sviluppo
**Stima:** 5–8 giorni

Riutilizzare dove possibile `StageView`, `TypingView`, componenti, temi,
profili e feedback. Adattare `SettingsView`, `DashboardView`, `ReportView`,
`OnboardingView`, `TrainingBar` e il layout:

- iPhone: navigazione verticale, niente pannello laterale fisso;
- iPad: due colonne quando lo spazio lo permette;
- orientamento verticale e orizzontale;
- Split View;
- tastiera esterna;
- testo fino a ×2;
- VoiceOver;
- Reduce Motion;
- modalità calma;
- bersagli di almeno 44×44 pt.

**Criterio di uscita:** i flussi principali sono completabili con VoiceOver,
testo grande e tastiera esterna; nessun testo essenziale è troncato o
sovrapposto.

### MOB-08 — Dati, cancellazione ed esportazione mobile

**Stato:** DA FARE
**Dipendenze:** `MOB-02`, `MOB-07`
**Responsabile:** sviluppo
**Stima:** 3–5 giorni

Mantenere il formato JSON comune, nella sandbox Application Support iOS.
Sostituire `NSSavePanel` con `FileDocument`, `fileExporter`, `ShareLink` o
document picker. Verificare salvataggio atomico, migrazione, cancellazione,
PDF, CSV e messaggi di errore.

Rimuovere dalla prima release mobile il controllo aggiornamenti via GitHub,
se non serve: gli aggiornamenti vengono gestiti dall'App Store e la promessa
“nessuna rete” è più semplice da dimostrare.

**Criterio di uscita:** adulto in grado di cancellare i dati ed esportare PDF e
CSV tramite Files o condivisione, senza collegare il dispositivo a un Mac.

### MOB-09 — Validare su dispositivi reali

**Stato:** DA FARE
**Dipendenze:** `MOB-04`, `MOB-05`, `MOB-06`, `MOB-07`, `MOB-08`
**Responsabile:** QA + area clinica
**Stima:** 8–12 giorni

Matrice minima:

| Dispositivo | Verifica |
|---|---|
| iPad recente non Pro | riferimento comune |
| iPad Pro recente | ProMotion |
| iPhone recente non Pro | hardware comune |
| iPhone Pro recente | ProMotion |
| cuffie cablate | route stabile |
| cuffie Bluetooth | cambio route e latenza |
| microfono USB su iPad | ingresso esterno |

Ripetere anche con offline, modello mancante, permesso negato, telefonata,
Siri, blocco schermo, ritorno dall'applicazione e risparmio energetico.

**Criterio di uscita:** matrice firmata con risultati e dispositivi supportati;
nessun problema critico aperto; ogni limite è visibile nell'app o nella
documentazione.

## Fasi Apple Developer e store

### STORE-01 — Preparare l'account della fondazione

**Stato:** DA FARE
**Dipendenze:** `MOB-01`
**Responsabile:** amministrazione fondazione
**Stima:** 2–5 giorni, esclusi eventuali tempi Apple

Verificare o completare:

- iscrizione organizzazione all'Apple Developer Program;
- entità legale;
- D-U-N-S;
- sito pubblico;
- Apple Account con autenticazione a due fattori;
- Account Holder;
- ruoli per sviluppo, gestione app e pubblicazione;
- accordi Apple accettati;
- accesso ad App Store Connect.

**Criterio di uscita:** la fondazione può creare l'app e assegnare ruoli senza
condividere password.

### STORE-02 — Registrare identificatori e firma

**Stato:** DA FARE
**Dipendenze:** `STORE-01`, `MOB-03`
**Responsabile:** sviluppo + Account Holder
**Stima:** 1–2 giorni

Creare il Bundle ID definitivo e configurare solo le capacità necessarie:

```text
microfono
sandbox iOS standard
```

Non aggiungere CloudKit, notifiche, tracking, analytics, Game Center o account
se non sono richiesti dal prodotto.

**Criterio di uscita:** archive Release caricabile da Xcode e installabile da
TestFlight.

### STORE-03 — Preparare privacy tecnica e policy pubblica

**Stato:** DA FARE
**Dipendenze:** `MOB-04`, `MOB-05`, `MOB-08`
**Responsabile:** privacy + sviluppo
**Stima:** 3–5 giorni

Preparare:

- `NSMicrophoneUsageDescription`;
- `PrivacyInfo.xcprivacy` se una API usata rientra nelle Required Reason APIs;
- privacy policy pubblica;
- descrizione del trattamento locale;
- assenza di account, tracking, pubblicità e telemetria;
- trattamento del nome e dello storico;
- cancellazione;
- esportazione manuale;
- eventuale uso facoltativo di Foundation Models.

**Criterio di uscita:** codice, schermate, privacy policy e App Privacy
questionnaire non si contraddicono.

### STORE-04 — Preparare contenuti, età e claim

**Stato:** DA FARE
**Dipendenze:** `MOB-01`, `MOB-07`
**Responsabile:** prodotto + clinica + comunicazione
**Stima:** 2–3 giorni

Preparare:

- nome e sottotitolo;
- descrizione italiana;
- parole chiave;
- categoria Education;
- age rating;
- screenshot iPhone e iPad;
- icona;
- URL supporto;
- URL privacy;
- dichiarazione che non è dispositivo medico né diagnostico;
- spiegazione dell'uso del microfono;
- valutazione separata della categoria Kids.

Non usare claim come “cura”, “diagnostica”, “test standardizzato” o
“garantisce miglioramenti”.

**Criterio di uscita:** tutti i contenuti sono approvati e descrivono il
prodotto reale, senza promesse cliniche non dimostrate.

### STORE-05 — Completare export compliance

**Stato:** DA FARE
**Dipendenze:** `MOB-03`, `STORE-03`
**Responsabile:** Account Holder + sviluppo
**Stima:** 1 giorno

Rispondere al questionario Apple sull'uso della crittografia, considerando
solo la rete e le librerie effettivamente presenti nella build.

**Criterio di uscita:** nessuna richiesta di export compliance irrisolta per la
build destinata a TestFlight e App Store.

### STORE-06 — TestFlight interno

**Stato:** DA FARE
**Dipendenze:** `MOB-05`, `MOB-06`, `MOB-07`, `MOB-08`, `STORE-02`, `STORE-03`, `STORE-05`
**Responsabile:** QA fondazione
**Stima:** 3–5 giorni

Caricare una Release, completare export compliance e creare gruppi interni.
Verificare installazione pulita, aggiornamento, offline, permessi, modello
mancante, audio, VoiceOver, testo grande, interruzioni, esportazione e
cancellazione.

**Criterio di uscita:** nessun blocco nei flussi principali e nessun errore
silenzioso.

### STORE-07 — TestFlight esterno e beta review

**Stato:** DA FARE
**Dipendenze:** `STORE-06`, `MOB-09`
**Responsabile:** prodotto + QA
**Stima:** 1–2 settimane

Creare gruppi separati:

```text
logopedisti
famiglie
accessibilita
```

Scrivere note di test, criteri dei tester e istruzioni per il microfono.
Inviare il primo build alla beta review Apple prima di invitare tester
esterni.

**Criterio di uscita:** feedback raccolto da logopedisti e famiglie, problemi
classificati per gravità, nessun problema critico aperto.

### STORE-08 — Preparare App Store Connect

**Stato:** DA FARE
**Dipendenze:** `STORE-02`, `STORE-03`, `STORE-04`, `STORE-05`, `STORE-07`
**Responsabile:** Account Holder + prodotto
**Stima:** 2–3 giorni

Completare:

- record app;
- Bundle ID;
- metadata;
- screenshot;
- age rating;
- App Privacy;
- privacy policy;
- export compliance;
- contatto App Review;
- build da inviare;
- note per il revisore;
- percorso per accedere a “Dettaglio per l'adulto”;
- spiegazione della modalità offline;
- spiegazione del microfono locale;
- spiegazione di Foundation Models facoltativo;
- eventuali link esterni.

**Criterio di uscita:** il revisore può completare una sessione senza
assistenza e App Store Connect non segnala campi obbligatori mancanti.

### STORE-09 — Inviare e pubblicare la prima versione

**Stato:** DA FARE
**Dipendenze:** `STORE-08`
**Responsabile:** Account Holder
**Stima:** 2–5 giorni, esclusi i tempi di review

Prima dell'invio:

1. incrementare il numero build;
2. creare archive Release;
3. eseguire smoke test su iPhone e iPad;
4. caricare la build;
5. completare export compliance;
6. selezionare la build;
7. inviare ad App Review;
8. rispondere alle domande Apple;
9. scegliere rilascio manuale;
10. pubblicare dopo verifica interna.

**Criterio di uscita:** app disponibile nello store, installata dalla pagina
pubblica e verificata con primo avvio, permesso microfono, sessione offline e
versione mostrata nell'app.

### STORE-10 — Sorvegliare la prima settimana

**Stato:** DA FARE
**Dipendenze:** `STORE-09`
**Responsabile:** prodotto + QA
**Stima:** 5 giorni distribuiti nella prima settimana

Controllare crash, feedback, recensioni, problemi di microfono, modello
mancante, nuovi dispositivi e coerenza della privacy. Preparare una patch solo
se esiste un problema riproducibile e documentato.

**Criterio di uscita:** problemi post-rilascio classificati, proprietario e
azione assegnati, nessun incidente privacy o misura falsata non gestito.

## Dipendenze principali

```text
MOB-01
  └─ MOB-02
      └─ MOB-03
          ├─ MOB-04
          │   └─ MOB-05
          ├─ MOB-06
          └─ MOB-07
              └─ MOB-08
MOB-04 + MOB-05 + MOB-06 + MOB-07 + MOB-08
  └─ MOB-09

STORE-01
  └─ STORE-02
STORE-03 + STORE-05 + MOB-09
  └─ STORE-06
      └─ STORE-07
          └─ STORE-08
              └─ STORE-09
                  └─ STORE-10
```

## Gate di qualità prima della pubblicazione

La prima versione non va inviata finché non sono vere tutte queste condizioni:

- build Release firmata installabile su iPhone e iPad;
- sessione Leggi offline;
- modalità Scrivi funzionante senza riconoscimento vocale;
- modello italiano mancante comunicato chiaramente;
- permesso microfono negato gestito chiaramente;
- interruzione audio senza misura falsata;
- frame clock verificato su più frequenze;
- dati cancellabili dall'app;
- PDF e CSV esportabili;
- VoiceOver utilizzabile;
- testo ×2 senza sovrapposizioni;
- privacy policy pubblica;
- App Privacy coerente;
- age rating compilato;
- export compliance completata;
- privacy manifest verificato;
- nessun segreto nel repository;
- TestFlight interno superato;
- beta esterna provata;
- note App Review complete;
- claim non diagnostici e non terapeutici.

## Milestone e stima

| Milestone | Attività | Tempo tecnico |
|---|---|---:|
| M0 — Perimetro approvato | `MOB-01`, `STORE-01` | 1 settimana |
| M1 — Progetto mobile che compila | `MOB-02`, `MOB-03` | 1–2 settimane |
| M2 — Prima sessione su iPad | `MOB-04`, `MOB-05`, `MOB-06` | 2–3 settimane |
| M3 — Beta tecnica | `MOB-07`, `MOB-08`, `MOB-09` | 2 settimane |
| M4 — TestFlight interno | `STORE-02`, `STORE-03`, `STORE-05`, `STORE-06` | 1 settimana |
| M5 — TestFlight esterno | `STORE-07` | 1–2 settimane |
| M6 — Prima pubblicazione | `STORE-04`, `STORE-08`, `STORE-09` | 1 settimana + review Apple |
| M7 — Stabilizzazione | `STORE-10` | 1 settimana |

Stima complessiva realistica:

- beta tecnica: 4–6 settimane;
- TestFlight esterno: 6–8 settimane;
- prima pubblicazione: 8–12 settimane;
- versione pronta per famiglie e logopedisti: 10–14 settimane.

Le attività possono procedere in parallelo, ma non si può saltare la validazione
di audio, temporizzazione, privacy e accessibilità.

## Diario decisioni

| ID | Decisione | Motivo | Stato |
|---|---|---|---|
| ADR-MOB-01 | iPad è il dispositivo di riferimento | Schermo e uso clinico più adatti; iPhone segue con layout dedicato | DA CONFERMARE |
| ADR-MOB-02 | `CoreDomain` senza framework UI o audio | Evita divergenze fra Mac, iPhone e iPad | DA CONFERMARE |
| ADR-MOB-03 | Foundation Models resta facoltativo | Il verdetto deve restare deterministico e disponibile su più dispositivi | PROPOSTA |
| ADR-MOB-04 | Audio interrotto = prova da ripetere | Meglio perdere una prova che registrare una misura falsa | PROPOSTA |
| ADR-MOB-05 | Nessun controllo aggiornamenti via rete nella prima app mobile | App Store gestisce gli aggiornamenti; promessa offline più semplice | PROPOSTA |
| ADR-MOB-06 | Categoria Kids non automatica | Introduce requisiti aggiuntivi per link, privacy e parental gate | DA VERIFICARE |

## Registro delle evidenze

Quando un'attività è completata, aggiungere qui il riferimento alla prova:

| Attività | Evidenza | Data | Esito |
|---|---|---|---|
| — | — | — | — |

## Riferimenti tecnici

- [SpeechAnalyzer](https://developer.apple.com/documentation/speech/speechanalyzer)
- [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber)
- [Foundation Models](https://developer.apple.com/documentation/foundationmodels)
- [AVAudioSession](https://developer.apple.com/documentation/avfaudio/avaudiosession)
- [Gestione delle interruzioni audio](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions)
- [Cambio della route audio](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes)
- [CADisplayLink](https://developer.apple.com/documentation/quartzcore/cadisplaylink)
- [ShareLink](https://developer.apple.com/documentation/swiftui/sharelink)
- [TestFlight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)
- [Upload delle build](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [App Privacy](https://developer.apple.com/app-store/app-privacy-details/)
- [Export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)
- [Invio ad App Review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
