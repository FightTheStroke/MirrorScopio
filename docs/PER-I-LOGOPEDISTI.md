# MirrorScopio, per chi fa questo mestiere

Pagina per logopedisti, neuropsicologi ed educatori. È scritta al netto della cortesia: dice
anche quello che questo strumento **non** può fare, perché è l'unica informazione davvero
utile prima di metterlo in mano a un paziente.

Il perché di ogni scelta di parametro sta in [`CLINICA.md`](CLINICA.md). Qui c'è come si usa.

---

## Che cosa avete davanti

Un tachistoscopio a soglia adattiva con scoring automatico via riconoscimento vocale
on-device, per italiano, che gira interamente in locale su un Mac.

| | |
|---|---|
| **Paradigma** | croce di fissazione (900 ms) → parola → maschera post-stimolo (200 ms) → ascolto |
| **Scala** | fissa, 1-su-1 (~50%), 2-giù-1-su (~71%), passo configurabile |
| **Soglia** | media delle ultime inversioni; nessun valore dichiarato sotto le 4 inversioni |
| **Misure** | esposizione richiesta e **effettiva**, esito, latenza vocale, tipo di errore |
| **Verdetto** | deterministico, mai affidato al modello linguistico |
| **Liste** | sillabe piane e complesse, bisillabe, trisillabe, quadrisillabe, non-parole, gruppi consonantici, digrammi, frasi brevi, frasi intere, numeri, più una lista vostra |
| **Seconda modalità** | «Scrivi»: la parola si sente e si scrive, per la disortografia |

## Quello che va detto prima di tutto

1. **Non è un test standardizzato.** Nessun valore è normato su popolazione italiana, per
   nessuna età e nessuna classe. Non esiste un punteggio da collocare rispetto a una media,
   perché la media non c'è.
2. **Non è validato.** MirrorScopio non è stato confrontato con nessuna batteria testata. Non
   ha misure di attendibilità, né sensibilità o specificità note.
3. **La soglia non è confrontabile fra due Mac.** Dipende da schermo, frequenza di
   aggiornamento, carattere, corpo del testo e distanza dagli occhi — e l'app conosce solo la
   prima. Due sedute si confrontano solo a condizione invariata.
4. **Il riconoscitore introduce errori suoi.** Una parola letta correttamente può essere
   trascritta male e contata come errore. Sulle **non-parole** succede spesso e nessun
   accorgimento lo risolve: non esistono nel lessico del riconoscitore. Su quelle liste usate
   la modalità «Scrivi», dove il confronto è testuale ed esatto.
5. **Non ci sono prove che questo esercizio, così com'è qui, migliori la lettura.**
   L'esercizio tachistoscopico è di uso comune, ma le prove sperimentali sono limitate e non
   riguardano questo software.

