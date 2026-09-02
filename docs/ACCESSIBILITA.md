# Accessibilità

MirrorScopio parte da un'idea presa da MirrorBuddy: **la disabilità non è un caso limite da
gestire in fondo, è il caso da cui si progetta.** Chi usa questa app ha spesso
dislessia, autismo, ADHD, ipovisione o paralisi cerebrale — a volte più di una insieme.

## Il vincolo che ha riscritto tutto

Durante lo sviluppo la reazione alla prima versione è stata, testualmente: *"non si capisce
un cazzo come funziona"*. La schermata d'avvio era un modulo con una ventina di controlli
clinici — esposizione, staircase, passo, ISI, maschera, endpoint — e in fondo un pulsante
piccolo.

Da lì, la regola:

> **L'utente primario è il ragazzo, non il clinico.** Ogni cosa che il ragazzo non deve
> decidere sta dietro "Per l'adulto".

In pratica: una domanda per schermata, un pulsante grande per volta, parole di uso comune
al posto dei termini tecnici, e i parametri clinici tutti raggiungibili ma tutti chiusi.

E la seconda regola, che vale anche per come scrivo a chi legge:

> **"Non capisco" è un difetto del design, non dell'utente.** Si risponde semplificando, non
> ripetendo più forte.

## Profili

Un profilo imposta tutte le manopole in un colpo solo.

| Profilo | Che cosa cambia davvero (`Design/Accessibility.swift:47-85`) |
|---|---|
| **Dislessia** | OpenDyslexic, lettere distanziate di 6 punti, righe più distanziate, testo ×1,15, tema sabbia, più tempo per rispondere (×1,3) |
| **Autismo** | Niente animazioni, modalità calma, suoni spenti, esito parola per parola, pausa ogni 5 parole, testo ×1,1. **Tema chiaro, non altissimo contrasto** |
| **ADHD** | Schermo pulito, pausa ogni 5 parole, sessioni brevi, niente animazioni |
| **Ipovisione** | Atkinson Hyperlegible, testo ×1,45, altissimo contrasto, lettere distanziate di 4 punti, la parola giusta viene anche detta |
| **Paralisi cerebrale** | Comandi alti 60 punti invece di 44, testo ×1,3, molto più tempo per rispondere (×1,6), niente animazioni, la parola giusta viene anche detta |

Le due cose che questo documento prometteva senza che il codice le facesse — le righe
distanziate della dislessia e i bersagli grandi della paralisi cerebrale — **adesso le fa**.
Non erano manopole, erano effetti calcolati dal profilo: e siccome toccare una qualunque
altra manopola riporta il profilo a «nessuno», sparivano al primo tocco, in silenzio. Ora
«Più aria fra le righe» e «Comandi più grandi» sono due interruttori veri in Impostazioni,
che il profilo accende e che restano accesi da soli.

Toccare una singola manopola riporta il profilo a «nessuno»: non fingiamo che le impostazioni
siano ancora quelle del profilo se non lo sono più. Vale sia nelle Impostazioni
(`SettingsView.swift:613`) sia nel primo avvio (`OnboardingView.swift:333`).

Il caso dell'autismo merita una nota, perché è controintuitivo: **l'alto contrasto è
disattivato apposta.** In molte linee guida "accessibile" e "ad alto contrasto" sono
sinonimi, ma per una persona con ipersensibilità sensoriale il contrasto massimo è
sovraccarico, non aiuto. Le due esigenze sono opposte e vanno tenute separate.

## Caratteri

Inclusi nell'app, registrati a runtime da `CTFontManager`, tutti SIL OFL 1.1:

- **OpenDyslexic** — lettere appesantite in basso e asimmetriche, per ridurre le confusioni
  b/d/p/q e lo scambio di orientamento.
- **Atkinson Hyperlegible** — del Braille Institute, disegnato perché ogni lettera resti
  distinguibile dalle altre in condizioni di vista ridotta.
- **Lexend** — pensato per la fluenza di lettura, spaziatura ampia.

Nessuno dei tre è "la soluzione alla dislessia": le prove sperimentali sui caratteri
specifici sono contrastate. Sono un'opzione, e chi legge deve poter provare e scegliere —
per questo l'anteprima nelle impostazioni è dal vivo.

