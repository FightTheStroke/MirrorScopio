import Testing
@testable import MirrorScopio

@Suite("Studio e navigazione originale")
@MainActor
struct NavigazioneTests {
  @Test("I servizi mantengono la schermata di studio")
  func serviziNonAbbandonanoStudio() {
    let nav = Navigazione()
    nav.schermata = .studio
    for servizio: Schermata in [.impostazioni, .progressi, .obiettivi, .audio, .preparazione] {
      nav.apri(servizio)
      #expect(nav.schermata == .studio)
      #expect(nav.servizioStudio == servizio)
      nav.servizioStudio = nil
      #expect(nav.schermata == .studio)
    }
  }

  @Test("La navigazione precedente resta diretta")
  func serviziDallaCasa() {
    let nav = Navigazione()
    nav.apri(.impostazioni)
    #expect(nav.schermata == .impostazioni)
    #expect(nav.servizioStudio == nil)
  }

  @Test("Tornare a casa chiude anche il servizio aperto")
  func uscitaDalloStudio() {
    let nav = Navigazione()
    nav.schermata = .studio
    nav.apri(.impostazioni)
    nav.apri(.casa)
    #expect(nav.schermata == .casa)
    #expect(nav.servizioStudio == nil)
  }
}
