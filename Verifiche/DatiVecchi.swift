import Foundation
import Testing
@testable import MirrorScopio

/// Che cosa succede a chi aveva già usato l'app, il giorno in cui arriva una
/// versione nuova.
///
/// Questa è la prova che mancava il 28 agosto 2026, e la sua assenza è costata
/// cara: tutte le altre prove salvavano e rileggevano con la stessa versione
/// del codice, quindi il file di prova conteneva sempre, per costruzione, tutti
/// i campi che il codice si aspettava. Il caso vero — un file scritto **ieri**,
/// letto da un'app di **oggi** — non era coperto da nessuna parte, e infatti il
/// giorno in cui a `SessionConfig` è stato aggiunto un `Bool` l'elenco delle
/// persone è diventato illeggibile su un Mac che ci lavorava da mesi.
///
/// Le prove qui sotto usano JSON scritti a mano apposta: non generati dal
/// codice di oggi, ma copiati dal formato di prima. È l'unico modo di
/// verificare davvero l'aggiornamento; un JSON generato dall'encoder corrente
/// non potrà mai mancare di un campo corrente.
@Suite("I dati vecchi si leggono ancora")
struct DatiVecchiSiLeggono {

  private func leggi<T: Decodable>(_ tipo: T.Type, _ json: String) throws -> T {
    try JSONDecoder().decode(tipo, from: Data(json.utf8))
  }

  @Test("Una configurazione senza il consenso al lampeggio veloce si legge")
  func configurazioneSenzaCampoNuovo() throws {
    // Esattamente il caso reale: il file di Roberto, che non aveva ancora
    // `lampeggioVeloceConsentito` perché quel campo non esisteva.
    let c = try leggi(SessionConfig.self, #"{"mode":"lettura","level":"base","trials":20,"exposureMs":600}"#)
    #expect(c.trials == 20)
    #expect(c.exposureMs == 600)
    #expect(c.lampeggioVeloceConsentito == false)  // il predefinito prudente
    #expect(c.responseTimeoutMs == 4000)           // anche gli altri assenti
  }

  @Test("Un'impostazione di accessibilità ridotta all'osso si legge")
  func accessibilitaSenzaCampiNuovi() throws {
    let a = try leggi(A11ySettings.self, #"{"textScale":1.5}"#)
    #expect(a.textScale == 1.5)
    #expect(a.volumeSuoni == 0.7)
    #expect(a.soundsEnabled == true)
    #expect(a.profile == .nessuno)
  }

  @Test("Una persona salvata da una versione precedente si legge intera")
  func personaVecchia() throws {
    let l = try leggi(Learner.self, #"{"name":"Mario","xp":120,"a11y":{},"config":{}}"#)
    #expect(l.name == "Mario")
    #expect(l.xp == 120)
    #expect(l.sessionsCompleted == 0)
    #expect(l.unlockedAchievements.isEmpty)
    #expect(l.config.lampeggioVeloceConsentito == false)
  }

  @Test("Una prova salvata prima che esistesse l'interruzione si legge")
  func provaVecchia() throws {
    let i = try leggi(ItemRecord.self,
                      #"{"stimulus":"cane","response":"cane","correct":true,"exposureMs":600,"errorKind":"nessuno"}"#)
    #expect(i.stimulus == "cane")
    #expect(i.correct)
    #expect(i.interrotto == false)   // non interrotta: non lo era
    #expect(i.frameSaltato == false)
    #expect(i.refreshHz == nil)      // non lo sapevamo: non lo inventiamo
    #expect(i.latencyMs == nil)
  }

  @Test("Una sessione vecchia porta dentro le sue prove vecchie")
  func sessioneVecchia() throws {
    let s = try leggi(SessionRecord.self, #"""
    {"setLabel":"bisillabe","correct":8,"total":10,
     "items":[{"stimulus":"mela","response":"mela","correct":true,"exposureMs":600,"errorKind":"nessuno"}]}
    """#)
    #expect(s.total == 10)
    #expect(s.items.count == 1)
    #expect(s.items[0].interrotto == false)
    #expect(s.mode == .lettura)
  }

  @Test("Un campo che c'è ma è rovinato resta un errore")
  func campoRovinatoNonSiPerdona() {
    // La tolleranza vale per i campi *assenti*. Un campo presente e scritto
    // male non è un formato vecchio: è un file rovinato. Leggerlo lo stesso
    // vorrebbe dire mettere un numero inventato dentro un referto clinico.
    #expect(throws: (any Error).self) {
      try leggi(SessionConfig.self, #"{"trials":"venti"}"#)
    }
    #expect(throws: (any Error).self) {
      try leggi(ItemRecord.self, #"{"response":"cane","correct":true,"exposureMs":600,"errorKind":"nessuno"}"#)
    }
  }

  @Test("Quello che l'app scrive oggi si rilegge identico")
  func andataERitorno() throws {
    var l = Learner()
    l.name = "Prova"
    l.config.lampeggioVeloceConsentito = true
    l.a11y.textScale = 1.8
    let dati = try JSONEncoder().encode(l)
    let riletta = try JSONDecoder().decode(Learner.self, from: dati)
    #expect(riletta.id == l.id)
    #expect(riletta.name == "Prova")
    #expect(riletta.config.lampeggioVeloceConsentito)
    #expect(riletta.a11y.textScale == 1.8)
  }
}