## Colore

**Il colore non porta mai da solo un'informazione.** Giusto e sbagliato arrivano sempre in
tre modi insieme: colore, simbolo e parola scritta. Se la palette sparisse del tutto, l'app
resterebbe completamente utilizzabile.

Le palette per deuteranopia, protanopia, tritanopia e monocromia non sono filtri applicati a
posteriori: sono coppie di colori scelte perché restino distinguibili con quella specifica
visione.

## Movimento e calma

- Ogni animazione si può togliere, **dall'interruttore dell'app**. Oggi MirrorScopio non
  legge le impostazioni di accessibilità di macOS: se hai già acceso "Riduci movimento" nelle
  Impostazioni di Sistema, qui devi rifarlo a mano. È il difetto più fastidioso di questo
  elenco — chiede di rifare un lavoro già fatto — ed è aperto.
- La **modalità calma** rimuove esclamazioni, coriandoli e enfasi: alcuni ragazzi vivono il
  festeggiamento come rumore, non come premio.
- Nei giochi moderni la modalità calma non sostituisce il 3D con una versione
  povera: conserva arena, materiali, ostacoli e traguardo, ma ferma corsa,
  rotazioni e movimento automatico. Riduce anche pubblico e bandiere e attenua
  i premi luminosi. Ogni pressione compie un salto e un passo.
- I **punteggi si possono nascondere** in tutte le schermate del ragazzo: il risultato
  diventa «hai letto tutte le parole fino in fondo», e nei progressi i numeri diventano
  parole. Il *Dettaglio per l'adulto* a fine sessione continua però a mostrarli, e oggi si
  apre con un clic senza chiedere niente: se il numero non deve arrivare agli occhi del
  ragazzo, quel pannello non va aperto davanti a lui. Difetto aperto.
- Le **pause automatiche** arrivano ogni N parole e non hanno conto alla rovescia. Si
  riparte quando si è pronti, non quando scade qualcosa.

## Suoni

L'app era muta, e chi non riesce a guardare bene lo schermo — spesso proprio chi usa questo
tachistoscopio — non aveva modo di sapere se il Mac aveva registrato la sua risposta. I
suoni di conferma sono quel modo: brevissimi, morbidi, spegnibili, e generati in codice (non
file audio) proprio per poterli plasmare. Sono quattro.

| Momento | Che suono | Perché così |
|---|---|---|
| **La parola è comparsa** | Un tocco solo, brevissimo | Discreto: dice «tocca a te» senza distrarre. |
| **È giusta** | Due note che salgono | La salita si legge come «sì» anche a occhi chiusi. |
| **Ancora** | Due tocchi *alla stessa altezza* | **Mai** una discesa, mai un buzz, mai un tono cupo. Due colpi uguali dicono «riproviamo», non «hai sbagliato»: il suono di un errore su un bambino che ci sta provando fa più danno di dieci parole giuste. |
| **Fine sessione** | Una piccola cadenza che sale | Adeguata al risultato ma sempre incoraggiante: mai triste, mai una fanfara. |

Ogni suono ha un inviluppo morbido — entra da zero e torna a zero — perché un'onda che parte
di scatto fa un «tac» che fa sobbalzare chi ha ipersensibilità uditiva. Che il primo e
l'ultimo campione siano davvero a zero, e che non ci siano salti, lo verifica un test che
conta i campioni invece di fidarsi dell'orecchio.

I suoni non suonano mai mentre il microfono sta valutando una risposta: altrimenti il Mac
sentirebbe sé stesso. E si adattano all'accessibilità, non si limitano a spegnersi:

| Impostazione | Che cosa succede ai suoni | Perché |
|---|---|---|
| **Modalità calma** (autismo, ipersensibilità) | Più bassi, più corti, più morbidi; la fine si riduce a due note gentili | Il festeggiamento può essere rumore, non premio. Mai fanfare. |
| **Riduci movimento** | Un po' più bassi e più corti | Chi chiede meno movimento spesso chiede anche meno stimoli. |
| **Colori che si somigliano / altissimo contrasto** | Più netti e ben distinti, con un volume minimo garantito | Qui il suono prende il posto del colore: deve dire chiaramente «giusta» e «ancora». |
| **VoiceOver acceso** | Ancora più brevi e un filo più bassi | Non si parla sopra il sintetizzatore: il suono cede il passo alla voce. |

