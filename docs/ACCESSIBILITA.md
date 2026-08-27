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
| **Dislessia** | OpenDyslexic, lettere più distanziate, righe più larghe, testo più grande |
| **Autismo** | Niente animazioni, niente distrazioni, niente esclamazioni, pause frequenti. **Contrasto medio, non alto** |
| **ADHD** | Sessioni brevi, pause automatiche, schermo pulito, feedback immediato |
| **Ipovisione** | Testo molto grande, altissimo contrasto, Atkinson Hyperlegible |
| **Paralisi cerebrale** | Tempi di risposta lunghi, bersagli grandi, nessuna fretta |

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

- Bersagli tattili/clic minimo 44×44 pt, ovunque.
- Contrasto WCAG 2.1 AA sui testi, AAA nelle schermate del ragazzo.
- Focus da tastiera sempre visibile; ogni schermata è percorribile senza mouse.
- Etichette VoiceOver su ogni controllo; le decorazioni sono nascoste allo screen reader.
- Le dimensioni si moltiplicano fino a ×2 sopra il valore già grande di partenza.
