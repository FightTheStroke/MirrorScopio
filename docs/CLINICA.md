# Basi cliniche

Questo documento spiega **perché** l'app fa quello che fa. Serve al logopedista che vuole
sapere che cosa sta misurando, e a chi mette le mani nel codice e deve capire quali costanti
può toccare e quali no.

> MirrorScopio è uno strumento di esercizio e di osservazione. **Non è un test
> standardizzato e non è un dispositivo diagnostico.** I numeri che produce hanno senso come
> confronto di una persona con sé stessa nel tempo, non come confronto con una norma.
>
> **Nessun valore prodotto da quest'app è normato su popolazione italiana**, né su nessun'altra:
> non esistono tabelle per età o per classe con cui confrontarlo. Prima di usare qualunque
> numero di qui in una relazione, si legga [Fonti e limiti](#fonti-e-limiti): dice quali scelte
> poggiano sulla letteratura e quali sono decisioni nostre mai validate.

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

Il **riscaldamento** — le prime tre parole restano visibili il triplo del tempo, fino a un
massimo di un secondo e mezzo — non entra nella scala, non conta nella percentuale finale e
non pesa sul livello suggerito. Le prime risposte di una sessione sono contaminate
dall'adattamento al compito, non dalla capacità di lettura.

La **soglia** che l'app riporta è la media delle ultime inversioni della scala — il modo
standard di stimarla in psicofisica. Serve però che le inversioni siano **almeno quattro**:
sotto quella soglia l'app non dichiara alcun numero, invece di dichiararne uno che non
significa niente.

## Il livello: sfidante ma raggiungibile

La soglia pura è il posto sbagliato dove allenarsi. Chi si esercita al 50% di riuscita
sbaglia una parola su due e si scoraggia; chi si esercita al 95% si annoia e non impara
nulla.

MirrorScopio punta a una **fascia di comfort fra il 60% e il 90% di parole prese**:

- sotto il 60% → l'app propone di scendere di livello;
- sopra il 90% → l'app propone di salire.

**Propone, non decide.** Il cambio di livello è sempre un'azione volontaria di chi legge o
dell'adulto.

Anche la calibrazione iniziale segue lo stesso principio: propone otto parole a esposizione
calante (la prima è di riscaldamento, sette contano), poi imposta il punto di partenza a
**soglia × 1,25**.

Con sole sette parole, però, la scala arriva raramente a quattro inversioni. Quando non ci
arriva l'app ripiega sull'**esposizione più breve presa giusta**: è una stima molto più
grossolana, che una singola risposta fortunata sposta parecchio. Va letta per quello che è —
un punto di partenza ragionevole per non annoiare né frustrare — e non come una misura.

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

Quei due numeri sono un **esempio per far capire l'idea, non due soglie**. Non esistono qui
valori di riferimento: la latenza si legge confrontando una persona con sé stessa, seduta
dopo seduta.

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

La scala è quattro gradini: **parola → parola difficile → frase breve → frase intera**.

La direzione generale — si comincia dalla parola isolata e si arriva al testo — è la stessa
che si trova nei software clinici italiani per la disortografia. **I quattro gradini di
MirrorScopio, però, sono una scelta nostra**: non riproducono la progressione di nessun
prodotto esistente e non sono stati confrontati con nessuno. Fino alla versione 0.6.0 qui
c'era scritto che erano «la stessa impostazione dei software clinici italiani del settore,
RIDInet compreso»: quella frase citava un prodotto di terzi come se ne confermasse le
scelte, senza uno straccio di riferimento. È stata tolta.

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

## Fonti e limiti

Questa sezione esiste perché fino alla versione 0.6.0 questo documento non citava **una sola
fonte**. Un logopedista che legge deve poter separare tre cose: quello che viene dalla
letteratura, quello che abbiamo deciso noi, e quello che l'app non sa fare.

### La frase che viene prima di tutte le altre

**Nessun valore prodotto da MirrorScopio è normato su popolazione italiana.** Non esistono
tabelle per età, per classe o per zona con cui confrontare una soglia, una percentuale o una
latenza misurate qui. Un numero di quest'app non dice mai «sopra la media» o «sotto la
media», perché non c'è nessuna media. Dice soltanto come è andata **oggi rispetto alle
volte precedenti, sullo stesso Mac, con lo stesso schermo e la stessa persona**.

E ancora prima: MirrorScopio non è mai stato oggetto di uno studio di validazione. Non è
stato confrontato con nessuna batteria testata, non ha misure di attendibilità, non ha
sensibilità né specificità note.

### Che cosa poggia sulla letteratura

| Quello che l'app fa | Su che cosa poggia | Che cosa dice davvero la fonte |
|---|---|---|
| La **maschera** subito dopo la parola | Sperling 1960; Coltheart 1980 | Senza maschera l'immagine resta disponibile nella memoria visiva per qualche centinaio di millisecondi. È il motivo per cui togliere la maschera fa misurare la memoria invece della percezione. |
| **1 su 1** converge verso ~50%, **2 giù / 1 su** verso ~71% | Levitt 1971 | Sono i punti di convergenza teorici delle due regole. |
| **Soglia = media delle ultime inversioni** | Levitt 1971 | È la stima standard, una volta scartate le oscillazioni iniziali più ampie. |
| Via lessicale e via fonologica come strade distinte | Coltheart, Rastle, Perry, Langdon & Ziegler 2001 | Il modello a doppia via su cui si regge l'idea di allenare il riconoscimento globale. |
| In italiano la dislessia si vede soprattutto sulla **velocità** | Zoccolotti et al. 1999; Linea guida ISS 2022 | In un'ortografia trasparente come l'italiano l'accuratezza recupera prima; il segno che resta è la lentezza. È il motivo per cui questo strumento misura tempi, non errori ortografici. |
| Le **non-parole** misurano la via fonologica pura | Sartori, Job & Tressoldi 2007 (DDE-2) | Le liste di non-parole sono uno strumento consolidato nella valutazione italiana proprio perché escludono l'aiuto del lessico. |
| Allenarsi né alla soglia né nella comodità | Wilson, Shenhav, Straccia & Cohen 2019 | Su compiti percettivi con difficoltà adattiva l'apprendimento è più rapido attorno a **circa l'85% di risposte giuste**. La nostra fascia 60–90% contiene quel valore, ma è più larga: vedi sotto. |

**Un limite di questa colonna, dichiarato.** Levitt descrive scale a passo fisso in condizioni
ideali; con passi fissi e poche prove il punto di convergenza reale si sposta rispetto al
50% e al 71% teorici (García-Pérez 1998). Le percentuali scritte nell'interfaccia («~50%»,
«~71%») vanno lette come **etichette della regola**, non come garanzie sul risultato di una
sessione da quindici parole.

