import Foundation

struct StudioHelpTopic: Identifiable {
  let id: String
  let title: String
  let how: String
  let why: String

  static let all: [StudioHelpTopic] = [
    .init(
      id: "iniziare", title: "1. Il primo testo",
      how: """
      Aggiungi una lezione: scrivi il titolo e la materia, poi incolla il testo oppure \
      importa un documento. Controlla il testo estratto prima di salvarlo. Parti da un \
      paragrafo che devi già studiare: non serve aggiungere esercizi ai compiti. \
      I limiti sono 20 MB per file, 30 pagine per PDF (al massimo 10 pagine \
      da riconoscere come immagine) e 120.000 caratteri per lezione. \
      L'archivio contiene al massimo 100 lezioni e occupa al massimo 20 MB.
      """,
      why: """
      Studiare un contenuto utile permette di capire se lo strumento ti aiuta davvero. \
      Il riconoscimento dei caratteri può confondere parole, numeri e colonne: vedere \
      un testo sullo schermo non significa che sia stato estratto correttamente.
      """),
    .init(
      id: "ascoltare", title: "2. Leggere oppure ascoltare",
      how: """
      Apri una lezione. Il testo viene diviso in segmenti: puoi leggere quello visibile \
      oppure ascoltarlo. Usa pausa, riprendi, ripeti e i comandi per cambiare segmento. \
      La lettura non passa da sola al segmento successivo. Le preferenze della voce \
      permettono di scegliere fra le voci italiane installate e cambiare la velocità.
      """,
      why: """
      L'audio può ridurre il lavoro necessario per decifrare il testo, ma non è migliore \
      per tutti e non garantisce la comprensione. Il testo resta disponibile e puoi \
      scegliere di non ascoltare. I segmenti non sono una dose terapeutica: fermati \
      quando serve, anche prima della fine.
      """),
    .init(
      id: "mappa", title: "3. Costruire e consultare la mappa",
      how: """
      Annota le idee principali, le parole che servono e il collegamento fra le idee. \
      Per un racconto possono servire persone ed eventi; per una spiegazione, \
      definizioni, esempi, cause o confronti. Prima ascolta, poi metti in pausa \
      e completa la mappa. Puoi consultarla anche durante il ripasso.
      """,
      why: """
      Una mappa lascia disponibili informazioni che altrimenti dovresti tenere tutte \
      a mente. Usarla non è barare. Aumentare l'autonomia può significare usare meglio \
      uno strumento, non eliminarlo: l'app non lo ritira dopo un certo numero di settimane.
      """),
    .init(
      id: "formulario", title: "4. Tenere a portata di mano una procedura",
      how: """
      Nel formulario scrivi i passi, le formule o un esempio svolto legato alla lezione. \
      Controllali sul libro o con un adulto. Consulta un passaggio per volta e torna \
      indietro quando vuoi. L'app non inventa formule né verifica automaticamente \
      la correttezza matematica di ciò che scrivi.
      """,
      why: """
      Tenere visibile una procedura permette di concentrarsi su come applicarla. \
      Non tutte le attività richiedono calcolo mentale. A scuola, quali strumenti \
      usare dipende dagli obiettivi concordati con gli insegnanti.
      """),
    .init(
      id: "ripasso", title: "5. Ripassare con una risposta di riferimento",
      how: """
      Un adulto prepara le domande e le risposte di riferimento, collegandole al testo. \
      Durante il ripasso prova a rispondere, per iscritto o a voce senza registrare. \
      Poi consulta la risposta e indica tu com'è andata: ricordato, con aiuto oppure \
      ancora. Se la risposta di riferimento non è corretta, falla correggere prima \
      di usarla di nuovo.
      """,
      why: """
      Recuperare informazioni a distanza può aiutare a imparare quei contenuti. \
      Non dimostra un aumento del QI. La tua valutazione è un'autovalutazione, \
      non un voto automatico: l'app non usa un modello linguistico per decidere \
      se hai capito. Consultare un aiuto è consentito e si distingue dal ricordare \
      senza aiuti.
      """),
    .init(
      id: "pause", title: "6. Pause, durata e giorni saltati",
      how: """
      Puoi interrompere quando vuoi e riprendere dal punto salvato. Non devi \
      completare una durata obbligatoria. Se sei stanco, fermati: i ripassi \
      disponibili non sono un debito da recuperare tutti oggi.
      """,
      why: """
      Non ci sono classifiche, vite o serie di giorni che si azzerano. Un giorno \
      senza studio non cancella quello che hai fatto. Questo percorso non usa \
      parole lampeggianti; non è però una garanzia medica sull'assenza di crisi. \
      Le indicazioni dei professionisti restano valide.
      """),
    .init(
      id: "adulto", title: "7. Che cosa osserva l'adulto",
      how: """
      Nell'area adulto si consultano le osservazioni disponibili e si preparano \
      i contenuti del ripasso. Il tempo attivo, la modalità di studio, gli aiuti \
      e la fatica indicata descrivono una sessione. Per confrontare due sessioni \
      considera anche il materiale e l'obiettivo: una pagina facile non equivale \
      a una pagina nuova e complessa. Gli intervalli del ripasso sono \
      promemoria di studio, non prescrizioni: un giro propone al massimo 20 carte.
      """,
      why: """
      Meno minuti non significano automaticamente più comprensione. Un risultato \
      utile può essere imparare lo stesso contenuto con meno fatica o meno richiami. \
      L'app non misura il QI, non produce diagnosi e non determina percorsi \
      scolastici o modifiche della terapia.
      """),
    .init(
      id: "archivi", title: "8. Dati, copie e due dispositivi",
      how: """
      Mac e iPhone hanno archivi locali separati. Per spostare lo studio, esporta \
      una copia dall'area adulto e importala sull'altro dispositivo. Prima di \
      confermare una sostituzione conserva una copia di entrambi: importare \
      non significa unire automaticamente due archivi. Il file esportato \
      è leggibile: scegli con attenzione dove salvarlo e a chi consegnarlo.
      """,
      why: """
      Non servono account, servizi remoti o sincronizzazione automatica. \
      L'app non invia i testi a un'intelligenza artificiale esterna. Se scegli \
      una cartella cloud o condividi un'esportazione, quella copia lascia \
      il dispositivo per tua scelta e non è più sotto il controllo dell'app.
      """),
    .init(
      id: "problemi", title: "9. Se qualcosa non funziona",
      how: """
      Se non senti la voce, controlla il volume e le voci italiane installate \
      nelle impostazioni del dispositivo: puoi comunque leggere il testo. \
      Se un documento non si importa, prova un estratto più breve o incolla \
      il testo, poi controllalo. Se compare un errore dell'archivio, non \
      cancellare i dati: conserva una copia e usa le opzioni di recupero \
      disponibili. Un salvataggio fallito non va ignorato.
      """,
      why: """
      Un problema tecnico non è una tua risposta mancata. L'app deve mostrarlo \
      e non deve ricorrere di nascosto alla rete, inventare un risultato \
      o sovrascrivere un archivio che non sa leggere.
      """),
    .init(
      id: "precedente", title: "10. Il percorso precedente e i limiti",
      how: """
      Sul Mac l'area adulto permette di aprire il percorso precedente di esercizi. \
      I suoi profili e risultati restano separati dallo studio. Su iPhone trovi \
      il nuovo percorso di studio, non i giochi e il tachistoscopio del Mac.
      """,
      why: """
      Leggere parole presentate rapidamente e studiare un capitolo sono attività \
      diverse. I loro risultati non si sommano e non si convertono in un unico \
      indice cognitivo. La scelta di un esercizio riabilitativo resta da \
      concordare con i professionisti.
      """)
  ]
}
