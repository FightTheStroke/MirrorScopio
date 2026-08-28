# Il sistema di disegno di MirrorScopio

Questo documento esiste per un motivo pratico: **cambiare una cosa in un posto
solo e vederla cambiare dappertutto.** Non è una guida di stile da ammirare, è
l'elenco dei pochi mattoncini con cui è fatta l'app e la regola per cui non se
ne aggiungono altri senza una ragione.

## Perché la coerenza qui non è estetica

Chi usa MirrorScopio ha dislessia, autismo, ADHD, ipovisione o paralisi
cerebrale. Per queste persone **ogni forma nuova è una cosa nuova da
imparare**. Un'app che chiude una schermata con un pulsante blu, quella dopo
con un rettangolo grigio e quella dopo ancora con una scritta in un angolo non
è «poco curata»: è un'app che chiede di imparare la stessa cosa tre volte, e
la terza volta si smette.

Era esattamente così: prima di questo documento, chiudere una schermata era
fatto in **sei modi diversi**.

## I mattoncini — `Sources/Design/Components.swift`

Se una schermata ha bisogno di uno di questi, **non lo riscrive**. Se un
mattoncino non esiste, si aggiunge lì e lo usano tutti.

| Componente | A che serve |
|---|---|
| `PulsanteChiudi` | L'unico modo di chiudere. Dice sempre «Chiudi», mai «Fine». |
| `IntestazionePagina` | Titolo a sinistra, uscita a destra, sempre nello stesso punto. |
| `BigButton` | L'azione principale di una schermata. `prominent: false` per le secondarie. |
| `SmallButton` | Il bottone di servizio. `prominente: true` per l'azione che sblocca; `distruttivo: true` per ciò che non si annulla. |
| `ChoiceCard` | Una scelta fra poche, grande e cliccabile. |
| `SectionTitle` | Titolo di sezione, sempre della stessa taglia. |
| `Explain` | Il testo che dice *perché*. Mai per riempire. |
| `Verdict` | L'esito di una parola: colore **e** forma **e** parola. |
| `StopButton` | Fermarsi. Ha un rosso suo, diverso da quello delle risposte. |
| `ProgressoPallini` | A che punto si è. Uguale in «Leggi» e in «Scrivi». |
| `Celebrazione` | I coriandoli di fine sessione. Si spengono da soli in modalità calma. |

## Le misure — `Metrica`

Quattro raggi e dieci distanze. Erano dieci raggi diversi scritti a mano
dentro le viste (2, 3, 7, 8, 10, 11, 12, 14, 16, 18), e divergevano perfino
fra i componenti condivisi. Le distanze erano 210 numeri sparsi su 21 valori
(3, 5, 7, 9, 10, 14, 18, 22, 24, 28, 36...): nessuno li aveva decisi, erano
capitati guardando una schermata alla volta.

I passi sono radi apposta. Due distanze devono essere **o uguali o chiaramente
diverse**: due punti di differenza non li decide nessuno e non li vede nessuno,
ma tolgono ritmo alla pagina. E il ritmo qui non e' estetica — se lo spazio fra
due cose vuol dire sempre la stessa cosa, aiuta a capire che cosa sta con che
cosa anche a chi legge con fatica.

```
raggioMinimo   3   pallini, barrette, cose piccole dentro altre cose
raggioPiccolo 10   righe di elenco, campi, pulsanti di servizio
raggio        14   carte, riquadri, gruppi
raggioGrande  18   pannelli grandi e pulsanti principali

filo           2   due cose attaccate: un'icona e la sua parola
briciola       4   quasi attaccate
spazioMinimo   6   fra due cose che sono la stessa cosa
spazioStretto  8   dentro un elemento: il respiro di un pulsante piccolo
spazioPiccolo 12   fra le righe di un gruppo
spazioMedio   16   fra due gruppi vicini
spazio        20   fra un gruppo e l'altro
spazioLargo   24   il respiro dentro un riquadro
spazioGrande  32   fra una sezione e l'altra
spazioEnorme  40   attorno alle cose che devono stare da sole
margine       26   attorno al contenuto di una pagina

bersaglio     44   il lato minimo di qualunque cosa si possa premere
```

**Se serve un valore che non è qui, quasi sempre la risposta giusta è usare
quello più vicino.** I 44 punti non sono l'obiettivo, sono il minimo assoluto:
chi ha paralisi cerebrale colpisce un bersaglio di 44 punti a fatica, e dove
si può il bersaglio è più grande (`StopButton` sta a 60).

## I colori — `Palette`, in `Theme.swift`

Nessuna vista scrive un colore a mano. Si prende dall'ambiente:

```swift
@Environment(\.palette) private var palette
```

`background`, `surface`, `foreground`, `muted`, `accent`, `ok`, `wrong`,
`isDark`. Cambiano insieme al tema scelto (chiaro, scuro, altissimo
contrasto, carta) e al modo in cui la persona vede i colori.

**Mai gli stili di sistema.** `.buttonStyle(.borderedProminent)` usa il blu di
macOS, che *non segue il tema*: con «Altissimo contrasto» il comando più
importante della schermata restava blu su nero, cioè la cosa meno visibile
dello schermo proprio per chi ha scelto quel tema perché vede poco. Stessa
cosa per `.secondary` e `.gray`: si usa `palette.muted`.

## Il testo — sette taglie

Sempre `a11y.font(.ruolo)`, mai un numero.

