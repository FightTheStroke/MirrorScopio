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
- **C'è scritto che cosa impedisce a qualcun altro di venderci sopra.** La licenza resta
  Apache 2.0 e non cambia niente per chi usa l'app, ma adesso il ragionamento è scritto:
  `docs/STRATEGIA-LICENZA.md` dice perché questa licenza, dove sta il valore che nel
  codice non c'è, e le tre condizioni al verificarsi delle quali si rivede. Con una riga
  scomoda dichiarata invece che nascosta: quattro delle sei cose che dovrebbero rendere
  MirrorScopio difendibile — dati normativi italiani, soglie tarate su bambini veri,
  protocollo validato, rete di logopedisti — **oggi non esistono ancora**.
- **Il nome è protetto anche se il codice è libero.** `NOTICE` e il README adesso dicono
  che «MirrorScopio», il logo e «Fight The Stroke» non sono coperti dalla licenza: chi
  parte da questo codice può farlo, ma deve chiamare la sua cosa in un altro modo e non
  può lasciar credere che sia nostra.
- **A chi contribuisce chiediamo una firma, e gli diciamo perché.** Senza, il giorno in cui
  servisse vendere una licenza a chi ci fa business bisognerebbe chiedere il permesso a
  ognuno o riscrivere il suo pezzo — e finirebbe che non si fa. La liberatoria non toglie
  niente a chi contribuisce: resta l'autore e il suo lavoro resta libero per tutti.
- **Tre documenti nuovi per chi non scrive codice.** «Per i genitori» spiega che cos'è e
  che cosa non è, senza una parola tecnica; «Per i logopedisti» dà paradigma, parametri ed
  esportazioni, e mette i limiti in cima invece che in fondo; «Privacy» dice che cosa l'app
  tiene, perché e per quanto — con una tabella riga per riga, **una pagina scritta per i
  ragazzi** e una valutazione d'impatto.
- **`docs/CLINICA.md` adesso cita le sue fonti.** Prima non ne citava nemmeno una. La nuova
  sezione «Fonti e limiti» separa tre cose che stavano mescolate: quello che poggia sulla
  letteratura (con la bibliografia per esteso), quello che è una scelta nostra mai validata
  — ogni numero con la riga di codice in cui vive — e quello che l'app non sa fare. In cima
  a tutto una frase che non c'era: **nessun valore prodotto da quest'app è normato su
  popolazione italiana**.
- **Il manifesto della privacy di Apple** (`PrivacyInfo.xcprivacy`) è dentro il pacchetto:
  dichiara nessun tracciamento, nessun dominio di tracciamento, nessun dato raccolto.

### Cambiato
- **La documentazione smette di promettere cose che il codice non fa.** Erano sei
  affermazioni false e due imprecise, trovate contandole:
  - Il progetto Xcode **sta** nel repository (README, AGENTS, ARCHITETTURA dicevano di no).
  - L'app si compila con `xcodebuild`, non con `swiftc`, e serve xcodegen.
  - `Verifiche/` e `ProveDaTastiera/` **sono** prove vere; solo `Tests/` sono banchi da
    lanciare a mano.
  - «L'unica cosa che passa dalla rete» erano tre, e il README stesso le elencava più sotto.
  - «Punteggi nascondibili del tutto»: si nascondono in tutte le schermate del ragazzo, ma
    il *Dettaglio per l'adulto* li mostra ancora e si apre senza chiedere niente. Adesso è
    scritto.
  - «Le animazioni si tolgono da sole con Riduci movimento di sistema»: **non è vero**, oggi
    vanno tolte a mano dall'app. Scritto anche questo.
  - La mappa del codice in `ARCHITETTURA.md` saltava dieci file: adesso ci sono tutti.
- **`docs/ACCESSIBILITA.md` dice quali promesse sono verificate e quali no**, una per una:
  i bersagli da 44 punti valgono per i nostri componenti e non per i controlli di sistema,
  il contrasto AA è misurato da una prova mentre l'AAA no, il fuoco da tastiera oggi spesso
  non si vede, e delle sette schermate che promettevano Esc ne è provata una.