Il quadro completo, con le fonti e con l'elenco dei parametri che sono scelte nostre mai
validate, è in [`CLINICA.md` § Fonti e limiti](CLINICA.md#fonti-e-limiti). **Vale la pena
leggerlo prima di mettere un numero di quest'app dentro una relazione.**

## Come impostarlo per un paziente

### 1. La prova iniziale

Otto parole a esposizione calante (la prima è riscaldamento). Da lì l'app propone velocità di
partenza e livello.

**Attenzione:** sette prove arrivano raramente a quattro inversioni. Quando non ci arrivano
l'app ripiega sull'esposizione più breve presa giusta — stima grossolana, che una risposta
fortunata sposta parecchio. **Consideratela un punto di partenza, non una misura di
baseline.** Per una baseline seria: una sessione da 20 prove con scala 2-giù-1-su, e si legge
la soglia da lì.

### 2. I quattro livelli

| Livello | Lista | Esposizione iniziale | Passo | Prove |
|---|---|---|---|---|
| Inizio | sillabe piane | 900 ms | 40 ms | 12 |
| Base | bisillabe | 600 ms | 30 ms | 15 |
| Intermedio | trisillabe | 300 ms | 20 ms | 20 |
| Avanzato | quadrisillabe | 150 ms | 15 ms | 20 |

Ogni parametro è modificabile dal pannello avanzato, dietro «Per l'adulto». Il livello
«personalizzato» esiste apposta.

### 3. La fascia di lavoro

L'app propone di salire sopra il 90% di riuscita e di scendere sotto il 60%, e solo con
almeno 5 prove contate. **Propone, non decide**: il cambio è sempre un'azione volontaria.
La fascia è una nostra scelta, più larga dell'ottimo indicato in letteratura (~85%).

### 4. Il riscaldamento

Le prime tre parole restano visibili il triplo del tempo (tetto 1,5 s). **Non entrano nella
scala, non entrano nella percentuale, non pesano sul livello proposto**, e nell'esportazione
sono marcate `riscaldamento = si`.

## Che cosa portate via

| Formato | Contenuto | Da dove |
|---|---|---|
| **PDF storico** | tutte le sessioni del profilo | «I tuoi progressi» → esporta |
| **PDF di sessione** | intestazione + dettaglio prova per prova | fine sessione → Dettaglio per l'adulto |
| **CSV di sessione** | `parola;risposta;esito;esposizione_ms;latenza_ms;tipo_errore;riscaldamento`, con intestazione (nome, data, modalità, livello, lista, giuste/totali, accuratezza, soglia, latenza media) | fine sessione, o «I tuoi progressi» |
| **JSON grezzo** | tutto, per chi vuole rianalizzare | `~/Library/Application Support/MirrorScopio/` |

Due avvertenze sull'esportazione:

- Il CSV usa il **punto e virgola** come separatore. Excel italiano lo apre giusto; altrove
  va dichiarato.
- **Il file esce dalla protezione dell'app.** Dentro c'è il nome del ragazzo e ogni suo
  errore: dove lo salvate e a chi lo mandate è una vostra responsabilità, e nessuna
  impostazione dell'app può proteggerlo una volta uscito.

### Che cosa il PDF e il CSV non dicono ancora

L'app registra per ogni parola tre cose che nelle esportazioni **non compaiono**, e che
restano solo dentro i file dei dati (`~/Library/Application Support/MirrorScopio/`):

- **Se il turno è stato interrotto** — il Mac che si addormenta, la finestra che passa
  dietro a un'altra, il microfono staccato. L'app fa la cosa giusta nei conti: un turno
  interrotto non entra nell'accuratezza e non sposta la difficoltà. Ma **nel CSV quella
  riga c'è comunque, con esito «ancora» e senza niente che la distingua**. Se contate gli
  «ancora» a mano sul CSV, vi verrà un numero peggiore di quello vero: fidatevi
  dell'accuratezza in intestazione, che è calcolata bene.
- **La frequenza dello schermo** (`refreshHz`) e **il fotogramma saltato**
  (`frameSaltato`). Servono a interpretare i millesimi: su uno schermo a 60 Hz
  un'esposizione di 30 ms non può esistere.

Se vi servono, sono nel file `history.json`, che è leggibile a occhio. Portarli anche nelle
esportazioni è un lavoro aperto.

## Le tre colonne che si leggono per prime

- **Esposizione**: la colonna `esposizione_ms` riporta la durata **effettivamente misurata**
  sullo schermo, al fotogramma, non quella richiesta (`SessionEngine.swift:945`). Se la
  misura non è disponibile, ripiega sulla richiesta. È il motivo per cui questa app usa
  `CVDisplayLink` invece di un timer di sistema: a 120 Hz la differenza fra i due criteri
  vale 8 ms su un'esposizione che può valerne 33.
- **Latenza vocale**: millisecondi fra la comparsa della parola e l'inizio della voce,
  misurata sull'energia del segnale audio, non sulla trascrizione (che arriva molto dopo).
  Indicatore indipendente dall'accuratezza. **Non ci sono valori di riferimento**: si legge
  confrontando la persona con sé stessa.
- **Tipo di errore**: inversione, lettera simile, sostituzione, omissione, aggiunta, altra
  parola, nessuna risposta. È un'etichetta **descrittiva**, scritta da un modello linguistico
  locale, e può sbagliarla. Non può però mai cambiare il verdetto giusto/sbagliato, deciso
  prima e in modo deterministico.

## Le vostre liste

Il pannello avanzato accetta una lista di parole vostra. È il modo giusto di adattare lo
strumento a un caso: liste bilanciate per frequenza, per struttura sillabica o per il
bersaglio ortografico della settimana.

Nell'esportazione la lista usata compare nell'intestazione, quindi resta tracciabile a
distanza di mesi.

## Modalità «Scrivi»

La parola si **sente**, non si vede: i millesimi di esposizione lì non significano niente, e
infatti l'app non li mostra. Quattro gradini: parola → parola difficile (gn, gl, sc, doppie,
gruppi consonantici) → frase breve → frase intera.

Sulle frasi, ogni parola scritta diventa una pastiglia che si tocca per **risentire solo
quella**, più un pulsante che rilegge tutta la frase. E il Mac rilegge **quello che c'è
scritto davvero**, non quello che avrebbe dovuto esserci: il punto è sentire con le proprie
orecchie la differenza fra le due cose.

I quattro gradini sono una nostra progettazione, non la riproduzione di nessun protocollo
esistente.

## Privacy, in una riga che potete ripetere ai genitori

Niente esce dal Mac, la voce non viene mai registrata, e noi che abbiamo fatto l'app non
vediamo nulla. Il titolare di quei dati è chi li tiene sul proprio computer — quindi voi, se
li tenete nel vostro studio. Dettaglio completo e valutazione d'impatto in
[`PRIVACY.md`](PRIVACY.md).

## Se trovate un difetto clinico

È la segnalazione che ci interessa di più, più di qualunque bug di interfaccia: un parametro
tarato male o un verdetto sbagliato producono un dato falso, e un dato falso in una relazione
fa danno. **info@fightthestroke.org**, oppure una issue pubblica sul repository.
