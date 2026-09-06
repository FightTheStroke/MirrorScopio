#if os(iOS)
import Foundation
import Testing
@testable import MirrorScopioMobile

@Suite("Preferenze comuni dello studio")
@MainActor
struct StudioPreferencesTests {
  @Test("Colori, caratteri e voce restano dopo il rilancio")
  func conservazione() throws {
    let nome = "MirrorScopio.Preferenze.Prova.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: nome))
    defer { defaults.removePersistentDomain(forName: nome) }
    let preferenze = StudioMobilePreferences(defaults: defaults)
    var scelte = preferenze.scelte
    scelte.theme = .sabbia
    scelte.typeface = .openDyslexic
    scelte.textScale = 2
    scelte.voiceIdentifier = "voce-italiana-di-prova"
    scelte.voiceRate = 0.35
    preferenze.salva(scelte)
    #expect(preferenze.errore == nil)
    let rilette = StudioMobilePreferences(defaults: defaults)
    #expect(rilette.scelte.theme == .sabbia)
    #expect(rilette.scelte.typeface == .openDyslexic)
    #expect(rilette.scelte.textScale == 2)
    #expect(rilette.scelte.voiceIdentifier == scelte.voiceIdentifier)
    #expect(rilette.scelte.voiceRate == 0.35)
    let dati = try #require(defaults.data(forKey: "MirrorScopio.mobile.preferenzeUI"))
    let campi = try #require(JSONSerialization.jsonObject(with: dati) as? [String: Any])
    #expect(Set(campi.keys) == Set([
      "theme", "colorVision", "typeface", "textScale", "reducedMotion", "calmMode",
      "bersagliGrandi", "righeDistanziate", "voiceIdentifier", "voiceRate"
    ]))
  }

  @Test("Una preferenza invalida non sostituisce quelle salvate")
  func modificaRifiutata() throws {
    let nome = "MirrorScopio.Preferenze.Prova.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: nome))
    defer { defaults.removePersistentDomain(forName: nome) }
    let preferenze = StudioMobilePreferences(defaults: defaults)
    preferenze.salva(preferenze.scelte)
    let prima = defaults.data(forKey: "MirrorScopio.mobile.preferenzeUI")
    var scelte = preferenze.scelte
    scelte.voiceRate = .nan
    preferenze.salva(scelte)
    #expect(preferenze.errore != nil)
    #expect(preferenze.scelte.voiceRate == 0.42)
    #expect(defaults.data(forKey: "MirrorScopio.mobile.preferenzeUI") == prima)
  }
}
#endif