- **Tolto il riferimento a RIDInet** dalla scala della modalità «Scrivi»: citava un prodotto
  di terzi come se ne confermasse le scelte, senza riferimento. I quattro gradini sono una
  progettazione nostra, e adesso lo dicono.
- **Riacceso il controllo di concorrenza rigoroso** (`SWIFT_STRICT_CONCURRENCY`). Non è una
  funzione nuova: quegli avvisi c'erano, sono spariti dallo schermo quando è stato tolto
  `Package.swift`, e i difetti erano rimasti tutti. Un problema che non si vede è peggio di
  un problema che si vede. L'app compila come prima; i tre punti che ora si vedono
  (`Gamification.swift:88`, `Fonts.swift:73-74`) restano da correggere.

### Corretto
- **I comandi grandi sparivano appena si toccava qualcos'altro.** Chi sceglieva
  «Paralisi cerebrale» otteneva pulsanti alti 60 punti invece di 44; poi bastava
  alzare di un filo la dimensione del testo e tornavano a 44, in silenzio,
  perché quella modifica riporta il profilo su «su misura». La cosa che rende
  l'app usabile veniva annullata senza una parola. Ora «Comandi più grandi» e
  «Più aria fra le righe» sono due interruttori veri in Impostazioni: il profilo
  li accende, e restano accesi.
- **Il menu dell'audio e le scelte a tendina erano alti 19 punti su 44
  promessi.** Non era un numero sbagliato nel codice: su macOS quel tipo di
  menu si fa dare l'altezza dal sistema e non ascolta quello che gli si chiede.
  Ora sono pulsanti normali con un elenco a comparsa, e ogni riga dell'elenco è
  alta quanto un bersaglio intero. Misurato sull'app in esecuzione: 246×44 il
  pulsante, 282×44 ogni riga.
- **Il Tab non arrivava su undici pulsanti su diciannove.** Sui Mac in cui
  «Navigazione da tastiera» è spenta — quelli appena usciti dalla scatola —
  l'elenco laterale delle Impostazioni, la scelta della voce e le schermate di
  prova non erano raggiungibili senza mouse, mentre il documento prometteva il
  contrario.
- **Giusto e «ancora» si distinguevano solo dal colore**, a meno che il Mac
  avesse acceso «Differenzia senza colore». Chi confonde verde e rosso senza
  saperlo vedeva due pallini identici. La forma diversa adesso c'è sempre.
- **«Niente animazioni» diceva «spento» mentre niente si muoveva.** Quando è il
  Mac a chiedere meno movimento, ora l'interruttore lo mostra acceso.
- **Lo stesso avviso, ripetuto, restava muto.** Il microfono che si azzittiva,
  tornava e si azzittiva di nuovo lo diceva una volta sola a voce.
- **Il testo grande sfondava la colonna laterale prima di quanto si credesse.**
  La soglia oltre la quale l'elenco si mette in fila era 1,6 per numero tondo,
  non per misura: misurata, la colonna sfonda già a ×1,45. Ora è 1,4, e la prova
  automatica non salta più i valori che rompono.
