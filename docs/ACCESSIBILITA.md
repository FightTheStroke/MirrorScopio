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

Un profilo imposta tutte le manopole in un colpo solo. Toccare poi una singola manopola
riporta il profilo a "nessuno": non fingiamo che le impostazioni siano ancora quelle del
profilo se non lo sono più.

| Profilo | Che cosa cambia |
|---|---|
| **Dislessia** | OpenDyslexic, lettere più distanziate, interlinea più ampia, testo più grande |
| **Autismo** | Niente animazioni, niente distrazioni, niente esclamazioni, pause frequenti. **Contrasto medio, non alto** |
| **ADHD** | Sessioni brevi, pause automatiche, schermo pulito, feedback immediato |
| **Ipovisione** | Testo molto grande, altissimo contrasto, Atkinson Hyperlegible |
| **Paralisi cerebrale** | Tempi di risposta lunghi, bersagli da 60 pt invece che da 44, parola più grande, nessuna fretta |

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

- Ogni animazione si può togliere (e si toglie da sola con "Riduci movimento" di sistema).
- La **modalità calma** rimuove esclamazioni, coriandoli e enfasi: alcuni ragazzi vivono il
  festeggiamento come rumore, non come premio.
- I **punteggi si possono nascondere**: per chi il numero lo trasforma in ansia.
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

- Bersagli tattili/clic minimo 44×44 pt, ovunque — compresi i controlli che disegna
  macOS (interruttori, cursori, elenchi a comparsa), che di serie sono alti fra i 16 e i
  26 pt e qui passano dagli involucri di `Sources/Design/Components.swift`. Nel profilo
  «I comandi piccoli sono difficili da prendere» il minimo sale a 60 pt.
  Misurato da `Verifiche/Bersagli.swift` sull'altezza resa, non su quella dichiarata.
- Contrasto WCAG 2.1 **AAA (7:1)** su tutto quello che l'app scrive — testo, esiti,
  scritte sui pulsanti — in tutti e quattro i temi e per tutti e cinque i modi di vedere
  i colori. Le forme che portano informazione senza essere testo (l'oro di un obiettivo
  conquistato, la fiamma dei giorni di fila, il rosso del comando che ferma) stanno a
  3:1, che è la soglia che la WCAG chiede per loro. Misurato da `Verifiche/Contrasto.swift`
  su tutte e venti le combinazioni, non a occhio.
- Focus da tastiera sempre visibile; ogni schermata è percorribile senza mouse.
- Etichette VoiceOver su ogni controllo; le decorazioni sono nascoste allo screen reader.
- Le dimensioni si moltiplicano fino a ×2 sopra il valore già grande di partenza.

## Tastiera e VoiceOver: che cosa è stato verificato

Queste righe raccontano prove fatte, non intenzioni.

- **Una sessione intera senza mouse.** Modalità «Scrivi», venti parole, dal
  pulsante «Via!» fino al riepilogo e dentro il minigioco, solo da tastiera.
- **Esc chiude tutto.** Impostazioni, aiuto, «I tuoi progressi», la prova del
  microfono, «Prepara il Mac», il premio di fine sessione e la schermata
  «Pronti?». Prima tre di queste si chiudevano solo col mouse, e una prometteva
  Esc senza rispondere.
- **Le etichette si leggono con una sonda diretta**, non a occhio: SwiftUI
  scrive `.accessibilityLabel` dentro `AXDescription`, non dentro `AXTitle`, e
  un albero letto male fa «correggere» problemi che non esistono.
- **Ogni cursore dice il proprio nome e il proprio valore** con le stesse
  parole scritte accanto — non una percentuale.
- **Le decorazioni tacciono.** Un `Image` dentro un `.overlay` su un `Button`
  diventa un pulsante a sé: nella schermata iniziale ce n'era uno, chiamato
  «Selezionato», che non faceva niente.
- **Quello che conta parla.** Il segno di esito resta leggibile a voce quando
  il punteggio è nascosto: lì è l'unica cosa che dice «Giusta» o «Ancora».
