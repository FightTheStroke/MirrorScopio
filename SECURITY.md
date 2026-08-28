# Sicurezza e privacy

## Segnalare una vulnerabilità

**Non aprire una issue pubblica.** Scrivi a **security@fightthestroke.org**
descrivendo il problema e come riprodurlo.

Riceverai un riscontro entro **5 giorni lavorativi**. Se la segnalazione è
valida, concordiamo insieme i tempi di pubblicazione della correzione e, se lo
desideri, il riconoscimento nel changelog.

Questo progetto è mantenuto da una fondazione senza scopo di lucro: non c'è un
programma di ricompense economiche.

## Che cosa consideriamo grave, qui

L'ordine non è quello abituale, perché gli utenti di questo software sono
**minori con disabilità**.

1. **Qualunque fuga di dati dal Mac.** La promessa del progetto è che nulla
   esca dal dispositivo. Un percorso di codice che invia audio, trascrizioni,
   nomi o risultati a un servizio esterno è la vulnerabilità più grave
   possibile in questo repository, anche se "innocua" sul piano tecnico.
2. **Esposizione dei dati di chi usa l'app** — nome, cronologia degli errori,
   referti — a un **altro utente** del Mac. (Un'altra applicazione avviata dal
   tuo stesso utente è un caso diverso: leggi «Perché l'app non è in sandbox».)
3. **Esecuzione di codice** attraverso file di dati, pacchetti o workflow.
4. **Compromissione della catena di rilascio**: firma, notarizzazione, segreti
   di GitHub Actions, pacchetto DMG.

## Dove stanno i dati

Tutto in `~/Library/Application Support/MirrorScopio/`:

- `learners.json` — profili: nome, preferenze di accessibilità, obiettivi
- `history.json` — cronologia delle sessioni: parole, esiti, tempi

Sono file JSON in chiaro. La cartella è creata con permessi `700` e i file con
`600`: **nessun altro utente del Mac può leggerli**. **Non sono cifrati.** È
una scelta consapevole: chi tiene a questi dati deve poterli leggere, copiare e
cancellare senza chiedere il permesso a nessuno, incluso a noi.

**Per cancellare i dati di una persona** — nome, progressi, obiettivi e ogni
sessione registrata — c'è un pulsante: Impostazioni › I dati › «Cancella tutti
i dati di…». Non serve aprire nessuna cartella di sistema. In alternativa si
butta l'intera cartella qui sopra.

## Perché l'app non è in sandbox

MirrorScopio **non gira nella sandbox** di macOS. Non è una dimenticanza.

La ragione: quando un ragazzo dice «non mi sente», nove volte su dieci il Mac
sta ascoltando dal microfono sbagliato. L'app risolve il problema cambiando
l'ingresso audio predefinito del sistema — cosa che una app in sandbox non può
fare. Abbiamo scelto che funzionasse.

**La conseguenza, detta chiaramente:** un'altra applicazione avviata dal tuo
stesso utente può leggere i file di MirrorScopio, esattamente come può leggere
qualsiasi altro documento nella tua cartella utente. Non è una falla specifica
di questa app: è come funziona un Mac. Se sul computer gira software di cui non
ti fidi, quel software vede anche questi dati.

L'app chiede **solo due permessi**, e li usa entrambi: il microfono, e la
scrittura dei file che scegli tu con la finestra «Salva». Se accendi i
promemoria giornalieri ne chiede un terzo — mostrare notifiche — **solo in quel
momento**, mai all'avvio, e serve a far comparire un avviso su questo stesso
Mac. Nessun permesso di rete: non è che non lo usiamo — non ce l'ha proprio.

I referti PDF e i file CSV finiscono dove li salvi tu e contengono il nome del
profilo: trattali come un documento clinico.

## Che cosa esce dal Mac, in tutta onestà

Nulla che riguardi chi usa l'app. Ma per non nascondere niente:

- **In entrata**, dalla schermata «Prepara il Mac», macOS scarica da Apple il modello
  di riconoscimento vocale italiano. È un download del sistema operativo, non
  contiene dati tuoi, e avviene una volta sola, con una barra di avanzamento e
  solo se lo chiedi tu. Dopo, l'app funziona senza internet. Se il modello
  manca, la sessione non parte e l'app te lo dice: non scarica mai un giga
  alle spalle di chi sta usando l'app.
- **Aggiornamenti**: l'app può chiedere a GitHub qual è l'ultima versione
  pubblicata, non più di una volta al giorno. È **spenta finché non la accendi**
  tu — nell'avvio guidato o in Impostazioni › Aggiornamenti — e si spegne quando
  vuoi. La richiesta non porta con sé niente: nessun identificativo, nessun
  dato di chi usa l'app, nessun contenuto delle sessioni. GitHub vede quello che
  vede qualunque sito: che un computer ha chiesto una pagina pubblica. Tutto il
  codice che tocca la rete sta in un file solo, `Sources/Core/Updates.swift`, e
  il controllo automatico in `.github/workflows/verifica.yml` fa fallire la
  build se qualcuno ne aggiunge altrove.
- **Installare l'aggiornamento**: da Impostazioni › I dati c'è un pulsante
  «Aggiorna e riavvia», e allora l'app scarica il pacchetto dalla pagina delle
  release e si sostituisce. Non parte mai da solo: lo preme un adulto, e non
  funziona mentre una sessione è in corso. Prima di toccare qualsiasi cosa il
  pacchetto deve superare **due** controlli — la firma dev'essere quella di
  Fight The Stroke (numero di squadra `93T3LG4NPG`, nome dell'app
  `org.fightthestroke.mirrorscopio`) **e** il timbro di Apple dev'essere valido.
  Il primo da solo non basterebbe al secondo, e viceversa: senza il vincolo sul
  nostro certificato basterebbe una qualunque app timbrata da Apple per
  prendere il nostro posto. Se un controllo non passa, non viene installato
  niente e l'app dice perché. Non viene mai chiesta la password di
  amministratore e non viene installato niente che giri con privilegi: se
  MirrorScopio sta dove questo utente non può scrivere, l'app lo dice e si
  ferma.
- **In fase di sviluppo**, chi compila e pubblica una versione manda l'app ad
  Apple per la firma di sicurezza (notarizzazione). Riguarda il programma, non
  i dati.

E una cosa che **non** esce, anche se potrebbe sembrare di sì: i **promemoria
giornalieri** sono notifiche locali di macOS. L'app chiede al sistema di
mostrare un avviso su questo Mac a un'ora scelta; nessun testo, nessun orario,
nessun dato viene inviato da nessuna parte. Restano avvisi che nascono e
muoiono su questo computer, e si spengono quando vuoi.

## Come nasce il pacchetto che scarichi

Chi fa un rilascio ha in mano il certificato della fondazione: quel certificato è
quello che dice a macOS «questa app è di chi dice di essere». Quindi la domanda che
conta non è se il pacchetto è firmato — lo è sempre — ma **quale codice ha ottenuto
quella firma**.

Tre cancelli, in ordine:

1. **L'etichetta di versione deve stare dentro il ramo principale.** Un'etichetta creata
   su un ramo qualunque, con dentro quello che si vuole, non viene impacchettata: il
   rilascio si ferma prima ancora di aprire il portachiavi. Solo codice già rivisto e
   fuso arriva a essere firmato.
2. **Gli script che girano vengono dal ramo principale di adesso**, non dall'etichetta.
   L'etichetta dice *che cosa* impacchettare; il come lo dice il ramo principale. Così
   un problema scoperto oggi non torna in circolo ri-pacchettizzando una versione di sei
   mesi fa.
3. **Una persona approva a mano.** I segreti stanno in un ambiente protetto e GitHub non
   li consegna prima. È scomodo apposta.

Fino al 28 agosto 2026 c'era solo il terzo, e guardava il nome dell'etichetta, non il
suo contenuto: bastava un'etichetta con un `build.sh` modificato dentro per far firmare
qualunque cosa alla fondazione.

**Quello che questi cancelli non coprono, detto:** il progetto Xcode e `project.yml`
vengono ancora dall'etichetta, e in un progetto Xcode si possono nascondere passi che
eseguono comandi. Il primo cancello lo rende difficile — quel contenuto è comunque
passato da una revisione — ma non è la stessa cosa di un controllo automatico.

## Versioni supportate

Riceve correzioni solo l'ultima versione pubblicata. Il progetto è giovane
(0.x): l'aggiornamento è il modo di restare sicuri.

## Avvertenza d'uso

MirrorScopio mostra parole con cambi rapidi di luminanza. **Non usarlo con
persone con epilessia fotosensibile senza parere medico.** Non è un dispositivo
medico e non produce diagnosi: è uno strumento di esercizio e di osservazione.
