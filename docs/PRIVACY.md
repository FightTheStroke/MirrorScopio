# Privacy

Questo documento vale come **informativa**. È scritto in due versioni — una per gli adulti e
una per i ragazzi — perché a un ragazzino di dieci anni si deve dire che cosa succede ai suoi
dati con parole che capisce, e non farlo sarebbe scorretto due volte.

Chi cerca il dettaglio tecnico su dove stanno i file e con quali permessi: [`SECURITY.md`](../SECURITY.md).

---

## Per i genitori e per chi accompagna

**MirrorScopio non manda niente a nessuno.** Non c'è un account da creare, non c'è un
servizio a cui collegarsi, non c'è nessuna statistica che ci arriva. Noi che abbiamo scritto
l'app non sappiamo se la state usando, chi la usa, e come sta andando.

Tutto quello che l'app registra resta in una cartella del vostro Mac, in file che potete
aprire con un editor di testo qualsiasi:

```
~/Library/Application Support/MirrorScopio/
```

Questo ha una conseguenza importante e va detta chiaramente: **il titolare di quei dati siete
voi**, non la Fight The Stroke Foundation. Noi non li trattiamo, non li vediamo, non
possiamo cancellarli e non possiamo recuperarli. Se cancellate quella cartella, i dati sono
andati e non esiste nessuna copia da nessuna parte.

### La voce

La voce del ragazzo **non viene registrata e non viene salvata**. Il microfono passa il suono
al riconoscitore vocale che sta dentro macOS, e di tutto quel passaggio resta solo il testo
di quello che è stato capito. Nessun file audio viene scritto sul disco, in nessun momento.

### Che cosa l'app tiene, perché, e per quanto

| Dato | A che serve | Dove sta | Quanto resta |
|---|---|---|---|
| Nome o soprannome del ragazzo | Distinguere due persone che usano lo stesso Mac. Può essere un soprannome: l'app non controlla niente e non serve che sia vero | `learners.json` | Finché non lo cancellate |
| Preferenze di accessibilità (carattere, tema, tempi, suoni) | Ritrovare l'app come l'avete lasciata | `learners.json` | Finché non lo cancellate |
| Velocità di partenza misurata dalla prova iniziale, e quando è stata fatta | Non ricominciare ogni volta da zero | `learners.json` | Finché non lo cancellate |
| Punti, serie di giorni, obiettivi raggiunti | La parte di gioco, che si può spegnere | `learners.json` | Finché non lo cancellate |
| Per ogni parola: quella mostrata, quella capita, giusta o «ancora», millesimi di esposizione, ritardo della voce, tipo di errore | Il referto e il confronto fra una seduta e l'altra | `history.json` | Finché non lo cancellate |
| Data e ora di ogni sessione | Mettere in fila i progressi | `history.json` | Finché non lo cancellate |
| Se il controllo versione è acceso, e quando è stato fatto l'ultimo | Non chiedere a GitHub più di una volta al giorno | Preferenze di sistema dell'app | Finché non disinstallate |
| **Copia di sicurezza di un file rovinato**, quando capita | Se un salvataggio è rimasto a metà, l'app **non ci scrive sopra**: ne mette da parte una copia con la data, così quel che c'era non va perso. Contiene le stesse cose del file da cui viene | Nella stessa cartella, con nome `learners.<data>.illeggibile.json` o `history.<data>.illeggibile.json` | **Finché non la cancellate voi**: l'app non la tocca più. Il nome vi dice qual è; si butta come qualunque file |
| **La voce** | — | **Da nessuna parte** | **Non viene mai salvata** |

Nessuna di queste righe esce dal Mac. Nessuna viene usata per profilare, misurare o
confrontare con altre persone.

### Le uniche quattro volte che passa dalla rete

Nessuna delle quattro porta via dati del ragazzo.

1. **Il modello vocale italiano**, la prima volta. Lo scarica macOS da Apple, non
   MirrorScopio, ed è circa un giga. Succede una volta sola. Non contiene niente di vostro:
   è un pezzo del sistema operativo che arriva dopo.
2. **Il controllo della versione**, se lo accendete. Una volta al giorno l'app chiede a
   GitHub qual è l'ultima versione pubblicata. Manda una domanda e basta, non manda mai
   dati. **È spento finché non lo accendete voi**, nell'avvio guidato o nelle Impostazioni.
   Come per qualunque visita a un sito, GitHub vede l'indirizzo IP da cui arriva la domanda:
   se questo vi dà fastidio, lasciatelo spento e l'app funziona identica.
