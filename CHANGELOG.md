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

### Corretto
- **VoiceOver adesso dice i nomi giusti**: i quattro cursori (impostazioni,
  primo avvio, controlli avanzati, velocità della voce) si annunciavano come
  «cursore, 50 per cento», senza dire di che cosa e con una percentuale che
  non è il numero scritto accanto. Ora ognuno dice il proprio nome e il
  proprio valore con le stesse parole che si leggono a schermo. Dodici icone
  di contorno smettono di ripetere a voce quello che il testo diceva già.
- **Esc chiude tutto**: «I tuoi progressi», la prova del microfono e «Prepara
  il Mac» si chiudevano solo col mouse, mentre impostazioni e aiuto no. Chi
  usa solo la tastiera restava dentro.
- **L'app non consuma più batteria stando ferma**: il battito che scandisce i
  centesimi di secondo di una lettura restava acceso anche in home, con lo
  schermo fermo. L'app ridisegnava tutto sessanta volte al secondo per non
  mostrare niente: mezzo core occupato, batteria che se ne va, ventole che
  partono. Ora il battito si ferma quando non c'è niente da cronometrare.
  Misurato a riposo: da mezzo core a zero.

### Cambiato
- **Leggi e Scrivi si assomigliano**: le due modalità avevano preso strade
  diverse — sfondo, margini, la fila dei pallini dell'avanzamento scritta due
  volte e già scivolata. Il compito resta diverso, ma quello che si vede
  intorno è lo stesso: chi impara in una modalità non deve reimparare l'altra.

### Aggiunto
- **Sostieni Fight The Stroke**: un pulsante discreto — nella pagina «Chi
  siamo» dell'aiuto e in fondo alla schermata di fine sessione — apre il sito
  di Fight The Stroke nel browser. Dice sempre che apre un sito esterno, e in
  modalità calma sparisce dalla fine sessione: lì c'è un ragazzo che ha appena
  finito, non un donatore.
- **Un aiuto dentro l'app**: dal menu «Aiuto» (o con ⌘?) si apre una guida in
  parole semplici — come funziona, le modalità Leggi e Scrivi, che fare se il
  Mac non sente, una pagina per genitori e logopedisti, i tasti e chi siamo.
- **Menu dell'applicazione**: si aprono dal menu (e da tastiera) le
  Impostazioni (⌘,), «I tuoi progressi» (⌘P), la prova del microfono e
  «Prepara il Mac». Durante una lettura queste voci restano spente, così
  nessuno esce da una sessione per sbaglio.
- **Distintivi degli obiettivi**: nella pagina «Obiettivi» ogni traguardo
  ancora da prendere non mostra più lo stesso lucchetto grigio uguale per tutti.
  Si vede il suo simbolo — attenuato, dentro un cerchio tratteggiato, con un
  piccolo lucchetto in un angolo — così si capisce sempre *che cosa* si può
  conquistare. Una volta preso, il simbolo diventa pieno con una medaglia e un
  segno di spunta. La differenza fra i due si vede a colpo d'occhio anche in
  bianco e nero e da chi i colori non li distingue.
- **Distintivi dei livelli**: ogni fascia — Esploratore, Lettore curioso,
  Occhio veloce, Lampo, Maestro dei lampi, Leggenda — ha ora il suo simbolo e un
  anello che si riempie salendo, in home e nella pagina dei progressi. Con la
  modalità calma i distintivi restano sobri, senza ori accesi né animazioni.