Il volume è regolabile, e ogni suono si può ascoltare in anteprima nelle impostazioni: chi
prepara l'app per un ragazzo sente prima cosa sentirà lui.

## Tono

Ereditato da MirrorBuddy: caldo, breve, mai giudicante.

**Non si sbaglia mai: "Ancora".** Non è venuta *ancora*. È la stessa parola che i bambini
imparano al Fight Camp — non "non so farlo", ma "non so ancora farlo" — e vale ovunque:
nel feedback, nei referti, nelle esportazioni e nei simboli. Dove c'era una croce adesso
c'è una freccia che torna indietro, perché a un ragazzo che sbaglia da anni quella croce è
già arrivata abbastanza volte.

**Nessuna parola definisce una persona per ciò che le manca.** "Normale" dice a tutti gli
altri che cosa sono. Le opzioni descrivono che cosa succede guardando lo schermo, non che
cosa manca a chi guarda: *"Il verde e il rosso si somigliano"*, non *"Non distinguo il
verde"*.

Una parola che non è venuta si dice nominando quella giusta e andando avanti. La sintesi
finale parla di quello che è migliorato prima di quello che manca.

## Fondamenta tecniche

Due colonne: quello che è vero oggi, e quello che è ancora un obiettivo. Sono separate
apposta — la prima volta che questo elenco è stato controllato riga per riga, cinque
affermazioni su sei erano ferme alle intenzioni.

| Promessa | Come sta davvero |
|---|---|
| Bersagli tattili/clic 44×44 pt | **Vero, e misurato.** Vale per i componenti nostri e per gli involucri dei controlli di macOS in `Design/Components.swift`. I due punti che sfuggivano — il menu dell'audio e le scelte a comparsa — erano alti 19 punti su 44 promessi, perché un `Menu` di macOS si fa dare l'altezza dal sistema e ignora quello che gli si chiede: ora sono pulsanti con un elenco a comparsa, misurati sull'app in esecuzione a 246×44 e 282×44 per riga. Con «Comandi più grandi» il minimo sale a 60. Le misure stanno in `Verifiche/Bersagli.swift`, sull'altezza resa e non su quella dichiarata. |
| Contrasto WCAG 2.1 AA sui testi | **Vero e verificato**: `Verifiche/Contrasto.swift` misura il rapporto in tutti i temi e in tutte le viste dei colori. |
| AAA (7:1) nelle schermate del ragazzo | **Vero e verificato** su tutte e venti le combinazioni di tema e vista dei colori. Le forme che portano informazione senza essere testo stanno a 3:1, la soglia che la WCAG chiede per loro. |
| Etichette VoiceOver su ogni controllo, decorazioni nascoste | **Vero per i controlli provati** (vedi sotto). Non è dimostrato che valga per ogni controllo di ogni schermata. |
| Le dimensioni si moltiplicano fino a ×2 | **Vero come manopola, e ora provato più a fondo.** La prova sulla larghezza saltava le scale che rompono davvero: misurata, la colonna laterale sfonda già a ×1,45, non a ×1,6 come si credeva. La soglia oltre la quale l'elenco si mette in fila è stata abbassata a 1,4 e la prova percorre tutto l'intervallo. Guardata a occhio su casa e impostazioni il 28 agosto 2026: niente troncato, niente sovrapposto. Non su tutte e nove le schermate. |
| Focus da tastiera sempre visibile | **Vero, e guardato in esecuzione** (28 agosto 2026: anello visibile nell'elenco dei microfoni, e il Tab lo sposta di riga in riga). L'anello lo disegna `StilePulsante`, che contiene anche la dichiarazione che rende i pulsanti raggiungibili col Tab sui Mac in cui «Navigazione da tastiera» è spenta: prima ce l'avevano otto pulsanti su diciannove. Il fuoco **parte** dal pulsante principale in quattro schermate su dieci; nelle altre parte da dove capita. |

## Tastiera e VoiceOver: che cosa è stato verificato

Queste righe raccontano **prove automatiche che girano a ogni modifica**, non intenzioni.
Stanno in `ProveDaTastiera/`.

- **Ogni comando ha un nome, e il nome dice qualcosa** — non «pulsante», non «Selezionato»:
  `testOgniComandoHaUnNome`, `testINomiDiconoQualcosa`.
- **Con il tasto Tab si arriva da qualche parte, e il fuoco si muove davvero** —
  `testSiArrivaDaQualchePartePremendoTab`, `testIlFuocoSiMuove`.
- **Si entra in una schermata e se ne esce, da tastiera** — `testSiEntraESiEsceDaTastiera`
  apre le Impostazioni con ⌘, e le chiude con Esc. Se si entra e non si esce, è una trappola.
- **Le etichette si leggono con una sonda diretta**, non a occhio: SwiftUI scrive
  `.accessibilityLabel` dentro `AXDescription`, non dentro `AXTitle`, e un albero letto male
  fa «correggere» problemi che non esistono.

### E che cosa invece non è verificato

Fino alla versione 0.6.0 questa sezione elencava fra le «prove fatte» anche cose che nessuna
prova esegue. Sono state spostate qui.

- **Una sessione intera senza mouse, fino al riepilogo.** Nessuna prova la percorre: la più
  lunga si ferma alle Impostazioni.
- **«Esc chiude tutto», su sette schermate.** Provata su **una**: le Impostazioni. Sulle
  altre sei è stata sistemata a mano e mai messa sotto prova, quindi può rompersi senza che
  nessuno se ne accorga.
- **Il segno di esito che resta leggibile a voce quando il punteggio è nascosto.** È scritto
  nel codice (`Design/Components.swift:419`, `Views/StageView.swift:202`), non c'è una prova
  che lo controlli.

## Che cosa non è ancora stato verificato a schermo

Sta scritto qui perché una promessa non verificata, in un documento di accessibilità,
vale meno di zero: chi lo legge ci conta.

- **Gli annunci a voce durante l'esercizio** (fase, inizio ascolto, esito, microfono
  muto, fine turno) sono nel codice e non sono ancora stati ascoltati con VoiceOver
  acceso. È l'unica voce rimasta in questo elenco, e resta qui perché per toglierla
  bisogna **sentire** — un albero di accessibilità non dice se una frase è stata
  pronunciata, e nemmeno se è arrivata al momento giusto.

