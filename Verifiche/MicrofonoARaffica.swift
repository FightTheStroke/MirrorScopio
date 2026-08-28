import Testing
import Foundation
@testable import MirrorScopio

/// Il microfono acceso e spento tante volte di fila, e da più parti insieme.
///
/// Serve perché nell'app succede davvero, e più spesso di quanto sembri:
/// premere «Esci» spegne, cambiare microfono a metà sessione spegne e
/// riaccende, la fine della sessione spegne di nuovo, e la sorveglianza che si
/// accorge di un microfono staccato può far partire tutto questo mentre è già
/// in corso. Sono tre strade che possono arrivare nello stesso istante.
///
/// Quando andava male non si vedeva subito: il motore audio restava acceso,
/// il microfono restava occupato, e il difetto compariva la volta dopo — a
/// volte il giorno dopo, su un altro Mac, senza modo di riprodurlo.
///
/// Qui non si può accendere il microfono vero: il modello vocale non è
/// installato su chi esegue le prove, e chiedere il permesso del microfono
/// dentro una prova aprirebbe una finestra di sistema che nessuno vede. Quello
/// che si prova è il resto, cioè la parte che sbagliava: che spegnere sia
/// ripetibile, che accendere e spegnere insieme non lascino niente appeso, e
/// che lo stato condiviso col thread audio regga la pressione.
@Suite("Il microfono acceso e spento a raffica")
struct MicrofonoARaffica {

  // MARK: - Spegnere

  @Test("Spegnere un microfono già spento non fa niente, cinquanta volte di fila")
  func spegnereRipetutamente() async {
    let ascoltatore = SpeechListener()
    for _ in 0..<50 { await ascoltatore.stop() }
    let fase = await ascoltatore.fase
    #expect(fase == .fermo, "Dopo cinquanta spegnimenti la fase dev'essere «fermo», non \(fase).")
  }

  @Test("Venti spegnimenti insieme non si incastrano fra loro")
  func spegnereDaPiuParti() async {
    let ascoltatore = SpeechListener()
    await withTaskGroup(of: Void.self) { gruppo in
      for _ in 0..<20 { gruppo.addTask { await ascoltatore.stop() } }
    }
    let fase = await ascoltatore.fase
    #expect(fase == .fermo)
  }

  // MARK: - Accendere e spegnere insieme

  /// L'accensione qui fallisce sempre, e va bene così: quello che si guarda
  /// non è che riesca, è che quando non riesce non lasci niente acceso e non
  /// resti in mezzo al guado. Prima la fase non esisteva e questa domanda non
  /// si poteva nemmeno porre.
  @Test("Dieci accensioni fallite di fila lasciano sempre il microfono fermo")
  func accensioniFallite() async {
    let ascoltatore = SpeechListener()
    for _ in 0..<10 {
      // Una lingua che non esiste: si ferma prima di toccare il microfono.
      try? await ascoltatore.start(locale: Locale(identifier: "xx_ZZ"), vocabulary: ["casa"])
      let fase = await ascoltatore.fase
      #expect(fase == .fermo, "Un'accensione non riuscita deve tornare a «fermo», non restare in \(fase).")
    }
  }

  @Test("Accensioni e spegnimenti mescolati non lasciano niente appeso")
  func raffica() async {
    let ascoltatore = SpeechListener()
    await withTaskGroup(of: Void.self) { gruppo in
      for i in 0..<20 {
        gruppo.addTask {
          if i.isMultiple(of: 2) {
            try? await ascoltatore.start(locale: Locale(identifier: "xx_ZZ"),
                                         vocabulary: ["casa", "mare"])
          } else {
            await ascoltatore.stop()
          }
        }
      }
    }
    // Un ultimo spegnimento chiude qualunque accensione fosse ancora in volo.
    await ascoltatore.stop()
    let fase = await ascoltatore.fase
    #expect(fase == .fermo, "Dopo la raffica il microfono dev'essere fermo, non \(fase).")
  }

  // MARK: - Lo stato condiviso col thread audio

  /// Le finestre di risposta si aprono e si chiudono dal thread principale
  /// mentre il thread del microfono scrive il livello del suono: sono i due
  /// che si pestavano i piedi. Adesso passano tutti e due da un lucchetto
  /// solo, e questa prova li fa correre insieme apposta.
  @Test("Aprire e chiudere finestre mentre qualcun altro legge non perde il conto")
  func finestreSottoPressione() async {
    let ascoltatore = SpeechListener()

    await withTaskGroup(of: Void.self) { gruppo in
      gruppo.addTask {
        for i in 1...300 {
          ascoltatore.beginWindow(trialID: i)
          ascoltatore.endWindow()
        }
      }
      gruppo.addTask {
        for _ in 0..<300 { _ = ascoltatore.read() }
      }
      gruppo.addTask {
        // Chiusure chieste per prove che non sono più quella aperta: ognuna
        // va contata fra le consegne fuori tempo, nessuna va servita.
        for _ in 0..<50 {
          let servita = await ascoltatore.flush(trialID: -1)
          #expect(servita == false, "Una prova che non esiste non può essere servita.")
        }
      }
    }

    let scartate = ascoltatore.read().consegneFuoriTempo
    #expect(scartate == 50, "Le cinquanta chiusure fuori tempo vanno contate tutte, non \(scartate).")
  }

  /// Il conto dei fotogrammi è quello che colloca nel tempo ogni parola: se si
  /// perde un pezzo per strada, il taglio della finestra di risposta si sposta
  /// e una parola giusta può finire giudicata «Ancora». Qui lo si fa avanzare
  /// da otto parti insieme e si controlla che il totale torni esatto.
  @Test("Il conto dei fotogrammi torna anche se avanza da otto parti insieme")
  func conteggioFotogrammi() async {
    let cassetta = CassettaVoce()
    cassetta.azzera(sampleRate: 16000)

    await withTaskGroup(of: Void.self) { gruppo in
      for _ in 0..<8 {
        gruppo.addTask {
          for _ in 0..<500 { _ = cassetta.avanza(fotogrammi: 10, frequenza: 16000) }
        }
      }
    }

    // 8 × 500 × 10 = 40 000 fotogrammi, cioè 2,5 secondi a 16 kHz.
    let punto = cassetta.punto()
    #expect(punto.value == 40_000,
            "Sono stati consegnati 40 000 fotogrammi, il conto ne dice \(punto.value).")
  }

  // MARK: - Il taglio del testo già detto

  /// Non è concorrenza, è la regola che impedisce di confrontare «cane tavolo
  /// mare» con `mare`. Sta qui perché nello spostare il codice era l'unica
  /// parte che poteva cambiare comportamento senza che nessuno se ne
  /// accorgesse: sbagliata, non dà errore — dà «Ancora» a chi ha letto giusto.
  @Test("Le parole delle prove di prima non rientrano in quella corrente")
  func tagliaLeParoleVecchie() {
    #expect(CassettaVoce.senzaLeParoleGiaDette("cane tavolo mare", gia: "cane tavolo") == "mare")
    #expect(CassettaVoce.senzaLeParoleGiaDette("mare", gia: "") == "mare")
    // Se non comincia con quello che era già stato detto, non è una
    // ripetizione: si tiene com'è, perché tagliare qui vorrebbe dire buttare
    // la risposta di adesso.
    #expect(CassettaVoce.senzaLeParoleGiaDette("mare", gia: "cane") == "mare")
    // Maiuscole e accenti non spostano il taglio: si lavora a parole intere.
    #expect(CassettaVoce.senzaLeParoleGiaDette("Cane però mare", gia: "cane pero") == "mare")
  }
}