- **L'accessibilità si sceglie già al primo avvio.** Nell'avvio guidato ci sono
  due nuovi passi: quanto grande deve essere la parola (con un'anteprima dal
  vivo, che cambia mentre sposti il cursore, uguale a come apparirà davvero
  durante l'esercizio), quale carattere, colori e luce; e poi modalità calma,
  meno animazioni e come vedi i colori. Non sei obbligato a decidere: i valori
  vanno bene per molti e si cambiano quando vuoi dalle Impostazioni.
- **Un promemoria gentile ogni giorno.** In Impostazioni › I dati e l'app puoi
  chiedere al Mac di ricordarti l'allenamento all'ora che scegli, tutti i
  giorni o solo dal lunedì al venerdì. Il permesso si chiede solo quando accendi
  l'interruttore; se lo neghi, l'app te lo dice e ti porta dove si rimedia. Non
  arriva niente se hai già letto le tue parole quel giorno, e il testo è sempre
  un invito, mai un rimprovero. È tutto locale: nessun avviso esce dal Mac.
- **L'app adesso suona**: quattro suoni di conferma, spegnibili, per chi fa
  fatica a guardare lo schermo — un tocco quando la parola compare, due note che
  salgono quando è giusta, un tocco piatto e neutro quando è «ancora» (mai un
  suono da errore), e una piccola cadenza incoraggiante alla fine. Si accendono,
  si regola il volume e si ascolta ciascuno in anteprima nella nuova pagina «I
  suoni» delle impostazioni. Si adattano da soli: più discreti in modalità calma
  e con VoiceOver, più netti per chi distingue male i colori, perché lì il suono
  fa il lavoro del colore. Non suonano mentre il microfono ascolta.
- **GitHub costruisce il pacchetto da solo**: ogni tag `v*` fa partire il
  workflow «Rilascio», che compila su macOS 26, firma, notarizza, verifica
  Gatekeeper e allega il DMG alla release.
- Workflow «Verifica» a ogni push: l'app deve compilare e la versione deve
  corrispondere al changelog.
- `scripts/setup-github-secrets.sh`: mette certificato e credenziali nella
  cassaforte di GitHub, guidando passo passo.

## [0.3.1] — 2026-08-27

### Corretto
- **Il controllo delle parole confrontava anche quella di prima.** Il
  riconoscitore consegna trascrizioni che scorrono e possono contenere la
  parola precedente: veniva presa tutta, e si finiva per confrontare «casa
  mare» con `mare`. Ancora ingiusti a chi aveva detto giusto — e ogni tanto il
  contrario, che è peggio. Ora si tiene solo quello che è stato detto dopo la
  comparsa della parola.
- **L'app non sentiva chi rispondeva subito**: il microfono cominciava a
  contare dopo la maschera, e una risposta veloce finiva in un intervallo che
  nessuno stava guardando. Adesso conta dalla comparsa della parola.
- **Il tempo scadeva mentre si stava ancora parlando.** Chi comincia a parlare
  in ritardo — cioè la norma, per chi stiamo aiutando — si vedeva tagliare la
  voce a metà e trovava «Ancora» senza capire perché.
- **Le parole di riscaldamento non contano più nella percentuale finale**: sono
  facili e restano il triplo del tempo, e gonfiavano il risultato.
- L'obiettivo «Dieci sessioni» conta le sessioni; prima guardava i punti.
- `README.md` e `SECURITY.md` dicevano «nessun controllo aggiornamenti» mentre
  l'app ce l'ha, opzionale e spento. Ora è descritto per quello che è.

### Aggiunto
- **Una scena sola durante la lettura**: la parola non sparisce più lasciando lo
  schermo vuoto, resta lì coperta dalle barre, e l'invito a parlare non compare
  dal nulla — si accende dov'era già. Prima erano tre scene diverse per una
  parola sola.
- **L'app dice perché non ha capito**: «non ho sentito niente» (ed è l'audio) o
  «ti ho sentito ma non ho capito le parole» (e allora si riprova). Sono due
  situazioni opposte e confonderle fa cercare guasti che non ci sono, o peggio
  fa credere a un ragazzo di non esserne capace.
- **Microfono e altoparlanti in barra anche durante l'allenamento**, in Leggi e
  in Scrivi: le cuffie si staccano a metà sessione, e prima bisognava uscire.
  Cambiare microfono rifà l'ascolto da solo, dicendolo.
- **Il tempo, se lo vuoi**: un orologio in alto che conta da quanto stai
  andando. Spento di default, e non è un conto alla rovescia — non scade mai.
- **I progressi sono organizzati come le Impostazioni**: cinque pagine corte con
  l'elenco a lato, invece di una colonna sola lunghissima da attraversare tutta.

## [0.3.0] — 2026-08-27

### Aggiunto
- **Scrivi ha la sua scala**, e non parla più di millesimi di secondo: lì la
  parola si sente, non si vede. Cresce la complessità — parole semplici, parole
  con le trappole ortografiche (gn, gl, sc, doppie), frasi brevi, frasi intere
  di senso compiuto. È la progressione usata nella riabilitazione della
  disortografia: scrivere una frase non è scrivere più parole, è reggere
  insieme significato, ordine e ortografia.
- **Riascolto parola per parola** sulle frasi: ogni parola scritta diventa una
  pastiglia che si tocca per risentire solo quella, più «Rileggimi tutta la
  frase che ho scritto». Il Mac rilegge quello che c'è scritto davvero, non
  quello che avrebbe dovuto esserci — il punto è sentire la differenza.
- **I progressi in home**, sempre: livello, barra, giorni di fila, obiettivi.
  Anche a zero punti, dove dicono come si comincia.
- **Coriandoli a fine sessione**, mai proporzionati solo al punteggio: chi
  prende quattro parole su venti ha fatto la fatica più grande. Si spengono da
  soli con «meno animazioni» e in modalità calma.
- **Microfono e altoparlanti nella barra in alto**, con scritto quale è attivo
  adesso: le cuffie si mettono e si tolgono a metà sessione.
- **Le voci italiane che mancano** sono elencate con i nomi esatti che compaiono
  in Impostazioni di Sistema, e al rientro nell'app la voce appena scaricata
  compare da sola. macOS non permette a nessuna app di scaricarle: quello che si
  poteva fare era smettere di lasciare la persona davanti a un elenco muto.
