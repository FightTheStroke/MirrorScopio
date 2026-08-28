# Architettura

Un'app SwiftUI per macOS 26, compilata da `swiftc` senza progetto Xcode. Nessuna
dipendenza esterna, nessuna chiamata di rete.

## Mappa

```
Sources/
  App.swift              punto d'ingresso, router fra le schermate, ambiente condiviso
  Core/
    Model.swift          configurazione della sessione, livelli, tipi di errore
    Stimuli.swift        le liste di parole
    SessionEngine.swift  la macchina a stati che governa una sessione
    FrameClock.swift     tempi al fotogramma via CVDisplayLink
    SpeechListener.swift riconoscimento vocale on-device + livello del microfono
    Scoring.swift        confronto deterministico fra parola detta e parola attesa
    Intelligence.swift   Foundation Models, solo per etichettare il tipo di errore
    Speaker.swift        sintesi vocale per la modalità Scrivi
    Updates.swift        l'unico file che tocca la rete: chiede a GitHub qual è
                         l'ultima versione e sa installarla, dopo aver
                         ricontrollato firma e timbro di Apple
  Design/
    Theme.swift          temi e palette per daltonismo
    Fonts.swift          caratteri per la dislessia, registrati a runtime
    Accessibility.swift  profili di disabilità e singole manopole
    Components.swift     pulsanti e riquadri riusabili, tutti sopra i 44 pt
  Data/
    Store.swift          profili e storico, JSON su disco
    Gamification.swift   punti, serie, obiettivi, proposta di livello
    Exporter.swift       referto PDF e CSV
  Views/                 una schermata per file
Tests/                   harness eseguibili, non XCTest
```

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