3. **Lo scaricamento dell'aggiornamento**, solo se lo chiedete voi premendo «Aggiorna e
   riavvia». A quel punto l'app prende da GitHub il pacchetto della versione nuova — sono
   decine di megabyte — e prima di sostituirsi controlla che la firma sia la nostra e che
   il timbro di Apple sia valido. Anche qui non parte nessun dato vostro: solo la richiesta
   del file, e ancora una volta GitHub vede l'indirizzo IP. Se non premete quel bottone,
   non viene scaricato niente.

   Il codice dei punti 2 e 3 sta tutto in un file solo (`Sources/Core/Updates.swift`), e un
   controllo automatico impedisce che una connessione di rete compaia altrove nell'app.
4. **La firma di Apple**, che riguarda noi e non voi: chi *pubblica* una versione manda
   l'app ad Apple perché la controlli. Non c'entra con chi la usa.

### I vostri diritti, e come si esercitano davvero

Il Regolamento europeo dà una serie di diritti su dati che qualcuno tiene per conto vostro.
Qui la situazione è più semplice: i dati li tenete voi, quindi ogni diritto si esercita
aprendo l'app o la cartella, senza chiedere niente a nessuno e senza aspettare risposte.

| Diritto | Come si esercita, in pratica |
|---|---|
| **Vedere** i dati | I due file JSON si aprono con TextEdit e si leggono. Sono fatti apposta per essere leggibili a occhio. |
| **Portarli via** | I due file si copiano. Dentro l'app: «I tuoi progressi» → esporta il PDF con **tutto lo storico**, o il CSV dell'ultima sessione. |
| **Correggerli** | Il nome si cambia nelle Impostazioni. Il resto si modifica nei file. |
| **Cancellarli** | Impostazioni › I dati › «Cancella tutti i dati di…». Oppure si butta la cartella: non resta nessuna copia. Se in passato è comparso l'avviso di un file rovinato, controllate che non sia rimasto un file con `illeggibile` nel nome: quello va buttato a mano. |
| **Opporsi** / limitare | Non c'è niente a cui opporsi: nessun trattamento nostro è in corso. Il controllo versione si spegne dalle Impostazioni. |
| **Reclamare** | Verso di noi, per il funzionamento dell'app: **info@fightthestroke.org**. Per problemi di sicurezza: **security@fightthestroke.org**. |

### Sull'età

MirrorScopio è pensato per ragazzi, quindi quasi sempre per minori. Poiché **non facciamo
alcun trattamento** — non riceviamo dati, non li conserviamo, non li usiamo — non c'è un
consenso da raccogliere e non c'è un'età minima da verificare.

Resta però una cosa che riguarda l'adulto: **decidere di registrare i risultati di un
ragazzo è una scelta che va fatta consapevolmente**, e il ragazzo dovrebbe saperlo. La
sezione qui sotto serve a dirglielo con parole sue.

---

## Per te che leggi le parole

Ciao. Questa pagina è per te, non per i grandi.

**Quello che dici a voce non viene registrato.** Il Mac ti ascolta per capire quale parola
hai detto, e poi di quel suono non resta niente. Non c'è nessun file con la tua voce dentro,
da nessuna parte.

**Quello che il Mac si segna** è questo: quale parola ti ha mostrato, quale ha capito che
hai detto, se era giusta o se non è venuta *ancora*, e quanto tempo ci hai messo. Serve a
farti vedere come stai andando, e a niente altro.

**Quelle cose restano dentro questo computer.** Non le vede nessuno su internet. Non le
vediamo nemmeno noi che abbiamo fatto l'app: davvero, non abbiamo modo di guardarle.

**Puoi cancellare tutto quando vuoi.** Nelle Impostazioni c'è un pulsante che butta via ogni
cosa: i punti, le stelle, le parole di tutte le volte. Non si può tornare indietro, e quindi
è meglio chiederlo a un adulto — ma la scelta puoi farla tu.

**Se qualcosa qui non ti è chiaro, non è colpa tua: l'abbiamo scritto male noi.** Diccelo a
info@fightthestroke.org e lo riscriviamo meglio.

---

## Valutazione d'impatto (DPIA)

Il Regolamento chiede una valutazione d'impatto quando un trattamento può presentare un
rischio elevato — e dati sulla salute di minori sono il caso tipico. Qui sotto la nostra, con
un avvertimento: **non è un documento firmato da un consulente**, è un'analisi fatta da chi
scrive il software. Vale come punto di partenza onesto, non come adempimento formale di un
titolare.

### Punto di partenza: chi tratta che cosa

