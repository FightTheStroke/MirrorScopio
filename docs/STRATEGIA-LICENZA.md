# Strategia di licenza e proprietà intellettuale

Questo documento risponde a una domanda sola: **che cosa impedisce a qualcun altro di
prendere MirrorScopio, venderlo e non dirci niente?**

La risposta onesta, oggi, è: quasi niente sul codice, e molto su tutto il resto. Qui sotto
c'è il perché, che cosa stiamo facendo perché «il resto» diventi consistente, e a quali
condizioni questa scelta si rivede.

È l'equivalente per MirrorScopio della strategia già adottata per
[MirrorBuddy](https://github.com/fightthestroke/mirrorbuddy), e segue la stessa dottrina: la
stessa fondazione non racconta due storie diverse a chi la finanzia.

---

## 1. La licenza di oggi

- **Licenza:** Apache License 2.0 ([`LICENSE`](../LICENSE), [`NOTICE`](../NOTICE)).
- **Caratteri tipografici:** SIL Open Font License 1.1, licenza distinta e indipendente
  ([`Resources/Fonts/LICENSES.md`](../Resources/Fonts/LICENSES.md)).
- **Fase:** dimostrare che il prodotto funziona. Non monetizzazione.

Perché Apache e non un'altra:

- **Protegge dai brevetti.** L'articolo 3 concede i brevetti a chi usa il software e li
  revoca automaticamente a chi ci fa causa per brevetto. Su uno strumento che confina con
  il medicale non è un dettaglio: è la differenza fra un deterrente e nessun deterrente.
  Una licenza MIT o BSD questo non ce l'ha.
- **Le istituzioni si fidano.** Ospedali, ASL, scuole e bandi pubblici sanno leggere
  «Apache 2.0» senza chiedere niente al proprio ufficio legale. Una licenza inventata da
  noi, o una non riconosciuta come software libero, apre una pratica invece di chiuderla.
- **Esclude il marchio in modo esplicito.** L'articolo 6 dice che la licenza non dà nessun
  diritto sul nome. Vedi la sezione 5.

### Che cosa la licenza consente, e va detto chiaramente

Apache 2.0 **permette l'uso commerciale**. Chiunque può prendere questo codice,
modificarlo, chiamarlo in un altro modo, venderlo, e non deve né pagarci né avvisarci. Gli
unici obblighi: tenere il testo della licenza, dichiarare i file che ha modificato,
riportare il contenuto di `NOTICE`. Non è un'omissione né un incidente: è una scelta, per i
motivi della sezione 3.

---

## 2. Dove sta il valore — e non è questo repository

Chi copia il repository si porta via il codice. Non si porta via nessuna di queste cose,
che sono quelle che rendono MirrorScopio uno strumento invece di una demo:

| | Che cos'è | Dove sta oggi |
|---|---|---|
| **Dati normativi su popolazione italiana** | Sapere che cosa vuol dire davvero un'esposizione di 200 ms per un bambino di otto anni in seconda elementare | **Non esistono ancora**. È il primo limite dichiarato in [`CLINICA.md`](CLINICA.md) |
| **Soglie tarate su bambini veri** | I quindici parametri della scala adattiva scelti a partire da misure, non a ragionamento | Non esistono. Oggi sono scelte nostre, e ogni numero lo dice accanto alla riga di codice |
| **Il protocollo clinico e chi lo firma** | Come si somministra, ogni quanto, che cosa si conclude, e la firma di chi se ne prende la responsabilità | Non esiste. MirrorScopio non è validato |
| **La rete dei logopedisti** | Chi lo usa davvero, ne riporta i difetti e ne guida l'evoluzione | Da costruire |
| **I dataset di prova etichettati** | Registrazioni con l'errore già classificato, per misurare quanto sbaglia il riconoscitore | Da costruire |
| **Il marchio e la fiducia delle famiglie** | «MirrorScopio», il logo, e vent'anni di Fight The Stroke dietro | «Fight The Stroke» **è un marchio registrato** (EUIPO 016206179). «MirrorScopio» **no**: vale solo per l'uso che se ne fa. Vedi la sezione 5 |

**La riga scomoda:** delle sei, quattro non esistono ancora e una è da costruire. Oggi il
vantaggio competitivo è quasi tutto nel repository, ed è stato reso perfettamente leggibile
di proposito — la sezione «Fonti e limiti» di `CLINICA.md` mette ogni costante accanto alla
riga in cui vive.

È una scelta, non una distrazione: in questa fase la trasparenza vale più della
difendibilità. Uno strumento che tocca bambini con difficoltà di lettura e che non dice da
dove vengono i suoi numeri non merita di essere adottato da nessuno. Ma questa scelta ha
una scadenza, ed è la sezione 4.

---

## 3. Perché non una licenza che vieta il commercio, oggi

Le alternative esistono e sono state considerate. Nessuna conviene adesso:

| Alternativa | Che cosa risolve | Perché non ora |
|---|---|---|
| **Commons Clause** sopra Apache | Vieta di vendere il software | Cristallizza una decisione commerciale prima di sapere se il prodotto funziona. E smette di essere software libero: attrito con bandi, università e fondazioni |
| **AGPL-3.0** + licenza commerciale | Chi lo rivende deve pubblicare tutto il proprio codice: per un concorrente è insostenibile, e allora viene a trattare | Resta software libero, quindi è l'opzione seria — ma richiede la liberatoria dei contributori e un canale commerciale che oggi non c'è. Va tenuta pronta, non attivata |
| **PolyForm Noncommercial** + licenza commerciale | Vieta l'uso commerciale in una riga | Perdiamo l'etichetta «open source», e con essa una parte del mondo clinico e pubblico |

Il ragionamento in una frase: **in questa fase una licenza restrittiva riduce le
possibilità senza aumentare il valore.** Nessuno vuole rivendere uno strumento che dichiara
di non essere validato.

### La cosa che va saputa comunque

Cambiare licenza **non vale all'indietro**. Ogni versione già pubblicata resta Apache per
sempre, e chiunque può ripartire da lì. Il vantaggio di una licenza nuova è solo il ritmo
con cui il codice cresce da quel giorno in poi. Quindi: rivederla non è un pulsante da
premere con calma quando serve. È una decisione che vale meno ogni settimana che passa.

---

## 4. Quando si rivede

La licenza resta Apache 2.0 finché non succedono **tutte e tre** queste cose:

1. È uscita la versione 1.0.
2. Esistono misure stabili su bambini veri — cioè almeno una delle righe «non esistono
   ancora» della tabella della sezione 2 è diventata vera.
3. È partita una forma di monetizzazione: licenze a enti, versione professionale,
   assistenza.

Quando succedono, si sceglie **una sola** fra:

1. **Doppia licenza: AGPL-3.0 per tutti, licenza commerciale per chi vuole tenersi il
   proprio codice chiuso.** Resta software libero, il mondo pubblico continua ad adottarlo,
   e chi ci vuole fare business viene a trattare.
2. **Apache 2.0 + Commons Clause**, se la priorità diventa la scuola e non l'ospedale.

La scelta si fa su un modello di ricavi verificato, non su un'ipotesi.

---

## 5. Le due cose che vanno fatte adesso, e costano zero

Non riguardano quale licenza, ma la possibilità stessa di sceglierne una domani.

### Il marchio non è nella licenza

L'articolo 6 di Apache 2.0 non concede nessun diritto sul nome. **«MirrorScopio», il logo e
«Fight The Stroke» non sono coperti dalla licenza del codice.** Chi parte da questo codice
può farlo, ma deve chiamare la sua cosa in un altro modo e non può far credere che sia
nostra o che noi la approviamo. È scritto in [`NOTICE`](../NOTICE) e nel
[`README`](../README.md).

Questa è, oggi, la protezione più concreta che abbiamo. **Verificato il 28 agosto 2026, e
non è una protezione sola: sono due, e una delle due non c'è.**

| Nome | Come sta davvero |
|---|---|
| **«Fight The Stroke»** | **Marchio registrato**, EUIPO n. 016206179, depositato il 27 dicembre 2016, tuttora in vigore. Copre fra le altre le classi 41 (formazione), 42 (servizi informatici e di ricerca) e 44 (assistenza medica). |
| **«MirrorScopio»** | **Non registrato.** Nessun deposito trovato su EUIPO, USPTO né TMview. |

Che cosa cambia in pratica:

- **Nessuno può spacciare la propria copia per roba della fondazione.** Quella è la difesa
  forte, ed è già in piedi: il nome della fondazione è registrato proprio nelle classi in
  cui un software del genere si vende.
- **Il nome «MirrorScopio», da solo, è difendibile ma male.** In Italia un nome usato senza
  registrarlo è un *marchio di fatto*: esiste, ma per farlo valere bisogna dimostrare in
  giudizio da quando lo si usa e quanto è conosciuto. Costa tempo, avvocati e incertezza.
  Chi lo registrasse per primo — un concorrente, chiunque — partirebbe da una posizione
  migliore della nostra.
- **C'è anche un buco nelle classi già registrate**, e va detto: fra quelle di «Fight The
  Stroke» **non c'è la 9**, che è quella dei programmi *scaricabili*. La 42 copre i servizi
  informatici, non un'app che si scarica e si installa. Per un'app per Mac distribuita
  così, è la classe che servirebbe.

**Cosa fare, in ordine di convenienza:**

1. **Depositare «MirrorScopio» come marchio UE in classe 9 e 42.** Un deposito EUIPO in una
   classe costa 850 € di tassa, più 50 € per la seconda: circa **900 € di tasse**, più
   l'eventuale parcella. Vale la pena solo se il nome resta questo per anni.
2. **Estendere «Fight The Stroke» alla classe 9.** Non si aggiunge una classe a un marchio
   già registrato: si deposita di nuovo. Stesso ordine di costo.
3. **Non fare niente e tenere le prove d'uso.** Costa zero. Conservare in modo ordinato le
   date di prima pubblicazione (i commit di questo repository sono già una prova datata e
   pubblica) è ciò che serve per far valere il marchio di fatto se un giorno servisse.

Nessuna delle tre è urgente finché il progetto non esce dalla cerchia di chi lo prova. La
terza è quella che stiamo già facendo senza accorgercene.

> Le date e i numeri qui sopra vengono da una banca dati di terze parti che rispecchia
> EUIPO, non dall'archivio EUIPO interrogato direttamente (serve una credenziale). Prima di
> spendere soldi su uno dei tre punti, si ricontrolla su `euipo.europa.eu`.

### La liberatoria di chi contribuisce

Oggi il codice ha un autore solo, quindi la fondazione può cambiare licenza quando vuole,
senza chiedere niente a nessuno.

**Al primo contributo esterno accettato senza una liberatoria firmata, questa libertà
finisce.** Il codice di quella persona resta suo, sotto Apache, e per vendere una licenza
commerciale su un software che lo contiene servirebbe il suo consenso — o riscrivere quel
pezzo. Con dieci contributori diventa impossibile.

La liberatoria non toglie niente a chi contribuisce: resta l'autore, il suo nome resta
nello storico, e il suo lavoro resta libero per tutti. Concede solo alla fondazione il
diritto di distribuire quel codice anche con una licenza diversa.

Va messa **prima** del primo contributo, non dopo. Vedi
[`CONTRIBUTING.md`](../CONTRIBUTING.md).

---

## 6. Che cosa diciamo a finanziatori e partner

> MirrorScopio è Apache 2.0 perché siamo nella fase in cui bisogna dimostrare che
> funziona, e uno strumento che tocca bambini con difficoltà di lettura deve poter essere
> ispezionato da chiunque. Il vantaggio competitivo che stiamo costruendo non è il
> repository: sono i dati normativi italiani, le soglie tarate su bambini veri, il
> protocollo validato e la rete di logopedisti che lo usa. **Oggi nessuna di queste cose
> esiste ancora** — ed è esattamente il lavoro per cui serve il finanziamento. La licenza
> commerciale arriverà quando ci sarà qualcosa da monetizzare, e le condizioni per
> rivederla sono scritte.

La differenza con MirrorBuddy va detta e non nascosta: là il sistema governato attorno al
codice esiste già, qui è l'obiettivo. Presentarlo come un fatto sarebbe la stessa cosa che
scrivere in un documento clinico un valore normativo che non abbiamo.

---

## 7. Registro delle decisioni

| Quando | Decisione | Perché |
|---|---|---|
| 27 agosto 2026 | Apache License 2.0 | Protezione sui brevetti, fiducia delle istituzioni, allineamento con MirrorBuddy |
| 28 agosto 2026 | Confermata Apache, scritte le condizioni per rivederla | Valutate Commons Clause, AGPL e PolyForm: nessuna conviene finché il prodotto non è validato |

Questo documento va riletto a ogni versione con il primo numero che cambia, e ogni volta
che una riga «non esiste ancora» della sezione 2 diventa vera.
