# AGENTS.md — MirrorScopio

Istruzioni per chi lavora su questo repository, umano o agente.

## Che cosa è questa app, in una riga

Un tachistoscopio che si usa **da solo**, per ragazzi con disturbi della lettura, che gira
**interamente in locale** su un Mac.

## Le tre regole che non si negoziano

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
- Tono caldo, breve, mai giudicante. Mai *"No, sbagliato"*.
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