- **Aggiornando l'app si perdevano tutti i propri dati.** Bastava che una
  versione nuova aggiungesse una sola impostazione perché l'elenco delle
  persone, le sessioni e i progressi salvati prima diventassero illeggibili in
  blocco — non quel campo: tutto. È successo davvero, su un Mac che aveva mesi
  di lavoro dentro. Niente è andato perduto (la copia di sicurezza ha retto e
  l'app lo ha detto a schermo), ma era inutilizzabile. Ora un'impostazione che
  ancora non esisteva quando i dati sono stati salvati prende semplicemente il
  suo valore predefinito, e tutto il resto si legge come prima. Un campo che
  invece c'è ma è rovinato continua a essere segnalato come errore: quello non
  è un formato vecchio, è un file rotto, e leggerlo lo stesso vorrebbe dire
  mettere un numero inventato dentro un referto.
- **Un file di dati illeggibile faceva sparire tutto in silenzio.** Se il
  salvataggio precedente era rimasto a metà — disco pieno, Mac spento a metà
  scrittura, aggiornamento andato storto — l'app ripartiva vuota come al primo
  giorno e alla fine dell'allenamento successivo ci scriveva sopra. Mesi di
  lavoro sparivano senza un messaggio. Adesso l'app **non scrive più niente**
  finché non lo dici tu, mette da parte una copia del file con la data e
  spiega a schermo che cosa è successo e dove sono i file.
- **Un salvataggio che non riusciva non lo diceva a nessuno.** Ora compare
  l'avviso con il motivo e la cartella.
- **Le parole esportate nel file di numeri potevano essere cambiate.** Un punto
  e virgola dentro una parola veniva sostituito con una virgola per non rompere
  le colonne: il file si apriva bene e diceva una cosa diversa da quella letta
  davvero. In un referto clinico non è ammissibile. Ora il testo arriva
  identico, virgolette e a capo compresi.
- **La risposta di una parola poteva finire attribuita a quella dopo.** Il
  riconoscitore vocale consegna quando gli pare, e una consegna in ritardo
  entrava nel turno successivo: chi aveva letto «casa» si trovava giudicato
  contro «mare». Non compariva nessun errore — il referto era pieno, ordinato e
  sbagliato. Ora ogni risposta porta il numero della parola a cui appartiene, e
  quella che arriva fuori tempo viene scartata e dichiarata, invece di essere
  contata come una parola non letta.
- **La durata delle parole era misurata sullo schermo sbagliato.** Con due
  schermi a frequenza diversa — un portatile accanto a un monitor — l'app
  chiedeva la frequenza a quello dove c'era il cursore, non a quello dove
  stava la finestra. Adesso la chiede a chi disegna davvero. La frequenza dello
  schermo e il fotogramma saltato vengono **salvati** insieme a ogni parola:
  senza quei numeri «30 millesimi» non vuol dire niente, perché su uno schermo
  a 60 Hz un'esposizione di 30 millesimi non esiste. Restano però dentro i file
  dei dati: **nel PDF e nel CSV esportati non compaiono ancora**.
- **Un turno interrotto veniva contato come una parola non letta.** Il Mac che
  si addormenta, la finestra che passa dietro a un'altra, le cuffie staccate a
  metà: succede, e non dice niente su chi sta leggendo. Ora quel turno è
  segnato come interrotto, non sposta la difficoltà, e l'app spiega che cosa è
  successo invece di lasciar credere che il ragazzo non abbia risposto. Il
  microfono staccato lo scopre subito, non tre parole dopo.
- **Interrompere e ricominciare mescolava le due sessioni.** Il risultato di
  una parola della sessione di prima poteva comparire fra i dati di quella
  nuova. Adesso ogni cosa che arriva in ritardo sa a quale sessione
  apparteneva, e se non è più quella viva viene lasciata cadere.
- **Il file esportato non può più eseguire formule.** Una parola che comincia
  per `=`, `+`, `-` o `@` veniva eseguita come formula da Excel e Numbers
  all'apertura. Adesso viene disinnescata.
- **Il controllo automatico che tiene la rete fuori dall'app ora guarda riga
  per riga**, e non salta più un file intero: ogni riga che parla di rete deve
  dichiararsi, e la deroga vale solo dove è stata concordata. Guarda anche il
  codice delle prove automatiche.
- **I permessi con cui l'app viene firmata sono scritti in un posto solo.**
  Erano due copie della stessa cosa, e due copie si allontanano in silenzio.
- **Nel registro di sistema non finiscono più percorsi e messaggi del Mac in
  chiaro.** Un percorso di cartella contiene il nome dell'utente.

### Sicurezza
- **Lo schermo non lampeggia più di tre volte al secondo.** Le parole ad alto
  contrasto che si alternano alla maschera sono esattamente il tipo di
  alternanza che può scatenare una crisi in chi ha un'epilessia fotosensibile,
  e questa app la usa un ragazzo da solo, senza nessuno accanto che possa
  fermarlo. Azzerando la croce e la pausa da «Per l'adulto» si arrivava a più
  di sessanta cambi al secondo, e niente lo impediva. Adesso il pannello
  avvisa mentre si stanno spostando i cursori, la sessione non parte, e la
  spiegazione dice perché e come rientrare. Un adulto può consentire un ritmo
  più veloce, ma deve dirlo apposta.

## [0.6.0] — 2026-08-28

### Aggiunto
- **Le versioni nuove si installano dall'app.** Fino a ieri MirrorScopio sapeva
  dire che c'era una versione nuova e lì si fermava: toccava andare sulla pagina,
  scaricare, aprire, trascinare. Adesso nelle impostazioni, sotto «I dati», c'è
  «Aggiorna e riavvia»: l'app scarica il pacchetto, mostra a che punto è, e si
  sostituisce da sola.
  - Non parte mai da solo e non parte mai dal ragazzo: il pulsante sta dove
    stanno le cose dell'adulto, e non funziona mentre una sessione è in corso.
    Sostituire un programma mentre qualcuno sta leggendo interrompe una prova
    a metà.
  - Prima di toccare qualsiasi cosa il pacchetto deve superare due controlli: la
    firma dev'essere quella di Fight The Stroke, **e** il timbro di Apple
    dev'essere valido. Se uno dei due non passa non viene installato niente e
    l'app dice perché: la versione che si sta usando resta intatta.
  - Non viene mai chiesta la password di amministratore. Se MirrorScopio sta in
    una cartella dove non si può scrivere — succede a scuola — l'app lo dice e
    si ferma, invece di chiedere privilegi che non dovrebbe avere.

- **Il primo avvio comincia chiedendo che cosa succede quando leggi.** I profili
  di accessibilità esistevano da sempre e non li proponeva nessuno: bisognava
  sapere che erano lì e andarli a cercare nelle impostazioni. Adesso è il primo
  passo, e le scelte sono frasi — «Le lettere si mescolano e saltano di riga»,
  «I comandi piccoli sono difficili da prendere» — non diagnosi. Chi non si
  riconosce in nessuna salta, e non cambia niente.
- **L'app dice a voce che cosa sta succedendo durante l'esercizio.** Con
  VoiceOver acceso si sentiva solo silenzio: adesso si sente quando comincia
  l'ascolto, com'è andato il turno, e — dopo due secondi di niente — che il
  microfono non sta ricevendo. La parola da leggere non viene mai detta: sarebbe
  suggerire la risposta.

### Cambiato
- **L'app segue le impostazioni di accessibilità del Mac.** Chi aveva già acceso
  «Riduci movimento», «Aumenta contrasto», «Riduci trasparenza» o «Differenzia
  senza colore» nelle Impostazioni di Sistema doveva riaccenderli qui dentro, uno
  per uno. Adesso partono da lì, e le impostazioni dell'app lo dicono invece di
  lasciare il mistero di una manopola accesa da sola.
- **I comandi si possono colpire anche quando li disegna macOS.** Interruttori,
  cursori, frecce su e giù ed elenchi a comparsa erano alti fra i sedici e i
  ventisei punti — proprio nelle impostazioni, cioè dove un adulto prepara l'app
  per un ragazzo che i bersagli piccoli non li prende. Ora rispettano i 44 punti
  promessi, e 60 nel profilo «I comandi piccoli sono difficili da prendere», che
  prima li prometteva grandi senza ingrandirne nemmeno uno. I cursori hanno
  accanto due pulsanti per chi il pallino non riesce a prenderlo.
- **Si vede dove è arrivata la tastiera.** Diciassette pulsanti cancellavano
  l'anello di fuoco: chi si muove a tasti non sapeva dove fosse. Adesso l'anello
  c'è, e il fuoco parte dal pulsante principale della schermata.
- **Il testo grande sta anche in larghezza.** La colonna laterale delle
  schermate lunghe cresceva col testo fino a mangiarsi mezzo schermo; la tabella
  del riepilogo aveva colonne a larghezza fissa e le parole finivano fuori.
  Adesso sopra una certa misura la colonna si mette in fila in alto e la tabella
  si apre in schede. E i numeri dei progressi non si rimpiccioliscono più per
  stare in una riga.
- **Le righe sono più larghe per chi salta di riga leggendo.** Il profilo per la
  dislessia lo prometteva da sempre e non lo faceva.
- **I colori sono più decisi.** Tutto quello che l'app scrive sta al livello alto
  del contrasto, non a quello minimo, in tutti e quattro i temi e per tutti e
  cinque i modi di vedere i colori.
- **Il pacchetto da scaricare pesa la metà** (5,8 MB → 3,3 MB): dentro il
  programma c'erano i nomi interni delle funzioni, che servono solo a chi cerca
  un difetto col debugger e restano comunque nel file di diagnostica accanto.
  Sono megabyte che ogni famiglia doveva scaricare.

### Corretto
- **«Nascondi punteggi e percentuali» adesso li nasconde davvero.** Alla fine
  della sessione comparivano lo stesso, tutti insieme: percentuali, millesimi di
  secondo, la tabella parola per parola. Chi aveva chiesto di non vedersi
  misurato si vedeva misurato proprio quando la sessione era ancora addosso. Ora
  quel pezzo sta dietro una porta, come le altre parti «per l'adulto».
- **Rifare il primo avvio e cambiare le impostazioni lasciano l'app nello stesso
  stato.** Toccando una manopola a mano il profilo torna a «su misura» in tutti e
  due i posti: prima lo faceva solo uno dei due.
- **L'app costruita da Xcode dichiarava di essere la versione 0.0.0.** Il numero
  vero, quello del file `VERSION`, arrivava solo nell'app costruita da `build.sh`:
  chi apriva il progetto in Xcode otteneva un pacchetto con un numero sbagliato che
  non protestava. Ora la versione la scrive `scripts/genera-progetto.sh` da un'unica
  fonte, e `./test.sh` si ferma se i due numeri non coincidono.
- **Il pacchetto pubblicato non aveva il timbro di Apple attaccato addosso.**
  Gatekeeper lo accettava lo stesso perché chiedeva ad Apple ogni volta, quindi
  il difetto non si vedeva — ma su un Mac senza internet, e per l'aggiornamento
  dall'app, quel timbro serve. Adesso `scripts/package.sh` lo attacca, e il
  workflow di rilascio si ferma se manca.

## [0.5.0] — 2026-08-28

### Corretto
- **Con il testo ingrandito, «Scrivi» e il gioco non nascondono più i propri
  comandi.** Misurate: la schermata dove si scrive era alta 1009 punti e il
  gioco 988, dentro una finestra da 700. Il campo dove si scrive e la parte
  bassa della festa finivano sotto il bordo, senza nessun modo di arrivarci — e
  finivano fuori proprio a chi aveva ingrandito il testo perché ne aveva
  bisogno. Ora scorrono, e restano centrate quando lo spazio basta.
- **Il pacchetto da scaricare si costruisce da solo a ogni versione.** Prima
  ogni rilascio automatico si fermava dicendo «credenziali non valide», e la
  colpa sembrava della password: in realtà lo script chiedeva ad Apple una cosa
  scritta in un modo che non esiste. Da questa versione il file da scaricare
  compare da sé nella pagina delle release, già firmato e timbrato da Apple:
  doppio clic e si apre, senza avvisi di sicurezza.
- **«giusta» e «ancora» adesso si leggono davvero, in tutti i temi.** I due
  colori erano calcolati per lo sfondo bianco e riusati tali e quali sul nero:
  sul tema scuro «ancora» stava sotto la soglia di leggibilità, e per chi vede
  tutto in tonalità di grigio «giusta» era praticamente dello stesso colore
  dello sfondo. La parola che dice com'è andata era la meno leggibile dello
  schermo, proprio per chi ha più bisogno di leggerla.
- **I pulsanti principali seguono il tema.** «Via!», «Consenti il microfono» e
  «Vai a prenderla» usavano il blu di macOS: con «Altissimo contrasto»
  restavano blu su nero, cioè la cosa meno visibile dello schermo per chi ha
  scelto quel tema perché vede poco.
- **La schermata «Pronti?» adesso scorre.** Era più alta della finestra già a
  grandezza normale: su un portatile «Scegli il microfono» finiva sotto il
  bordo e non c'era nessun modo di raggiungerlo. Chi non veniva sentito
  restava fermo lì.
- **Le giornate storte non sono più segnate con una croce.** Nelle sessioni
  recenti c'era una X rossa: qui si guardano i giorni passati, e quella X
  trasformava una giornata difficile in una bocciatura da rivedere ogni volta.
  Adesso c'è la stessa freccia del resto dell'app: non è venuta *ancora*.
- **Il referto per l'adulto non parla più di «errori».** Il ragazzo non lo
  legge, ma è il documento che il genitore stampa e porta alla logopedista.
- La x che nasconde l'avviso di aggiornamento e il tasto per ascoltare una
  voce erano più piccoli del minimo: chi ha difficoltà di mira li mancava.

### Cambiato
- **La pagina dei Progressi ha lo stesso impianto delle Impostazioni.** Erano
  disegnate uguali ma costruite con numeri diversi: il titolo rientrava del
  doppio, la colonna era più larga, c'era una riga di separazione in più. Ora
  entrambe usano lo stesso guscio, quindi restano allineate anche dopo il
  prossimo ritocco.
- **Si chiude sempre allo stesso modo.** Chiudere una schermata era fatto in
  sei modi diversi, con due parole diverse: chi aveva imparato dove si esce,
  nella schermata dopo non lo ritrovava. Adesso è un pulsante solo, sempre
  nello stesso punto, e dice sempre «Chiudi».
- **Il primo avvio si attraversa da tastiera**: Invio va avanti, Esc salta. Era
  l'unica schermata dell'app che chiedeva per forza il mouse — ed è quella in
  cui si sceglie il profilo di chi usa solo la voce o pochi tasti.
- **La pagina dei parametri clinici rispetta tema, carattere e ingrandimento.**
  Era l'unica a ignorarli: ma chi ingrandisce tutto lo fa perché vede poco lui,
  e quella è la pagina dell'adulto.

## [0.4.0] — 2026-08-27

### Corretto
- **«Ti ho sentito, ma pianissimo»**: quando il microfono prende troppo piano,
  il Mac non capisce nessuna parola — e l'app rispondeva «non sono riuscita a
  capire», che suona come «hai letto male». Non è vero: la voce c'era, era il
  volume. Misurato con la prova del microfono: con il picco a 0,02 non arriva
  una sola parola, con 0,075 arriva in mezzo secondo e con confidenza 0,83.
  Ora l'app dice quale delle due cose è successa e dove si rimedia.
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

[Non ancora rilasciato]: https://github.com/FightTheStroke/MirrorScopio/compare/v0.6.0...HEAD
[0.1.0]: https://github.com/FightTheStroke/MirrorScopio/releases/tag/v0.1.0
[0.2.0]: https://github.com/FightTheStroke/MirrorScopio/releases/tag/v0.2.0
[0.4.0]: https://github.com/FightTheStroke/MirrorScopio/releases/tag/v0.4.0
[0.6.0]: https://github.com/FightTheStroke/MirrorScopio/releases/tag/v0.6.0