- **Controllo aggiornamenti** via GitHub, spento finché non lo si sceglie. È
  l'unica cosa che esce dal Mac, sta in un file solo, e non installa niente.
- **Un'icona**: un occhio, nella stessa famiglia del logo di MirrorBuddy.

### Cambiato
- **«Ancora» al posto di «sbagliato»**, ovunque: nel feedback, nel referto,
  nelle esportazioni. La croce è diventata una freccia che torna indietro.
- **La parola «normale» non c'è più.** Le opzioni descrivono cosa succede
  guardando lo schermo, non cosa manca a chi guarda.
- **Le Impostazioni sono otto pagine corte** con l'elenco sempre visibile,
  invece di una pagina sola lunghissima.
- **I parametri clinici** non stanno più in home accanto a «Via!», dove il
  ragazzo li trovava prima del logopedista: sono l'ultima pagina delle
  Impostazioni.
- **La prova di velocità** è l'ultimo passo dell'onboarding, non un riquadro in
  fondo alla home che nessuno leggeva. Si rifà dalle Impostazioni.
- **La schermata Scrivi ricalca quella di Leggi**: stesso pulsante per smettere,
  stesso riquadro fermo, stessa fila di pallini. Compito diverso, interfaccia
  uguale.
- **I bottoni hanno tutti la stessa forma**: prima alcuni sembravano link, e un
  link e un bottone chiedono due gesti diversi.
- **Il controllo aggiornamenti distingue i casi**: repository non ancora
  pubblico, troppe richieste, oppure la rete. Un messaggio unico faceva sembrare
  rotta un'app che non lo era.

### Sicurezza
- Chiusa un'iniezione di comandi nel workflow di rilascio, dove il tag arrivava
  in uno script di shell nel job con il portachiavi di firma aperto.
- **Cancellazione dei dati di una persona** dalle Impostazioni, senza frugare
  nelle cartelle di sistema.
- Cartella dei dati `0700`, file `0600`. Password mai negli argomenti dei
  comandi. Il `.p12` viene cancellato davvero.
- Niente più download silenzioso del modello vocale (~1 GB) all'avvio di una
  sessione: adesso rimanda a «Prepara il Mac».

## [0.2.0] — 2026-08-27

### Aggiunto
- **Onboarding guidato al primo avvio**: un passo alla volta, solo ciò che
  manca. Permesso del microfono e modello vocale italiano si concedono e si
  scaricano dall'app, senza mai aprire le Impostazioni di Sistema.
- **Scelta della voce dentro l'app**, con anteprima all'ascolto e regolazione
  della velocità. La voce scelta viene salvata nel profilo.
- Schermata **"Prepara il Mac"**: controlla permesso del microfono, microfono
  collegato, modello di riconoscimento italiano, voce italiana di sistema e
  Apple Intelligence. Il modello vocale si scarica dall'app con avanzamento;
  per voci e Apple Intelligence si apre la pagina giusta delle Impostazioni di
  Sistema. Compare da sola all'avvio se manca qualcosa.
- Schermata **"Mi senti?"** per provare microfono e altoparlanti.
- Indicatori di avanzamento discreti durante la sessione.

### Corretto
- **L'app non riconosceva nessuna parola.** `SpeechAnalyzer` non consegna
  risultati per parole singole: ora al termine della finestra di risposta si
  chiama `finalize(through:)`, che li restituisce in circa 40 ms.
- La scelta del microfono passa dall'ingresso predefinito del sistema e avviene
  prima di creare il motore audio: impostarlo sull'unità audio lo lasciava vivo
  ma muto.

### Distribuzione
- `scripts/package.sh`: DMG firmato Developer ID e, con `--notarize`,
  notarizzato e stapled — apribile su qualunque Mac senza avvisi.
- `TIMESTAMP=1 ./build.sh` aggiunge la marca temporale richiesta da Apple.
- `docs/DISTRIBUZIONE.md`: che cosa serve, perché, e come verificarlo.

### Corretto (voci)
- L'app diceva «c'è solo Alice, di qualità base» pur avendo Federica Premium
  installata: l'elenco delle voci era calcolato una volta sola all'avvio. Ora è
  sempre fresco, e la qualità di serie non è più segnalata come un problema.

### Rimosso
- La richiesta del permesso di *riconoscimento vocale*, che mostrava l'avviso di
  sistema "i dati vocali verranno inviati ad Apple". Non serve: la trascrizione
  usa il modello installato sul Mac. Ora si chiede solo il microfono.


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

[Non ancora rilasciato]: https://github.com/FightTheStroke/MirrorScopio/compare/v0.2.0...HEAD
[0.1.0]: https://github.com/FightTheStroke/MirrorScopio/releases/tag/v0.1.0
[0.2.0]: https://github.com/FightTheStroke/MirrorScopio/releases/tag/v0.2.0
