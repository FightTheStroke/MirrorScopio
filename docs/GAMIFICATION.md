# Punti, serie e obiettivi

La gamification qui ha un compito preciso: **far tornare il ragazzo domani.** Un esercizio
di lettura funziona se è frequente, e la frequenza è un problema di motivazione, non di
didattica.

E ha un limite altrettanto preciso: **non deve mai diventare la ragione per cui si mente.**
Niente classifiche fra persone, niente punti che si perdono, niente penalità.

## Punti

| Azione | Punti |
|---|---|
| Ogni parola presa | 10 |
| Sessione completata (almeno una parola) | 20 |

Sorgente di verità: `Gamification.xp(for:streak:)` in
[`Sources/Data/Gamification.swift`](../Sources/Data/Gamification.swift). Se questa tabella
e il codice divergono, ha ragione il codice — e la tabella va corretta.

I punti **non si tolgono mai**. Una brutta giornata vale meno, non vale in negativo.

Un livello ogni **500 punti**. (MirrorBuddy usa 1000; qui le sessioni sono più brevi, quindi
la soglia è più bassa per mantenere lo stesso ritmo percepito.)

## Serie

Giorni consecutivi con almeno una sessione. La serie moltiplica i punti:

| Giorni | Moltiplicatore |
|---|---|
| 0 (prima sessione in assoluto) | ×1,0 |
| 1–2 | ×1,1 |
| 3–6 | ×1,25 |
| 7 e oltre | ×1,5 |

La serie si interrompe saltando un giorno, e quando si interrompe l'app **non lo rinfaccia**:
riparte e basta. Trasformare una serie persa in un rimprovero è il modo più rapido per far
smettere qualcuno.

## Obiettivi

Nove, sbloccabili una volta sola. Alcuni premiano il risultato, altri semplicemente
l'esserci — che per molti ragazzi è la parte difficile.

| Obiettivo | Come si prende |
|---|---|
| Si comincia | Prima sessione completata |
| En plein | Una sessione intera senza errori |
| Dieci in fila | Dieci parole giuste nella stessa sessione |
| Tre giorni di fila | Serie di 3 giorni |
| Una settimana intera | Serie di 7 giorni |
| Occhio da falco | Una parola letta sotto i 200 ms |
| Più veloce del lampo | Una parola letta sotto i 100 ms |
| So anche scriverle | Prima sessione in modalità Scrivi |
| Dieci sessioni | Dieci sessioni completate |

Ogni obiettivo ha il suo simbolo (`Achievement.symbol`), e quel simbolo si vede
**sempre**: pieno, con una medaglia e un segno di spunta, quando è conquistato;
tenue, dentro un cerchio tratteggiato con un piccolo lucchetto in un angolo,
finché è ancora da prendere. Non più un lucchetto uguale per tutti: si capisce
sempre *che cosa* si può conquistare. La differenza fra i due stati non è
affidata al colore — cambiano la forma del bordo e il segnale nell'angolo — così
si legge anche in bianco e nero e da chi i colori non li distingue.

## Livelli e distintivi

Un livello ogni 500 punti (vedi sopra). I livelli sono raccolti in sei fasce, e
ogni fascia ha un nome e un suo distintivo. Sorgente di verità:
`Gamification.levelName(_:)` e `Gamification.levelSymbol(_:)`.

| Livelli | Fascia | Simbolo del distintivo |
|---|---|---|
| 1–2 | Esploratore | binocolo |
| 3–5 | Lettore curioso | libro |
| 6–9 | Occhio veloce | occhio |
| 10–14 | Lampo | fulmine |
| 15–20 | Maestro dei lampi | fiamma |
| 21 e oltre | Leggenda | corona |

Il distintivo del livello ha un anello diviso in sei spicchi, uno per fascia:
sono pieni gli spicchi già raggiunti. Più anello pieno vuol dire fascia più alta,
e questo si vede anche in bianco e nero — si capisce che Leggenda viene dopo
Esploratore senza dover leggere il numero.

Con la **modalità calma** i distintivi restano, ma sobri: niente oro acceso,
nessun luccichio, nessuna animazione. La forma continua a distinguere gli stati
anche senza colore.

## Cosa non c'è, di proposito

- **Nessuna classifica.** I dati non escono dal Mac e non c'è nessuno con cui confrontarsi.
  Il confronto è solo con sé stessi la settimana scorsa.
- **Nessuna vita da perdere, nessun timer che incalza.** La fretta è esattamente il nemico
  di chi ha un disturbo di lettura.
- **Nessun premio per la velocità pura.** I punti seguono le parole prese, non i
  millisecondi: altrimenti la strategia vincente diventa indovinare.

## Per chi tutto questo dà fastidio

Nelle impostazioni si può:

- **nascondere i punteggi**, per chi dai numeri prende ansia;
- attivare la **modalità calma**, che toglie esclamazioni e festeggiamenti.

Con entrambe attive resta un tachistoscopio pulito, senza una sola coriandolo. Per alcuni
ragazzi è l'unica versione usabile.