### Che cosa abbiamo deciso noi, e non è validato

Ognuno di questi numeri è nel codice, alla riga indicata. Nessuno viene da uno studio:
sono scelte ragionevoli, provate a mano, mai confrontate con un'alternativa.

| Parametro | Valore | Dove sta | Perché quel valore |
|---|---|---|---|
| Parole di riscaldamento | 3 | `Core/Model.swift:202` | Abbastanza per prendere la mano senza allungare la seduta. Scelto a occhio. |
| Quanto durano di più | ×3, tetto 1500 ms | `Core/SessionEngine.swift:119` | Devono vedersi «benissimo». Il tetto evita attese noiose ai livelli lenti. |
| Parole della calibrazione | 8 (7 contano) | `Core/SessionEngine.swift:183-184` | Compromesso fra precisione e pazienza di un ragazzo al primo avvio. **Troppo poche per una soglia stabile**, come detto sopra. |
| Partenza della calibrazione | 800 ms, passo 90 ms, minimo 60 ms | `Core/SessionEngine.swift:185-188` | Scendere in fretta per finire in fretta. |
| Margine sul punto di partenza | soglia × 1,25 | `Core/SessionEngine.swift:677` | Allenarsi al limite scoraggia: si parte appena sopra. Il 25% è una scelta, non una misura. |
| Fascia di comfort | 60%–90% | `Data/Gamification.swift:164-165` | Più larga dell'85% della letteratura, di proposito: proporre un cambio di livello a ogni piccola oscillazione sarebbe fastidioso. Sotto le 5 parole contate l'app non propone niente (`:168`). |
| Passo della scala | 15 ms di serie; 40 / 30 / 20 / 15 ms per i quattro livelli | `Core/Model.swift:206`, `:87-93` | Passi più grandi dove le esposizioni sono lunghe. Proporzione scelta a mano. |
| Esposizione iniziale dei livelli | 900 / 600 / 300 / 150 ms | `Core/Model.swift:87-93` | Corrisponde alla difficoltà delle liste (sillabe piane → quadrisillabe). Nessuna taratura su dati. |
| Croce di fissazione | 900 ms | `Core/Model.swift:210` | Il tempo di posare lo sguardo. |
| Maschera | 200 ms | `Core/Model.swift:212` | Abbastanza da coprire la persistenza, abbastanza poco da non pesare. |
| Pausa fra una parola e l'altra | 1200 ms | `Core/Model.swift:213` | Respiro fra due prove. |
| Attesa massima della risposta | 4000 ms | `Core/Model.swift:216` | Oltre, si registra «nessuna risposta». Si allunga con i profili che lo chiedono. |
| Silenzio che chiude la risposta | 450 ms | `Core/Model.swift:225` | Misurato a mano sul comportamento reale: 700 ms facevano ripetere la parola già detta giusta. È l'unico di questa tabella corretto guardando l'app in funzione. |
| I quattro gradini di «Scrivi» | parola → parola difficile → frase breve → frase intera | `Core/Model.swift` (liste in `Stimuli.swift`) | Nostra progettazione. Vedi sopra. |

