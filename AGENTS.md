# AGENTS.md — MirrorScopio

Istruzioni per chi lavora su questo repository, umano o agente.

## Che cosa è questa app, in una riga

Un tachistoscopio che si usa **da solo**, per ragazzi con disturbi della lettura, che gira
**interamente in locale** su un Mac.

## Le quattro regole che non si negoziano

1. **L'utente primario è il ragazzo, non il clinico.** Se una schermata richiede di sapere
   che cos'è una staircase, è progettata male. Tutto ciò che il ragazzo non deve decidere
   sta dietro "Per l'adulto".
2. **Niente esce da questo Mac.** Nessuna rete, nessun account, nessuna telemetria, nessun
   servizio esterno. Neanche per il crash reporting. Una `URLSession` in questo codice è un
   bug.
3. **Il verdetto giusto/sbagliato è deterministico.** Il modello linguistico può etichettare
   un errore, mai deciderlo. Se un giorno la tentazione di far arbitrare il modello torna,
   rileggere la sezione apposita di [`docs/ARCHITETTURA.md`](docs/ARCHITETTURA.md): è già
   stato provato e ha dichiarato "volato" corretto per "tavolo".
4. **Nessuna parola definisce una persona per ciò che le manca.** "Normale" dice a tutti gli
   altri che cosa sono, e chi apre questa app ha già sentito abbastanza spesso di essere
   l'eccezione: le opzioni descrivono che cosa succede guardando lo schermo, non che cosa
   manca a chi guarda ("Il verde e il rosso si somigliano", non "Non distinguo il verde").
   E non si sbaglia mai: **"Ancora"**. Non è venuta *ancora*. È la stessa parola che i
   bambini imparano al Fight Camp — non "non so farlo", ma "non so ancora farlo" — e vale
   nel feedback, nei referti, nelle esportazioni e nei simboli (una freccia che torna
   indietro, non una croce).

## Prima di dire che una cosa funziona

- `./build.sh` compila **senza errori** (gli avvisi si guardano, non si ignorano).
- `./test.sh` passa.
- Se il cambiamento tocca l'interfaccia, **si guarda l'app in esecuzione**. Non basta che
  compili.
- Se il cambiamento tocca i tempi, si verifica sull'app in esecuzione con
  `FrameClock` attivo: i timer di sistema mentono, i fotogrammi no.

Attenzione: `open` su un'app già in esecuzione **rifocalizza la vecchia istanza** invece di
caricare il binario nuovo. Dopo ogni build va chiuso il processo precedente, altrimenti si
verifica la versione sbagliata. È già successo.

## Scrivere all'utente e nell'interfaccia

- **Italiano**, sempre, anche nei commenti e nei messaggi di commit.
- Parole di uso comune. Se un termine tecnico è inevitabile, si spiega nella stessa frase.
- Tono caldo, breve, mai giudicante. Mai *"No, sbagliato"*: si dice **"Ancora"**.
- **Se l'app sa qualcosa, lo dice.** È il difetto che è tornato più volte: microfono muto e
  barra ferma senza spiegazione, salvataggio fallito in silenzio, un giga scaricato di
  nascosto, un livello che prometteva millesimi inesistenti. Uno stato conosciuto e taciuto
  è un bug, anche quando il codice è corretto.
- **"Non capisco" è un difetto di chi ha scritto**, non di chi legge: si risponde
  semplificando e cambiando le parole, mai ripetendo più forte.

## Struttura

Vedi [`docs/ARCHITETTURA.md`](docs/ARCHITETTURA.md). In breve: `Core` non sa niente di
SwiftUI, `Design` non sa niente di sessioni, `Views` non fa calcoli.

## Accessibilità: la lista che va ricontrollata a ogni schermata nuova

- Bersagli minimo 44×44 pt.
- Il colore non porta mai da solo un'informazione: sempre anche simbolo e parola.
- Percorribile da tastiera, focus visibile.
- Etichette VoiceOver sui controlli, decorazioni nascoste.
- Rispetta "Riduci movimento" e la modalità calma.
- Regge il testo moltiplicato ×2 senza troncare né sovrapporre.

## Dipendenze

Nessuna, e va tenuta così. Niente SwiftPM, niente CocoaPods, niente progetto Xcode. Solo
`swiftc` e i framework di sistema. Aggiungere una dipendenza è una decisione da discutere,
non da fare di passaggio.

## Versioni

`VERSION` alla radice è l'unica fonte di verità. `build.sh` la scrive nell'Info.plist
insieme al numero di build (il conto dei commit) e al commit da cui è nato il binario;
`AppVersion` la rilegge dal bundle e la mostra nelle impostazioni. **Non scrivere mai un
numero di versione dentro il codice Swift.**

Per rilasciare: scrivi che cosa cambia sotto `## [Non ancora rilasciato]` nel
[CHANGELOG](CHANGELOG.md), poi `./scripts/release.sh 0.2.0`. Lo script rifiuta di partire
con modifiche non salvate o con la sezione vuota.