## Che cosa è stato guardato a schermo, e quando

Le tre righe che seguono stavano nell'elenco qui sopra fino alla 0.6.0. Sono state
verificate sull'app in esecuzione il 28 agosto 2026, leggendo l'albero di accessibilità e
guardando le schermate, e sono scese qui perché adesso sono vere.

- **L'anello di fuoco si vede.** Aperto l'elenco dei microfoni e premuto Tab: l'anello
  compare intorno alla prima riga. Premuto ancora: passa alla seconda. È stato guardato,
  non dedotto dal codice.
- **Il Tab entra negli elenchi a comparsa.** Nella 0.6.0 questo documento diceva il
  contrario — «provando a schermo il Tab non è entrato nel pannello». **Era sbagliato.**
  Il Tab entra, il fuoco si sposta di riga in riga e Esc chiude il pannello. Le nove
  righe dell'elenco audio sono alte 44 punti, misurate sull'albero reso, e ognuna dice a
  voce a che cosa serve e se è quella in uso adesso («Microfono di Studio Display, in uso
  adesso»).
- **Il testo a ×2 non rompe niente, ed è stato guardato.** Sulla schermata di casa e
  sulle impostazioni: nessuna parola troncata, nessuna sovrapposizione, tutto
  raggiungibile scorrendo. La colonna laterale delle impostazioni fa quello che la prova
  promette: sopra ×1,4 si mette in fila orizzontale invece di stringersi fino a
  spezzare le parole. Resta un difetto **estetico**: nella pagina «Si comincia da qui» le
  sei schede dei profili, che a grandezza normale stanno in griglia, a ×2 si sfalsano in
  verticale. Nulla è illeggibile né irraggiungibile, ma è brutto, ed è scritto qui perché
  non si dica poi che nessuno se n'era accorto.
