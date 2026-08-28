# Architettura

Un'app SwiftUI per macOS 26, senza nessuna dipendenza esterna: solo i framework che stanno
già dentro il sistema. Si compila con `xcodebuild` sul progetto Xcode, che `build.sh`
rigenera da `project.yml` a ogni compilazione.

Una sola parte del codice tocca la rete — `Core/Updates.swift`, che chiede a GitHub qual è
l'ultima versione (spento finché non lo si accende) e ne scarica il pacchetto solo se lo si
chiede — e un controllo automatico impedisce che ne compaia altra altrove.

## Mappa

```
Sources/
  App.swift              punto d'ingresso, router fra le schermate, ambiente condiviso
  Core/
    Model.swift          configurazione della sessione, livelli, tipi di errore, scala
    Stimuli.swift        le liste di parole
    SessionEngine.swift  la macchina a stati che governa una sessione
    FrameClock.swift     tempi al fotogramma via CVDisplayLink
    SpeechListener.swift riconoscimento vocale on-device + livello del microfono
    Scoring.swift        confronto deterministico fra parola detta e parola attesa
    Intelligence.swift   Foundation Models, solo per etichettare il tipo di errore
    Speaker.swift        sintesi vocale per la modalità Scrivi
    ItalianVoices.swift  elenco delle voci italiane installate, con anteprima
    Suoni.swift          i quattro suoni di conferma, generati in codice
    AudioDevices.swift   microfoni disponibili e scelta dell'ingresso
    Readiness.swift      «Prepara il Mac»: permessi, modello vocale, voce
    Promemoria.swift     avvisi locali giornalieri
    Navigazione.swift    quali schermate sono raggiungibili e quando
    AppVersion.swift     versione e numero di build letti dal pacchetto
    Log.swift            registro diagnostico locale
    Updates.swift        l'unico file che tocca la rete: chiede a GitHub qual è
                         l'ultima versione e sa installarla, dopo aver
                         ricontrollato firma e timbro di Apple
  Design/
    Theme.swift          temi e palette per daltonismo
    Fonts.swift          caratteri per la dislessia, registrati a runtime
    Accessibility.swift  profili di disabilità e singole manopole
    Components.swift     pulsanti e riquadri riusabili
    Badge.swift          i simboli degli obiettivi
    ElencoPagine.swift   la lista di navigazione laterale
  Data/
    Store.swift          profili e storico, JSON su disco
    Gamification.swift   punti, serie, obiettivi, proposta di livello
    Exporter.swift       referto PDF e CSV
  Views/                 una schermata per file (18)
```

## Le prove

Tre cartelle, tre mestieri diversi:

```
Verifiche/          Swift Testing, senza aprire l'app: scala adattiva,
                    contrasto dei colori, suoni, confronto fra versioni,
                    e i due banchi sui dati — che il salvataggio non perda
                    niente e che il referto non alteri le parole
ProveDaTastiera/    XCUITest: apre l'app vera e la usa solo da tastiera,
                    leggendo l'albero di accessibilità
Tests/              banchi di prova eseguibili a mano (`@main`), non XCTest:
                    servono microfono, modello vocale o Foundation Models veri
```

Le prime due girano da `./test.sh` e dentro la verifica automatica su GitHub. La terza si
lancia a mano, perché ha bisogno di hardware e modelli che una macchina di compilazione non
ha.

## Il progetto Xcode

`MirrorScopio.xcodeproj` **sta nel repository**, ma non è la sorgente: è un risultato.
La sorgente è `project.yml`, un file di testo che si legge e si confronta, mentre un
`.xcodeproj` si sporca da solo a ogni apertura. Ci sta perché Xcode Cloud pretende di
trovarlo al momento del clone, prima di eseguire qualunque script.

`scripts/genera-progetto.sh` lo produce sempre uguale a partire da `project.yml`, e un
controllo su GitHub rifiuta le modifiche in cui i due non corrispondono. **Regola pratica: si
cambia `project.yml`, poi si rigenera. Mai il contrario.**

## Il ciclo di una parola

`SessionEngine` è un `@MainActor ObservableObject`. Ogni parola attraversa sempre gli
stessi stati:

```
fissazione → stimolo → maschera → ascolto → esito → pausa fra le parole
```

Il passaggio `stimolo → maschera` è l'unico che **non** usa un timer di sistema. Usa
`FrameClock`, che si appoggia a `CVDisplayLink` tramite `NSView.displayLink(target:selector:)`
e chiude lo stimolo al fotogramma **più vicino** al bersaglio, non al primo che lo supera.
A 120 Hz la differenza fra i due criteri è di 8 ms su un'esposizione che può valere 33: è
la differenza fra una misura e una stima.

## Perché il verdetto non lo dà il modello

Il confronto fra parola detta e parola attesa è **deterministico** (`Scoring.swift`):
minuscole, via i diacritici, via la punteggiatura, e **via anche gli spazi** — se il
riconoscitore scrive "far falla" per "farfalla", la segmentazione è un artefatto del
riconoscitore, non un errore di lettura.

Il modello linguistico interviene **dopo** e solo per dire *che tipo* di errore è
(inversione, sostituzione di una lettera visivamente simile, e così via). Non può ribaltare
un giusto in sbagliato né viceversa.

Questo vincolo nasce da un difetto osservato: interrogato liberamente, il modello ha
dichiarato corretta la risposta "volato" per lo stimolo "tavolo". In un contesto clinico un
falso positivo del genere è peggio di nessuna analisi.

Per la stessa ragione `Intelligence.qualitative()` costruisce il prompt **senza cifre**, solo
con descrizioni qualitative: quando i numeri erano nel prompt, il modello ne inventava altri
nella sintesi.

## Latenza vocale

Il tempo che passa fra la comparsa della parola e l'inizio della voce si misura sul segnale
audio grezzo — l'energia RMS di ogni buffer nel tap — non sulla trascrizione, che arriva
centinaia di millisecondi dopo. La soglia si calibra sul rumore ambientale dei primi 40
buffer: `mediana × 4 + 0.002`.

## Riconoscimento vocale

`SpeechTranscriber` + `SpeechAnalyzer` di macOS 26, interamente on-device. La leva decisiva è
`analyzer.setContext`: mettere la lista di parole della sessione in
`contextualStrings[.general]` polarizza il riconoscitore verso quelle parole, che è
esattamente ciò che serve quando lo stimolo è una parola isolata senza contesto di frase.

Sulle **non-parole** questo non basta e nulla può bastare: non esistono nel vocabolario. Su
quelle liste l'app dichiara che il punteggio è indicativo e suggerisce la modalità Scrivi.

## Dati

`~/Library/Application Support/MirrorScopio/`, due file JSON in chiaro: `learners.json` e
`history.json`. Formato leggibile a occhio di proposito — un genitore deve poter aprire,
capire e cancellare i dati del figlio senza chiedere il permesso a nessuno.