### Che cosa l'app non sa, e non può sapere

- **La soglia non è confrontabile fra due Mac.** Dipende da dimensione dello schermo,
  frequenza di aggiornamento, carattere scelto, dimensione del testo e distanza dagli occhi.
  L'app misura fedelmente la durata sul **suo** schermo e non conosce nessuna delle altre
  variabili. Due sedute vanno confrontate solo se fatte nella stessa condizione.
- **Il riconoscimento vocale introduce errori suoi.** Una parola letta bene può essere
  trascritta male, e conta come sbagliata. Sulle non-parole succede spesso, ed è dichiarato
  dentro l'app.
- **Nessuna prova che il tachistoscopio, così com'è qui, migliori la lettura.** L'esercizio
  tachistoscopico è di uso comune nella pratica riabilitativa italiana, ma le prove
  sperimentali di efficacia sono limitate e non riguardano questo software. Dove le prove
  sono più solide è sulla **lettura ripetuta** (Therrien 2004), che è un'altra cosa.
- **L'etichetta del tipo di errore la scrive un modello linguistico**, e può sbagliarla. Non
  può però mai cambiare il verdetto giusto/sbagliato, che è deterministico e viene deciso
  prima (vedi [`ARCHITETTURA.md`](ARCHITETTURA.md)).

### Bibliografia

- Coltheart, M. (1980). *Iconic memory and visible persistence.* Perception & Psychophysics,
  27(3), 183–228.
- Coltheart, M., Rastle, K., Perry, C., Langdon, R., & Ziegler, J. (2001). *DRC: A dual route
  cascaded model of visual word recognition and reading aloud.* Psychological Review, 108(1),
  204–256.
- García-Pérez, M. A. (1998). *Forced-choice staircases with fixed step sizes: asymptotic and
  small-sample properties.* Vision Research, 38(12), 1861–1881.
- Istituto Superiore di Sanità (2022). *Linea guida per la gestione dei Disturbi Specifici
  dell'Apprendimento (DSA).* Sistema Nazionale Linee Guida.
- Levitt, H. (1971). *Transformed up-down methods in psychoacoustics.* The Journal of the
  Acoustical Society of America, 49(2B), 467–477.
- Sartori, G., Job, R., & Tressoldi, P. E. (2007). *DDE-2. Batteria per la valutazione della
  dislessia e della disortografia evolutiva-2.* Firenze: Giunti O.S.
- Sperling, G. (1960). *The information available in brief visual presentations.*
  Psychological Monographs: General and Applied, 74(11), 1–29.
- Therrien, W. J. (2004). *Fluency and comprehension gains as a result of repeated reading: a
  meta-analysis.* Remedial and Special Education, 25(4), 252–261.
- Wilson, R. C., Shenhav, A., Straccia, M., & Cohen, J. D. (2019). *The Eighty Five Percent
  Rule for optimal learning.* Nature Communications, 10, 4646.
- Zoccolotti, P., De Luca, M., Di Pace, E., Judica, A., Orlandi, M., & Spinelli, D. (1999).
  *Markers of developmental surface dyslexia in a language (Italian) with high
  grapheme–phoneme correspondence.* Applied Psycholinguistics, 20(2), 191–216.

I riferimenti sono dati per esteso — autore, anno, rivista, volume, pagine — perché chi legge
possa cercarli e controllarli. **Se una fonte non regge il controllo, è un difetto di questo
documento**: si segnala e si corregge, non si difende.

## Sicurezza

- **Epilessia fotosensibile.** La sequenza comporta cambi rapidi di luminanza. Non usare in
  presenza di epilessia fotosensibile senza parere medico.
- **Affaticamento.** Sessioni brevi e ripetute battono sessioni lunghe. Le pause automatiche
  esistono per questo.
