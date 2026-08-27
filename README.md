# MirrorScopio

**Un tachistoscopio che si usa da solo.** Una parola compare per un lampo, chi legge la
dice ad alta voce, il Mac la ascolta e capisce da sé se è giusta. Nessun adulto deve stare
lì a segnare le risposte.

Progetto della **Fight The Stroke Foundation**, sorella di
[MirrorBuddy](https://github.com/FightTheStroke/MirrorBuddy), da cui eredita i principi di
progettazione inclusiva.

> ⚠️ **Avvertenza.** La presentazione rapida comporta rapidi cambi di luminanza. Non usare
> con persone con epilessia fotosensibile senza parere medico. MirrorScopio è uno strumento
> di esercizio e di osservazione, **non** un dispositivo diagnostico.

---

## Che cos'è un tachistoscopio

Uno strumento usato da logopedisti e neuropsicologi: mostra uno stimolo visivo per un tempo
brevissimo e misurato — decine o centinaia di millesimi di secondo — poi lo copre. Serve a
esercitare e a misurare la **lettura globale**: riconoscere la parola tutta insieme invece
di decifrarla lettera per lettera. È uno degli esercizi classici nella riabilitazione della
dislessia evolutiva.

MirrorScopio fa due cose che gli strumenti tradizionali non fanno:

1. **Valuta da solo.** Il riconoscimento vocale gira interamente sul Mac (Speech framework
   di macOS 26). Nessun operatore deve premere "giusto/sbagliato" dopo ogni parola.
2. **Si adatta.** La velocità sale e scende da sola inseguendo la soglia di chi legge, e a
   fine sessione l'app propone di cambiare livello se è troppo facile o troppo difficile.

## Due modalità

| | Che cosa succede | Che cosa allena |
|---|---|---|
| **Leggi** | Lampeggia una parola, la si legge ad alta voce | Lettura globale, ampiezza dello sguardo, velocità di riconoscimento |
| **Scrivi** | Il Mac detta una parola, la si scrive | Conversione suono → lettera, ortografia |

## Come funziona una sessione

1. **Prova iniziale** (una volta sola) — otto parole a velocità calante misurano da dove
   partire. Né troppo facile da annoiare, né troppo difficile da scoraggiare.
2. **Riscaldamento** — le prime parole restano visibili il triplo del tempo e non contano
   per la misura.
3. **Sessione** — croce di fissazione → parola → maschera → ascolto → esito. Tutto
   automatico, nessun tasto da premere.
4. **Risultato** — quante ne ha prese, quali sono scappate, stelle e obiettivi. Il dettaglio
   clinico (soglia, latenza vocale, tipo di errore, referto PDF) sta chiuso sotto
   "Dettaglio per l'adulto".

## Accessibilità

MirrorScopio è pensato per ragazzi con dislessia, autismo, ADHD, ipovisione, paralisi
cerebrale. **Un profilo imposta tutto in un colpo solo**; poi ogni singola manopola resta
regolabile.

- **Caratteri**: OpenDyslexic, Atkinson Hyperlegible, Lexend (tutti SIL OFL, inclusi
  nell'app), oltre a quelli di sistema.
- **Temi**: chiaro, scuro, altissimo contrasto, carta color crema.
- **Daltonismo**: palette per deuteranopia, protanopia, tritanopia e monocromia. Giusto e
  sbagliato **non si distinguono mai solo dal colore**: c'è sempre anche un simbolo e una
  parola.
- **Movimento**: si può togliere ogni animazione.
- **Calma**: modalità senza esclamazioni né festeggiamenti, per chi li vive come rumore.
- **Punteggi nascosti**: per chi si mette in ansia con i numeri.
- **Pause automatiche** ogni N parole, senza conto alla rovescia.
- Tutto è grande e ogni dimensione si moltiplica fino a ×2.

Dettagli e razionale: [`docs/ACCESSIBILITA.md`](docs/ACCESSIBILITA.md).

## Privacy

**Niente esce da questo Mac.** Nessun account, nessuna rete, nessun servizio esterno. La
voce viene trascritta dal modello on-device, l'analisi degli errori usa i Foundation Models
di Apple che girano in locale, e i dati stanno in file JSON leggibili in
`~/Library/Application Support/MirrorScopio/`, che un adulto può aprire o cancellare a mano.

## Requisiti

- macOS 26 o successivo, Mac con Apple Silicon
- Apple Intelligence attivo (facoltativo: senza, l'app funziona lo stesso, perde solo
  l'etichettatura clinica degli errori)
- Il pacchetto lingua italiana per il riconoscimento vocale (macOS lo scarica da sé alla
  prima richiesta)

## Compilare ed eseguire

```bash
./build.sh          # compila e firma
open build/MirrorScopio.app
./test.sh           # esegue gli harness di verifica
```

Non c'è un progetto Xcode: `build.sh` invoca `swiftc` direttamente. È voluto — l'app deve
restare compilabile e leggibile senza aprire nulla.

La firma usa il certificato **Developer ID Application: Fight The Stroke Foundation** se è
presente nel portachiavi; altrimenti ripiega su una firma ad-hoc, così un clone fresco
compila su qualunque Mac.

## Portarla su un altro Mac

```bash
./scripts/package.sh --notarize     # → build/MirrorScopio-<versione>.dmg
```

Firmata Developer ID di Fight The Stroke e notarizzata da Apple: si apre senza
avvisi e senza Xcode. Il perché di ogni passaggio, e la credenziale da salvare
una volta sola, sono in [`docs/DISTRIBUZIONE.md`](docs/DISTRIBUZIONE.md).

## Documentazione

- [`docs/ARCHITETTURA.md`](docs/ARCHITETTURA.md) — com'è fatta dentro
- [`docs/ACCESSIBILITA.md`](docs/ACCESSIBILITA.md) — scelte inclusive e perché
- [`docs/CLINICA.md`](docs/CLINICA.md) — scala adattiva, soglia, tipi di errore
- [`docs/GAMIFICATION.md`](docs/GAMIFICATION.md) — punti, serie, obiettivi
- [`docs/DISTRIBUZIONE.md`](docs/DISTRIBUZIONE.md) — firmare, notarizzare, portarla su un altro Mac
- [`AGENTS.md`](AGENTS.md) — istruzioni per chi ci lavora, umano o agente

## Licenza

Codice: vedi [`LICENSE`](LICENSE). Caratteri inclusi: SIL Open Font License 1.1, vedi
[`Resources/Fonts/LICENSES.md`](Resources/Fonts/LICENSES.md).
