# Basi cliniche

Questo documento spiega **perché** l'app fa quello che fa. Serve al logopedista che vuole
sapere che cosa sta misurando, e a chi mette le mani nel codice e deve capire quali costanti
può toccare e quali no.

> MirrorScopio è uno strumento di esercizio e di osservazione. **Non è un test
> standardizzato e non è un dispositivo diagnostico.** I numeri che produce hanno senso come
> confronto di una persona con sé stessa nel tempo, non come confronto con una norma.

## Che cosa misura

Il tempo minimo di esposizione al quale una parola viene ancora riconosciuta. È una
**soglia psicofisica**: sotto, l'informazione visiva non basta più; sopra, avanza.

La presentazione rapida impedisce la decodifica lettera per lettera e obbliga al
riconoscimento globale della parola. È questo il bersaglio dell'esercizio: nella dislessia
evolutiva la via lessicale — "vedo la parola, la riconosco" — è tipicamente più debole della
via fonologica.

## La sequenza, e perché ogni pezzo c'è

```
croce di fissazione → parola → maschera → ascolto
```

- **Croce di fissazione.** Lo sguardo deve essere già nel punto giusto quando la parola
  compare, altrimenti si misura il tempo del movimento oculare invece della lettura.
- **Maschera.** Una sequenza di segni che copre la parola subito dopo. Senza maschera
  l'immagine persiste nella memoria visiva (*iconic memory*) per centinaia di millisecondi:
  si continua a "leggere" una parola non più sullo schermo, e si finisce per misurare la
  memoria invece della percezione. **Togliere la maschera invalida la misura di soglia** —
  resta un buon esercizio, non più una misura.
- **Ascolto.** Il riconoscitore vocale è già in ascolto quando la parola compare, così la
  latenza include il tempo di reazione e non quello di avvio del microfono.

## La scala adattiva

Ogni parola sposta il tempo di esposizione. Le regole disponibili:

| Regola | Comportamento | A che serve |
|---|---|---|
| **Fissa** | Il tempo non cambia | Esercizio a difficoltà costante |
| **1 su 1** | Sale a ogni errore, scende a ogni successo | Converge verso circa il 50% di riuscita |
| **2 su 1** | Scende dopo due successi di fila, sale a ogni errore | Converge verso circa il 71%: più gentile, ed è il valore di riferimento in psicofisica |

Il **passo** è la quantità di millisecondi per aggiustamento. Passi grandi convergono in
fretta ma oscillano; passi piccoli sono precisi ma servono più parole.

Il **riscaldamento** — le prime parole restano visibili il triplo del tempo — non entra
nella scala. Le prime risposte di una sessione sono contaminate dall'adattamento al compito,
non dalla capacità di lettura.

## Il livello: sfidante ma raggiungibile

La soglia pura è il posto sbagliato dove allenarsi. Chi si esercita al 50% di riuscita
sbaglia una parola su due e si scoraggia; chi si esercita al 95% si annoia e non impara
nulla.

MirrorScopio punta a una **fascia di comfort fra il 60% e il 90% di parole prese**:

- sotto il 60% → l'app propone di scendere di livello;
- sopra il 90% → l'app propone di salire.

**Propone, non decide.** Il cambio di livello è sempre un'azione volontaria di chi legge o
dell'adulto.

Anche la calibrazione iniziale segue lo stesso principio: misura la soglia con otto parole a
esposizione calante, poi imposta il punto di partenza a **soglia × 1,25**.

## Tipi di errore

Quando i Foundation Models sono disponibili, ogni errore riceve un'etichetta:

| Etichetta | Che cosa vuol dire | Esempio |
|---|---|---|
| Inversione | Lettere o sillabe in ordine scambiato | *libro* → *librio*, *il* → *li* |
| Lettera simile | Confusione fra forme somiglianti | b/d, p/q, a/e |
| Sostituzione | Una lettera cambiata | *sole* → *sale* |
| Omissione | Una lettera in meno | *sport* → *sport* senza la r |
| Aggiunta | Una lettera in più | *casa* → *casta* |
| Altra parola | Una parola diversa, magari vicina di significato o di suono | |
| Nessuna risposta | Silenzio entro il tempo | |

L'etichetta è **descrittiva**. La decisione giusto/sbagliato è già stata presa in modo
deterministico prima che il modello veda alcunché (vedi
[`ARCHITETTURA.md`](ARCHITETTURA.md)).

## Latenza vocale

Il tempo fra la comparsa della parola e l'inizio della voce. È un indicatore utile
indipendente dall'accuratezza: due persone possono prendere le stesse parole, una in 600 ms
e una in 1800 ms, e stanno facendo due cose diverse — la seconda probabilmente sta ancora
decodificando.

## Non-parole

Le liste di non-parole misurano la via fonologica pura, senza aiuto lessicale. Sono
clinicamente preziose e per il riconoscimento vocale sono il caso peggiore: non esistono nel
vocabolario, quindi il riconoscitore le storpia verso la parola vera più vicina.

L'app lo dichiara apertamente e suggerisce la **modalità Scrivi**, dove non c'è
riconoscimento vocale di mezzo e il confronto è esatto.

## La scala di Scrivi: complessità, non velocità

In lettura cresce la fretta; scrivendo cresce la complessità. In modalità Scrivi la parola
si **sente**, non si vede: i millesimi di esposizione non hanno alcun significato, e infatti
l'app non li mostra più lì — prometteva una precisione che in quella modalità non esiste.

La scala è quattro gradini, ed è la progressione usata nella riabilitazione della
disortografia (la stessa impostazione dei software clinici italiani del settore, RIDInet
compreso): **parola → frase → brano**.

| Gradino | Che cosa si detta | Che cosa mette alla prova |
|---|---|---|
| **Parole** | Bisillabe piane, ortografia trasparente | Conversione suono → lettera |
| **Parole difficili** | gn, gl, sc, doppie, gruppi consonantici | Le regole che l'italiano non scrive come si sente |
| **Frasi brevi** | Tre o quattro parole | Tenere in memoria una sequenza mentre si scrive |
| **Frasi intere** | Frasi di senso compiuto | Significato, ordine e ortografia insieme |

Scrivere una frase non è scrivere più parole di seguito: è reggere insieme tre carichi che
sulla parola singola non si sommano mai.

### Il controllo parola per parola

Sulle frasi, «ripeti tutto» non serve: chi sta imparando non sbaglia la frase, sbaglia *una*
parola dentro la frase, e per accorgersene deve poter sentire quella e basta. Ogni parola
scritta diventa una pastiglia che si tocca per risentire **solo quella**, più un pulsante
che rilegge tutta la frase.

Il Mac rilegge **quello che c'è scritto davvero**, non quello che avrebbe dovuto esserci:
il punto è sentire con le proprie orecchie la differenza fra le due cose, che è esattamente
il controllo che chi scrive bene fa in automatico e chi ha disortografia deve imparare a
fare a voce alta.

## Sicurezza

- **Epilessia fotosensibile.** La sequenza comporta cambi rapidi di luminanza. Non usare in
  presenza di epilessia fotosensibile senza parere medico.
- **Affaticamento.** Sessioni brevi e ripetute battono sessioni lunghe. Le pause automatiche
  esistono per questo.
