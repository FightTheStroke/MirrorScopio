# Portare MirrorScopio su un altro Mac

## In automatico, su GitHub (consigliato)

Una volta sola, per insegnare a GitHub a firmare:

```bash
./scripts/setup-github-secrets.sh
```

Chiede due sole cose: l'Apple ID e la password per app. Il certificato di firma
lo prende da solo dal portachiavi, tiene **soltanto** il «Developer ID
Application» (le altre identità restano dov'erano) e prima di spedire niente
prova a importarlo in un portachiavi usa-e-getta — la stessa cosa che farà
GitHub, fatta qui dove si può ancora rimediare.

Da quel momento ogni tag `v*` fa partire il workflow **Rilascio**: GitHub
compila su un Mac vero (macOS 26), firma con il certificato di Fight The Stroke,
manda l'app ad Apple per la notarizzazione, attacca il timbro, controlla che
Gatekeeper la accetti e **allega alla release due file**: il DMG e uno zip.

Servono a due persone diverse, e servono tutti e due:

- il **DMG** è per chi installa la prima volta: si apre, si trascina l'icona
  nelle Applicazioni;
- lo **zip** è per MirrorScopio stesso. Le versioni già installate lo scaricano
  quando un adulto preme «Aggiorna e riavvia» nelle impostazioni. Se una
  release non ha lo zip non è rotta, ma costringe tutti a reinstallare a mano.

Prima di allegarli il workflow apre lo zip e ricontrolla esattamente quello che
ricontrollerà l'app sul Mac di una famiglia: la firma è la nostra, e il timbro
di Apple è attaccato addosso — cioè si può verificare anche senza internet.

Pubblicare una versione diventa:

```bash
./scripts/release.sh 0.3.0
```

Il workflow **Verifica** gira invece a ogni push: compila, controlla che in
`Sources/` non ci sia una riga di rete, che il progetto Xcode sia allineato al
file che lo genera, che il risultato sia davvero un'app avviabile, che versione
e diario siano allineati, e che **tutte le prove passino**. Non serve nessun
segreto.

## Chi preme il tasto: nessuno

Per mesi la pubblicazione è stata un comando dato a mano, ed è andata come va
sempre in questi casi: il 28 agosto 2026 sette correzioni sono state finite e
fuse nel ramo principale, e la versione scaricabile è rimasta indietro di otto
ore. Il lavoro era fatto, l'impianto funzionava, ma nessuno aveva dato il via —
e chi usava l'app non stava usando quello che avevamo corretto per lei.

Adesso c'è un terzo workflow, **Pubblicazione**. Aspetta che «Verifica» finisca
verde sul ramo principale, poi guarda `VERSION`:

- se quel numero **ha già** la sua etichetta, non fa niente e lo scrive nel
  riepilogo. È il caso normale di una correzione fusa senza cambiare versione:
  non è un errore e non colora di rosso niente;
- se il numero **è nuovo**, controlla che nel diario ci sia la sua sezione — una
  versione che nessuno può capire non si pubblica — mette l'etichetta e da lì in
  poi riparte tutto quello che c'era già: firma, timbro di Apple, pacchetto
  allegato.

**Che cosa resta una decisione umana: il numero.** Di proposito. Un rilascio a
ogni fusione vorrebbe dire cinque aggiornamenti da scaricare in un pomeriggio e
un diario che nessuno legge. Quindi il gesto per pubblicare resta uno solo, ed è
quello di sempre:

```bash
./scripts/release.sh 0.7.0
```

o, se si preferisce, si alza `VERSION` e si scrive il diario dentro una normale
proposta di modifica: quando viene fusa e le prove passano, la pubblicazione
parte da sé.

**Se la pubblicazione non parte**, la causa quasi certa è la chiave
`CHIAVE_RILASCIO` scaduta. Serve a mettere l'etichetta e nient'altro — non apre
il portachiavi di firma. Si rifà da github.com → Settings → Developer settings →
Fine-grained tokens, con il solo permesso «Contents: Read and write» su questo
progetto, e si rimette nei segreti con quel nome. Il workflow se ne accorge da
solo e si ferma dicendolo, invece di tacere.

## A mano, da questo Mac

```bash
./scripts/package.sh --notarize     # → build/MirrorScopio-<versione>.dmg
                                    #   build/MirrorScopio-<versione>.zip
```

Il DMG che ne esce si apre su qualunque Mac con macOS 26, senza tasto destro,
senza avvisi e senza Xcode. Lo zip accanto è quello che l'app scarica quando si
aggiorna da sola: si crea con `ditto` e non con `zip`, perché `zip` perde
permessi e collegamenti interni e la firma arriverebbe a destinazione rotta.

## Che cosa serve, e perché

| Pezzo | Stato | A che serve |
|---|---|---|
| Certificato **Developer ID Application** (Fight The Stroke, `93T3LG4NPG`) | già presente | dice a macOS chi ha fatto l'app |
| **Hardened runtime** | già attivo | condizione per notarizzare |
| **Marca temporale** | con `TIMESTAMP=1 ./build.sh` | l'app resta valida anche quando il certificato scade |
| **Notarizzazione** | serve una credenziale, vedi sotto | senza, Gatekeeper blocca l'app su un Mac diverso da questo |
| **Stapling** | automatico dopo la notarizzazione | il timbro viaggia nel file: funziona anche offline |

Firmare non basta. Un'app firmata ma non notarizzata, su un altro Mac, dà
*«impossibile verificare lo sviluppatore»*. Da macOS 15 non basta più il tasto
destro › Apri: bisogna passare da Impostazioni di Sistema › Privacy e sicurezza.
Per una famiglia è un muro. Perciò: si notarizza.

## La credenziale, una volta sola

```bash
./scripts/setup-notarizzazione.sh
```

Lo script apre la pagina di Apple, spiega dove premere e chiede l'Apple ID e la
password per app. Fa tutto lui: apre il browser, verifica con Apple e salva.

Da quel momento `./scripts/package.sh --notarize` funziona da solo. La
credenziale resta nel portachiavi di questo Mac: non entra mai nel repository.

## Provare che funzioni davvero

Sull'altro Mac, prima di aprire:

```bash
spctl -a -vvv -t install /Applications/MirrorScopio.app
# atteso: accepted — source=Notarized Developer ID
```

Al primo avvio l'app chiede **solo il microfono** e, se manca, scarica il
modello di riconoscimento italiano: tutto dall'onboarding, senza Impostazioni
di Sistema.

## Quello che l'altro Mac deve avere

- **macOS 26** o successivo (l'app usa `SpeechAnalyzer`).
- Un microfono, anche quello incorporato.
- Circa 1 GB liberi per il modello vocale italiano, scaricato una volta sola.
- Apple Intelligence è **facoltativo**: senza, il voto resta identico — cambia
  solo il commento clinico.

## Quello che non si può automatizzare

Le voci di sistema (Federica Premium, Alice Enhanced…) **non sono installabili
da un'app**: macOS non espone nessuna API per farlo. L'app mostra e fa ascoltare
quelle presenti; per scaricarne altre c'è un collegamento diretto alla pagina
giusta delle Impostazioni. Le voci di serie bastano per usare MirrorScopio.
