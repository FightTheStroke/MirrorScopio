import Testing
@testable import MirrorScopio

/// Il battito del display: quando gira e quando deve stare zitto.
///
/// Perché queste prove esistono. MirrorScopio ha bruciato per settimane il
/// 58,9% di un processore stando ferma: l'orologio che scandisce i fotogrammi
/// restava acceso anche a schermo immobile, e sessanta volte al secondo
/// chiamava una funzione che non faceva niente e ridisegnava una schermata
/// identica a se stessa. Su un portatile si sente: ventola che parte, Mac che
/// scotta, batteria che finisce a metà pomeriggio. Cioè una sessione
/// interrotta, che è esattamente quello che l'app dovrebbe evitare.
///
/// Misurare la CPU dentro una prova non si può: il sistema non lascia leggere
/// il consumo di un altro processo da dentro le prove, e un numero che dipende
/// da cos'altro sta girando sul Mac sarebbe rumoroso al punto da venire spento
/// dopo tre giorni. Quindi si prova la **causa** invece dell'effetto, e la
/// causa è netta: il battito deve essere acceso se e solo se serve.
@Suite("Battito del display")
@MainActor
struct Battito {

  /// Le fasi in cui `tick` esce subito senza toccare niente.
  ///
  /// Sono copiate dallo `switch` in cima a `SessionEngine.tick`. Se qualcuno
  /// ne aggiunge una là e la dimentica qui, la prova qui sotto se ne accorge.
  static let fasiFerme: [Phase] = [
    .idle, .preparing, .instructions, .typing, .pausa, .scoring,
    .finished, .failed("una ragione qualsiasi"),
  ]

  /// Le fasi in cui il tempo conta e lo schermo cambia davvero.
  static let fasiVive: [Phase] = [
    .countdown(3), .fixation, .preMask, .stimulus, .postMask,
    .listening, .flushing, .interTrial, .feedback(true), .feedback(false),
  ]

  @Test("A schermo fermo l'orologio e' spento")
  func fermoVuolDireSpento() {
    for fase in Self.fasiFerme {
      #expect(SessionEngine.serveIlBattito(in: fase) == false, """
        In fase \(fase) l'app ridisegna lo schermo sessanta volte al secondo \
        per non fare niente: `tick` in questa fase esce subito. Su un portatile \
        si sente come ventola accesa e batteria che scende.
        """)
    }
  }

  @Test("Quando il tempo conta l'orologio gira")
  func vivoVuolDireAcceso() {
    for fase in Self.fasiVive {
      #expect(SessionEngine.serveIlBattito(in: fase) == true, """
        In fase \(fase) l'orologio e' spento, ma e' proprio la fase in cui i \
        millisecondi contano: senza battito la parola resterebbe sullo schermo \
        piu' a lungo del dovuto, e la misura della soglia sarebbe sbagliata.
        """)
    }
  }

  @Test("Nessuna fase e' rimasta fuori dai due elenchi")
  func nessunaFaseDimenticata() {
    // I casi di `Phase` sono 17, e qui gli elementi sono 18 perche'
    // «feedback» si prova due volte: risposta giusta e risposta sbagliata.
    // Non esiste un elenco automatico (`Phase` porta con se'
    // dei valori, quindi non e' `CaseIterable`). Il conto e' l'unico modo di
    // accorgersi che qualcuno ne ha aggiunta una senza decidere se il battito
    // le serve: una fase nuova che nessuno ha classificato e' esattamente il
    // modo in cui il difetto era entrato la prima volta.
    let classificate = Self.fasiFerme.count + Self.fasiVive.count
    #expect(classificate == 18, """
      Le fasi classificate sono \(classificate), ne erano attese 18. Se hai \
      aggiunto o tolto una \
      fase a `Phase`, mettila in `fasiFerme` o in `fasiVive` a seconda \
      che `tick` faccia qualcosa o no, e aggiorna questo numero.
      """)
  }
}