```
nota          13   note a margine, unita' di misura, didascalie
etichetta     15   etichette, voci secondarie, testo dentro elementi piccoli
corpo         17   il testo normale: quello che si legge davvero
guida         20   testo guida, voci di elenco, pulsanti
sezione       24   titoletti di sezione dentro una pagina
titolo        30   il titolo di una pagina
titoloGrande  40   i numeri grandi e le poche parole da vedere da lontano
```

Il peso si passa come secondo argomento: `a11y.font(.corpo, .semibold)`.

Erano venti taglie diverse su circa 180 punti di chiamata — 15 qui, 16 la', 14
nella riga accanto. Differenze di un punto che nessuno decide e nessuno vede
una per una, ma che insieme fanno una pagina senza gerarchia. Sette taglie
distanti fra loro si distinguono a colpo d'occhio, ed e' esattamente quello che
serve a chi fatica a leggere: capire che cosa e' titolo e che cosa e' nota
senza doverlo decifrare.

- `a11y.typeface` è il carattere **scelto dalla persona** — chi ha scelto
  OpenDyslexic o Atkinson se lo aspetta ovunque, non solo nelle schermate a
  cui qualcuno si è ricordato di applicarlo. `font(_:_:)` lo applica da solo.
- L'ingrandimento è già dentro: le sette taglie sono quelle *di partenza*, e
  vengono moltiplicate per «Dimensione di tutto». Un `Text` con taglia fissa
  non cresce, e quella è l'impostazione per cui qualcuno ha aperto le opzioni.

Restano fuori dalla scala tre casi, e sono legittimi: la parola-stimolo (la
sua taglia la sceglie la persona), i numeri dentro le medaglie (proporzionali
al lato della medaglia) e i simboli SF.

Unica eccezione legittima: `.font(.system(size:))` su un `Image(systemName:)`,
perché il carattere non si applica ai simboli SF.

## Le animazioni

Sempre `a11y.animation(durata)`, mai `.animation(.easeInOut(...))` diretta:
è quella funzione a rispettare «meno animazioni» e la modalità calma. Per chi
ha ipersensibilità sensoriale un'animazione non richiesta non è un tocco di
classe, è un'aggressione.

## Le parole

Vincolate da [`AGENTS.md`](../AGENTS.md), e valgono anche qui:

- **Mai «sbagliato», «errore», «fallito».** Si dice **«Ancora»**: la parola non
  è venuta *ancora*. Vale anche nei referti e nelle esportazioni, che il
  ragazzo non legge ma il genitore stampa e porta alla logopedista.
- **Mai una croce** per un esito. La croce dice «hai sbagliato», e a chi
  sbaglia da anni quella croce è già arrivata abbastanza volte. Si usa
  `ColorVision.wrongSymbol`, una freccia che torna indietro: resta una forma
  nettamente diversa dal segno di spunta, quindi funziona anche per chi non
  distingue i colori.
- **Mai definire una persona per ciò che le manca.** Nell'app non c'è una
  modalità «Normale»: c'è «Distinguo tutti i colori».
- **Niente gergo non spiegato.** Se una parola tecnica serve, si dice cosa
  vuol dire nella stessa frase.

## Le regole che non si negoziano

1. **Il colore da solo non porta mai un'informazione.** Sempre colore **più**
   forma **più** parola.
2. **Da ogni schermata si esce con Esc.** Se l'unica via d'uscita è il mouse,
   chi il mouse non lo usa resta dentro.
3. **Ogni `Image(systemName:)` cliccabile ha un `accessibilityLabel`.** Le
   icone decorative hanno `accessibilityHidden(true)`, altrimenti VoiceOver
   legge una filastrocca di nomi di simboli.
4. **Fermarsi è la cosa più facile dello schermo**, non la più difficile.

## Come si controlla che regga

Il modo che ha funzionato: un **agente avversariale in sola lettura** a cui si
chiede di trovare solo incoerenze e violazioni, con `file:riga`, e a cui si
vieta di fare complimenti. È così che sono usciti i sei modi di chiudere, la
croce rossa sulle giornate storte, il blu di sistema che vanificava
l'altissimo contrasto e la pagina clinica che ignorava tema e carattere.

E un banco che **disegna l'interfaccia**: `./test.sh` produce
`build/schermate/*.png` con i mattoncini in tutti e quattro i temi e
ingranditi con OpenDyslexic, e poi verifica da solo tre cose:

- il **contrasto** di ogni parola in tutte e venti le combinazioni di tema e
  modo di vedere i colori (8 accostamenti ciascuna, soglia 4,5 a 1);
- che tutte le **schermate intere scorrano**, perché chi ingrandisce il testo
  altrimenti perde i pulsanti sotto il bordo senza rimedio;
- che il controllo del contrasto **sappia ancora bocciare** bianco su giallo —
  prima di fidarsi di un controllo bisogna vederlo fallire.

Serve perché l'accessibilità di sistema può non rispondere, e allora l'unico
modo di «vedere» una schermata è leggere il codice e immaginarsela.
Immaginarsela non basta: è così che i pulsanti principali sono finiti bianchi
su giallo, e che «Pronti?» è rimasta per mesi più alta della finestra.

Due controlli rapidi che valgono ogni volta:

```sh
grep -rn "cornerRadius: [0-9]"      Sources/   # dev'essere vuoto
grep -rn "borderedProminent\|\.bordered\b"  Sources/   # dev'essere vuoto
grep -rn "foregroundStyle(\.secondary\|\.gray)" Sources/   # dev'essere vuoto
```