MirrorScopio è un programma che gira sul computer di qualcun altro e non comunica con noi.
La Fight The Stroke Foundation **non è titolare né responsabile** del trattamento dei dati
generati dall'uso: non li riceve, non li conserva, non li può leggere. Titolare è la famiglia
o il professionista che decide di registrarli sul proprio Mac.

Questo sposta il rischio, non lo cancella. Il rischio resta tutto **locale**, e chi ha
scritto l'app ha comunque la responsabilità di non renderlo peggiore del necessario.

### I rischi, uno per uno

| # | Rischio | Quanto è probabile | Quanto farebbe male | Che cosa c'è oggi | Che cosa manca |
|---|---|---|---|---|---|
| 1 | I dati escono dal Mac verso un servizio | Molto bassa | Gravissimo | Un solo file tocca la rete (`Updates.swift`), e un controllo automatico boccia una rete aggiunta altrove. Il controllo guarda **riga per riga**, non file per file, e copre anche le vie di servizio (scaricare un indirizzo senza `URLSession`, o lanciare `curl`); guarda pure il codice delle prove automatiche | Resta una lista di divieti: una tecnica di rete nuova, non ancora nell'elenco, passerebbe. Va rovesciata in lista di permessi |
| 2 | Un'altra persona che usa lo stesso Mac legge i dati | Bassa | Alto | Cartella con permessi `700`, file `600`: un altro utente non li apre | Niente da fare in più, è la garanzia del sistema |
| 3 | **Un altro programma avviato dallo stesso utente legge i dati** | Media | Alto | Nessuna difesa: l'app non gira in una scatola chiusa, per poter cambiare il microfono di sistema. È dichiarato in `SECURITY.md` | Accendere la sandbox, o cifrare i due file con una chiave nel portachiavi. È un lavoro aperto |
| 4 | I dati vengono persi per un guasto | Media | Medio | I file sono JSON leggibili e copiabili a mano. Se un file risulta illeggibile l'app **non ci scrive sopra**: ne mette da parte una copia con la data, lo dice a schermo e aspetta che decida una persona | Resta che la copia è nella stessa cartella e quindi sullo stesso disco: contro la perdita del disco non protegge. Una copia fuori dal Mac la deve fare la famiglia |
| 5 | Un referto esportato finisce dove non deve | Media | Alto | L'esportazione è sempre un'azione volontaria di un adulto, con la finestra «dove lo salvo» | Sta a chi esporta. Va detto nel documento per i logopedisti, ed è detto |
| 6 | Un dato clinico sbagliato porta a una decisione sbagliata | Media | Alto | Il verdetto giusto/sbagliato è deterministico, il modello linguistico non può ribaltarlo. I limiti sono dichiarati in `CLINICA.md` | I limiti vanno letti davvero: nessun numero di quest'app è normato |
| 7 | Un ragazzo si sente giudicato dai propri dati | Media | Medio | Punteggi nascondibili, mai la parola «sbagliato», mai una croce | Il *Dettaglio per l'adulto* non è ancora protetto: un ragazzo può aprirlo |
| 8 | L'indirizzo IP arriva a GitHub col controllo versione, e di nuovo se si scarica un aggiornamento | Media, solo se acceso; lo scaricamento solo se lo si chiede | Basso | Spento finché non lo si accende, e detto prima; lo scaricamento parte solo premendo «Aggiorna e riavvia» | Niente |

### Il giudizio

Il rischio principale **non è la fuga in rete** — quella è tenuta stretta e verificata — ma
il fatto che i file stiano in chiaro dentro la cartella dell'utente (rischio 3): un altro
programma avviato dalla stessa persona li può leggere, e oggi non c'è niente che glielo
impedisca. È un lavoro aperto e dichiarato, non una sorpresa. La perdita silenziosa
(rischio 4) era il secondo, ed è stata chiusa: adesso un file rovinato viene messo da parte
e detto, invece di sparire.

Questa valutazione va rifatta ogni volta che: si aggiunge una connessione di rete, si cambia
dove stanno i dati, si aggiunge un dato nuovo alla tabella qui sopra, o si porta l'app su
un'altra piattaforma.

---

## Che cosa in questo documento è ancora un obiettivo

Per coerenza con il resto della documentazione, le cose non fatte stanno scritte:

- La **policy pubblicata su un sito** non esiste ancora: oggi questa pagina è il documento, e
  vive nel repository. Serve prima della pubblicazione sull'App Store
  ([`roadmap.md`](../roadmap.md), STORE-03).
- La **DPIA non è stata rivista da un consulente esterno**.
- L'**esportazione** porta via tutto lo storico in PDF, ma in CSV solo l'ultima sessione. Chi
  vuole tutto in formato tabellare deve per ora passare dai file JSON.
