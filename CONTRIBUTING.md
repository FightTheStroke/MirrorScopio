# Contribuire a MirrorScopio

Grazie per l'interesse. Questo documento dice come si lavora qui e, soprattutto,
**che cosa non è negoziabile**.

MirrorScopio è fatto da una fondazione piccola per ragazzi veri. Il contributo
più prezioso quasi mai è una pull request: è qualcuno che ci dice **che cosa
non ha funzionato con suo figlio martedì pomeriggio**.

## Contribuire senza scrivere una riga di codice

Se non sviluppi, questa è la parte che conta.

**Racconta com'è andata.** Apri una
[discussione](https://github.com/FightTheStroke/MirrorScopio/discussions) e
scrivi che cosa è successo davvero: dove si è bloccato, che cosa non ha capito,
in che punto ha smesso di avere voglia. Non serve che sia ordinato. Se una
persona ha smesso di usare l'app dopo due giorni, sapere *perché* vale più di
dieci funzioni nuove.

**Segnala qualcosa che non va.** Le [issue](https://github.com/FightTheStroke/MirrorScopio/issues)
sono aperte a tutti. Non serve linguaggio tecnico: «la parola sparisce prima
che riesca a guardarla» è una segnalazione perfetta.

**Vota che cosa viene dopo.** Ti serve in un'altra lingua o su un altro
computer? Bastano due clic:
[la lingua](https://github.com/FightTheStroke/MirrorScopio/discussions/1) ·
[la piattaforma](https://github.com/FightTheStroke/MirrorScopio/discussions/2).

**Se lavori sulla lettura** — logopedista, insegnante, ricercatore — sei la
persona di cui abbiamo più bisogno. Le liste di parole, la progressione delle
difficoltà, il modo in cui si classifica un errore: quello è il pezzo che il
codice non può inventare. Guarda [`docs/CLINICA.md`](docs/CLINICA.md) e dicci
dove sbagliamo.

**Traduci.** L'interfaccia si traduce volentieri. Le liste di parole no, non da
sole: vanno costruite con qualcuno che lavori sulla lettura in quella lingua
(vedi sopra).

**Sostieni il lavoro.** L'app è gratuita, senza pubblicità e senza account, e
resterà così. Se vuoi che continui:
**[sostieni Fight The Stroke](https://www.fightthestroke.org/donorbox)**.

Se preferisci scrivere a una persona invece che su GitHub:
[info@fightthestroke.org](mailto:info@fightthestroke.org?subject=MirrorScopio).

---

## Le tre regole che vengono prima di tutto

1. **L'utente primario è il ragazzo o la ragazza che legge.** Non il logopedista,
   non il genitore, non lo sviluppatore. Se una funzione rende l'app più
   completa per l'adulto e più confusa per il bambino, non entra.
2. **Niente esce dal Mac.** Nessun account, nessuna telemetria, nessuna
   chiamata di rete con i dati di chi usa l'app. Una pull request che introduce
   una dipendenza di rete sui dati viene rifiutata, per quanto sia utile.
3. **Il verdetto è deterministico.** Giusto o sbagliato si decide con un
   confronto testuale normalizzato, riproducibile e verificabile. Il modello
   linguistico può etichettare *il tipo* di errore, non ribaltare l'esito.
   Motivo concreto: in prova libera il modello aveva dichiarato corretta
   «volato» per *tavolo*.

Il razionale completo è in [`AGENTS.md`](AGENTS.md).

## Prima di scrivere codice

Apri una issue e descrivi il problema in termini di **chi legge**, non in
termini di implementazione. «I bambini con ADHD perdono il filo dopo la decima
parola» è una buona issue. «Aggiungere un timer configurabile» non lo è ancora.

Per cambiamenti che toccano l'accessibilità o la parte clinica, dillo
esplicitamente nella issue: vanno discussi prima, non in fase di review.

## Come si lavora

```bash
git clone https://github.com/FightTheStroke/MirrorScopio.git
cd MirrorScopio
./build.sh                 # compila e firma (ad-hoc se non hai il certificato)
open build/MirrorScopio.app
./test.sh --all            # tutte le verifiche
./scripts/genera-progetto.sh   # solo se vuoi lavorare dentro Xcode
```

Serve **macOS 26** o successivo e un Mac Apple Silicon. `build.sh` chiama
`swiftc` direttamente: per compilare non serve aprire nulla.

Il progetto Xcode non sta nel repository: nasce da `project.yml` e lo rigenera
`scripts/genera-progetto.sh`, che gli scrive dentro la versione presa dal file
`VERSION`. **Quello che cambi a mano nella scheda «General» di Xcode viene
perso alla rigenerazione: si cambia `project.yml`.**

## Regole di stile

- **La lingua del progetto è l'italiano**, nel codice, nei commenti, nei commit
  e nell'interfaccia. I nomi dei tipi Swift restano in inglese dove seguono
  convenzioni di sistema.
- **I commenti spiegano il perché, mai il cosa.** Un commento che ripete quello
  che il codice già dice è rumore. Un commento che spiega perché una strada
  ovvia non funziona vale oro — e in questo progetto ce ne sono parecchi,
  pagati caro.
- Niente `try!`, niente force unwrap su valori che possono davvero mancare.
- I testi dell'interfaccia si scrivono per un ragazzino di dieci anni: frasi
  corte, nessun termine tecnico non spiegato nella stessa frase.
- **Non si disegna niente da zero.** I mattoncini stanno in
  `Sources/Design/Components.swift`, le misure in `Metrica`, i colori in
  `Palette`: se una schermata riscrive un pulsante invece di usare quello
  condiviso, fra tre mesi le due copie saranno diverse — è già successo, ed è
  così che chiudere una schermata era finito per essere fatto in sei modi.
  Il documento è [`docs/DESIGN.md`](docs/DESIGN.md), e in fondo ci sono tre
  `grep` che devono restare vuoti.

## Verifiche prima di proporre una modifica

```bash
./build.sh && ./test.sh --all
```

Devono passare. Se tocchi il riconoscimento vocale, `Tests/StreamHarness.swift`
è la verifica che conta: esercita la catena completa con voce sintetizzata,
senza microfono, e avrebbe intercettato il guasto più grave che questo progetto
abbia avuto.

Se una cosa non l'hai verificata, **scrivilo**. «Compila» e «funziona» sono due
affermazioni diverse.

## Commit e versioni

- Un commit racconta una cosa sola, e il messaggio dice *perché*, non *cosa*.
- Il [`CHANGELOG.md`](CHANGELOG.md) è scritto per chi usa l'app, non per chi
  scrive il codice. Ogni voce va sotto `[Non ancora rilasciato]`.
- Le versioni seguono [SemVer](https://semver.org/lang/it/) e si pubblicano con
  `./scripts/release.sh <versione>`. Il pacchetto lo costruisce GitHub. In alternativa
  basta alzare `VERSION` e scrivere il diario in una proposta di modifica: quando è fusa
  e le prove sono passate, la pubblicazione parte da sé.

## Segnalare un problema di sicurezza o di privacy

Non aprire una issue pubblica: vedi [`SECURITY.md`](SECURITY.md).

## Licenza, e perché ti chiediamo una firma

Proponendo una modifica accetti che venga distribuita sotto
[Apache License 2.0](LICENSE), la stessa del resto del progetto.

Ti chiediamo anche una cosa in più, e ti spieghiamo perché.

MirrorScopio lo fa una fondazione, senza pubblicità e senza vendere dati. Un
giorno, per tenerlo in piedi, potrebbe servire vendere licenze a chi ci fa
business — enti, aziende, editori. Se nel codice c'è una riga scritta da te e
tu non ci hai dato il permesso, quel giorno dovremmo chiederti il consenso, o
riscrivere quel pezzo. Con dieci persone diventa impossibile, e finisce che non
si fa: cioè il progetto perde una strada per sopravvivere.

Per questo, alla tua prima proposta di modifica, ti chiediamo di accettare una
**liberatoria**: resti l'autore di quello che hai scritto, il tuo nome resta
nello storico, il tuo lavoro resta libero per tutti sotto Apache 2.0 — e in più
concedi alla Fight The Stroke Foundation il diritto di distribuire quel codice
anche con una licenza diversa, se un domani servisse.

Non ti toglie niente, e non ti impegna a niente. Se questa cosa non ti va bene,
dillo: preferiamo saperlo prima e discuterne, piuttosto che scoprirlo dopo.

Il ragionamento per esteso, comprese le condizioni a cui la licenza si
rivedrebbe, è in [`docs/STRATEGIA-LICENZA.md`](docs/STRATEGIA-LICENZA.md).

**Il nome è un'altra cosa dal codice.** «MirrorScopio», il logo e «Fight The
Stroke» non sono coperti dalla licenza: puoi partire da questo codice e farne
quello che vuoi, ma la tua cosa deve chiamarsi in un altro modo e non deve far
credere che sia nostra.
