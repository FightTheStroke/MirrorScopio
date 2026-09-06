import SwiftUI

@main
struct MirrorScopioMobileApp: App {
  @StateObject private var preferenze = StudioMobilePreferences()

  init() {
    FontLoader.registerBundledFonts()
  }

  var body: some Scene {
    WindowGroup {
      StudioMobileRoot(preferenze: preferenze)
    }
  }
}

private struct StudioMobileRoot: View {
  @ObservedObject var preferenze: StudioMobilePreferences
  @StateObject private var accessibilita = AccessibilitaDelMac()
  @Environment(\.colorScheme) private var sistema
  @State private var mostraImpostazioni = false

  private var a11y: EffettiveImpostazioniAccessibilita {
    EffettiveImpostazioniAccessibilita(preferenze.scelte, mac: accessibilita.stato)
  }
  private var palette: Palette {
    Palette.resolve(theme: a11y.theme, vision: a11y.colorVision, system: sistema)
  }

  var body: some View {
    VStack(spacing: Metrica.spazioPiccolo) {
      if preferenze.errore != nil {
        VStack(alignment: .leading, spacing: Metrica.spazioStretto) {
          Text("Impostazioni da controllare")
            .font(a11y.font(.corpo, .semibold))
            .fixedSize(horizontal: false, vertical: true)
          SmallButton(title: "Controlla", symbol: "exclamationmark.triangle", a11y: a11y) {
            mostraImpostazioni = true
          }
          .accessibilityLabel("Controlla le preferenze dell'interfaccia")
        }
        .padding(Metrica.spazioMedio)
      }
      StudioRootView(onSettings: { mostraImpostazioni = true })
    }
    .sheet(isPresented: $mostraImpostazioni) {
      StudioMobileSettings(
        scelte: Binding(get: { preferenze.scelte }, set: { preferenze.salva($0) }),
        errore: preferenze.errore,
        onClose: { mostraImpostazioni = false })
        .environment(\.palette, palette)
        .environment(\.impostazioni, a11y)
        .presentationDetents([.large])
        .presentationBackground(palette.background)
    }
    .onChange(of: mostraImpostazioni) { _, aperte in
      if aperte {
        _ = StudioRuntime.shared.store.flushStaged()
        StudioRuntime.shared.audio.stop()
        StudioRuntime.shared.tracker.pause()
      }
    }
    .environment(\.palette, palette)
    .environment(\.impostazioni, a11y)
    .font(a11y.font(.corpo))
    .foregroundStyle(palette.foreground)
    .tint(palette.accent)
    .background(palette.background.ignoresSafeArea())
    .preferredColorScheme(a11y.theme == .auto ? nil : (palette.isDark ? .dark : .light))
    .transaction {
      if a11y.reducedMotion || a11y.calmMode {
        $0.animation = nil
        $0.disablesAnimations = true
      }
    }
  }
}

/// Solo preferenze visive locali: nessuna lezione, risposta o parametro di trattamento.
@MainActor
final class StudioMobilePreferences: ObservableObject {
  @Published private(set) var scelte = A11ySettings()
  @Published private(set) var errore: String?
  private let defaults: UserDefaults
  private static let chiave = "MirrorScopio.mobile.preferenzeUI"

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    #if DEBUG
    // La prova a testo doppio non modifica le preferenze salvate.
    let ambiente = ProcessInfo.processInfo.environment
    if ambiente["MIRRORSCOPIO_STUDIO_TEST_ID"] != nil,
       ambiente["MIRRORSCOPIO_STUDIO_TEST_SCALA"] == "2" {
      scelte.textScale = 2
      return
    }
    #endif
    guard let valore = defaults.object(forKey: Self.chiave) else { return }
    do {
      guard let dati = valore as? Data else { throw CocoaError(.coderReadCorrupt) }
      let lette = try JSONDecoder().decode(A11ySettings.self, from: dati)
      try Self.valida(lette)
      scelte = lette
    } catch {
      errore = "Non riesco a leggere le preferenze salvate: uso le impostazioni iniziali. "
        + "Le precedenti non vengono cancellate finché non scegli una nuova impostazione. "
        + error.localizedDescription
    }
  }

  func salva(_ nuove: A11ySettings) {
    do {
      try Self.valida(nuove)
      let dati = try JSONEncoder().encode(SoloInterfaccia(scelte: nuove))
      defaults.set(dati, forKey: Self.chiave)
      scelte = nuove
      errore = nil
    } catch {
      errore = "Questa modifica non è stata salvata. Le preferenze precedenti restano valide. "
        + error.localizedDescription
    }
  }

  private static func valida(_ scelte: A11ySettings) throws {
    guard scelte.textScale.isFinite, (0.8...2).contains(scelte.textScale),
          scelte.voiceRate.isFinite, (0.2...0.6).contains(scelte.voiceRate) else {
      throw DecodingError.dataCorrupted(.init(
        codingPath: [], debugDescription: "Controlla la dimensione del testo (0,8–2) e la velocità della voce (0,2–0,6)."))
    }
  }

  /// Il lettore tollerante di A11ySettings completa i campi assenti con i valori originali.
  private struct SoloInterfaccia: Encodable {
    let scelte: A11ySettings
    private enum CodingKeys: String, CodingKey {
      case theme, colorVision, typeface, textScale, reducedMotion, calmMode
      case bersagliGrandi, righeDistanziate
      case voiceIdentifier, voiceRate
    }

    func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encode(scelte.theme, forKey: .theme)
      try c.encode(scelte.colorVision, forKey: .colorVision)
      try c.encode(scelte.typeface, forKey: .typeface)
      try c.encode(scelte.textScale, forKey: .textScale)
      try c.encode(scelte.reducedMotion, forKey: .reducedMotion)
      try c.encode(scelte.calmMode, forKey: .calmMode)
      try c.encode(scelte.bersagliGrandi, forKey: .bersagliGrandi)
      try c.encode(scelte.righeDistanziate, forKey: .righeDistanziate)
      try c.encodeIfPresent(scelte.voiceIdentifier, forKey: .voiceIdentifier)
      try c.encode(scelte.voiceRate, forKey: .voiceRate)
    }
  }
}
