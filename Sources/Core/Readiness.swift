import AVFoundation
import AppKit
import FoundationModels
import Speech
import SwiftUI

/// Controlla che il Mac abbia davvero tutto quello che serve prima di iniziare.
///
/// Un Mac appena comprato non ha necessariamente il modello di riconoscimento
/// italiano né una voce italiana installata, e Apple Intelligence può essere
/// spento. Invece di scoprirlo a metà sessione — con un ragazzo che legge e
/// l'app che resta muta o sorda — lo verifichiamo prima e, quando è possibile,
/// lo sistemiamo da qui.
@MainActor
final class Readiness: ObservableObject {

  /// Che cosa può fare l'app per rimediare a una cosa che manca.
  enum Rimedio: Equatable {
    /// Il permesso si chiede dall'app.
    case chiediMicrofono
    /// Il modello si scarica dall'app, con avanzamento.
    case scaricaModello
    /// Solo l'utente può farlo, nelle Impostazioni di Sistema.
    case apriImpostazioni(String)
    /// Nessun rimedio: dipende dall'hardware.
    case nessuno
  }

  enum Stato: Equatable {
    case ok(String)
    case manca(String)
    case inCorso(Double?)
  }

  struct Voce: Identifiable, Equatable {
    let id: String
    let titolo: String
    var stato: Stato
    /// Vero se senza questa cosa l'app non può funzionare.
    let necessaria: Bool
    var rimedio: Rimedio

    var isOK: Bool { if case .ok = stato { return true }; return false }
    var isInCorso: Bool { if case .inCorso = stato { return true }; return false }
  }

  @Published private(set) var voci: [Voce] = []
  @Published private(set) var staControllando = false

  /// Vero quando tutto ciò che è necessario è a posto.
  var puoIniziare: Bool { voci.filter(\.necessaria).allSatisfy(\.isOK) }

  /// Vero quando manca qualcosa, necessario o no: è il segnale per mostrare
  /// la schermata di preparazione all'avvio.
  var qualcosaManca: Bool { voci.contains { !$0.isOK } }

  private let locale = Locale(identifier: "it-IT")

  // MARK: - Controllo

  func controlla() async {
    staControllando = true
    defer { staControllando = false }

    var nuove: [Voce] = []
    nuove.append(vocieMicrofono())
    nuove.append(voceIngresso())
    nuove.append(await voceModelloVocale())
    nuove.append(voceVoceItaliana())
    nuove.append(voceAppleIntelligence())
    voci = nuove
  }

  private func vocieMicrofono() -> Voce {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      return Voce(id: "microfono", titolo: "Permesso del microfono",
                  stato: .ok("Concesso."), necessaria: true, rimedio: .nessuno)
    case .notDetermined:
      return Voce(id: "microfono", titolo: "Permesso del microfono",
                  stato: .manca("Da concedere. L'audio resta su questo Mac."),
                  necessaria: true, rimedio: .chiediMicrofono)
    default:
      return Voce(id: "microfono", titolo: "Permesso del microfono",
                  stato: .manca("Negato. Va riattivato nelle Impostazioni di Sistema."),
                  necessaria: true,
                  rimedio: .apriImpostazioni("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"))
    }
  }

  private func voceIngresso() -> Voce {
    let ingressi = AudioDevices.inputs()
    guard let corrente = AudioDevices.defaultInput(),
          let nome = ingressi.first(where: { $0.id == corrente })?.name else {
      return Voce(id: "ingresso", titolo: "Microfono collegato",
                  stato: .manca("Nessun microfono disponibile."),
                  necessaria: true,
                  rimedio: .apriImpostazioni("x-apple.systempreferences:com.apple.preference.sound?input"))
    }
    return Voce(id: "ingresso", titolo: "Microfono collegato",
                stato: .ok(nome), necessaria: true, rimedio: .nessuno)
  }

  private func voceModelloVocale() async -> Voce {
    guard SpeechTranscriber.isAvailable,
          let supportata = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
      return Voce(id: "modello", titolo: "Riconoscimento vocale italiano",
                  stato: .manca("Questo Mac non offre il riconoscimento in italiano."),
                  necessaria: true, rimedio: .nessuno)
    }
    let modulo = SpeechTranscriber(locale: supportata, transcriptionOptions: [],
                                   reportingOptions: [], attributeOptions: [])
    if await AssetInventory.status(forModules: [modulo]) == .installed {
      return Voce(id: "modello", titolo: "Riconoscimento vocale italiano",
                  stato: .ok("Installato su questo Mac."), necessaria: true, rimedio: .nessuno)
    }
    return Voce(id: "modello", titolo: "Riconoscimento vocale italiano",
                stato: .manca("Da scaricare una volta sola. Poi funziona senza internet."),
                necessaria: true, rimedio: .scaricaModello)
  }

  private func voceVoceItaliana() -> Voce {
    let italiane = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("it") }
    guard let migliore = Speaker.italianVoice, !italiane.isEmpty else {
      return Voce(id: "voce", titolo: "Voce italiana del Mac",
                  stato: .manca("Nessuna voce italiana installata. Serve per dettare le parole."),
                  necessaria: true,
                  rimedio: .apriImpostazioni("x-apple.systempreferences:com.apple.Accessibility-Settings.extension?SpokenContent"))
    }
    if migliore.quality == .default {
      return Voce(id: "voce", titolo: "Voce italiana del Mac",
                  stato: .manca("C'è solo «\(migliore.name)», di qualità base. Una voce migliorata si capisce molto meglio."),
                  necessaria: false,
                  rimedio: .apriImpostazioni("x-apple.systempreferences:com.apple.Accessibility-Settings.extension?SpokenContent"))
    }
    return Voce(id: "voce", titolo: "Voce italiana del Mac",
                stato: .ok("\(migliore.name), qualità alta."), necessaria: false, rimedio: .nessuno)
  }

  private func voceAppleIntelligence() -> Voce {
    switch Intelligence.state {
    case .available:
      return Voce(id: "intelligence", titolo: "Apple Intelligence (facoltativo)",
                  stato: .ok("Attivo: i commenti clinici sono più ricchi."),
                  necessaria: false, rimedio: .nessuno)
    case .unavailable(let motivo):
      return Voce(id: "intelligence", titolo: "Apple Intelligence (facoltativo)",
                  stato: .manca("\(motivo) L'app funziona lo stesso: il voto resta un confronto esatto fra parole."),
                  necessaria: false,
                  rimedio: .apriImpostazioni("x-apple.systempreferences:com.apple.Siri-Settings.extension"))
    }
  }

  // MARK: - Rimedi

  func applica(_ voce: Voce) async {
    switch voce.rimedio {
    case .chiediMicrofono:
      _ = await AVCaptureDevice.requestAccess(for: .audio)
      await controlla()

    case .apriImpostazioni(let url):
      if let u = URL(string: url) { NSWorkspace.shared.open(u) }

    case .scaricaModello:
      await scaricaModello()

    case .nessuno:
      break
    }
  }

  private func scaricaModello() async {
    guard let supportata = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else { return }
    let modulo = SpeechTranscriber(locale: supportata, transcriptionOptions: [],
                                   reportingOptions: [], attributeOptions: [])
    aggiorna("modello", .inCorso(nil))

    guard let richiesta = try? await AssetInventory.assetInstallationRequest(supporting: [modulo]) else {
      aggiorna("modello", .manca("Non riesco a chiedere il download. Controlla la connessione."))
      return
    }

    // L'avanzamento arriva da un `Progress`: lo leggiamo a intervalli perché
    // serve solo a far vedere che qualcosa si muove.
    let avanzamento = richiesta.progress
    let osservatore = Task { @MainActor in
      while !Task.isCancelled {
        aggiorna("modello", .inCorso(avanzamento.fractionCompleted))
        try? await Task.sleep(for: .milliseconds(300))
      }
    }
    defer { osservatore.cancel() }

    do {
      try await richiesta.downloadAndInstall()
      _ = try? await AssetInventory.reserve(locale: supportata)
      await controlla()
    } catch {
      aggiorna("modello", .manca("Download non riuscito: \(error.localizedDescription)"))
    }
  }

  private func aggiorna(_ id: String, _ stato: Stato) {
    guard let i = voci.firstIndex(where: { $0.id == id }) else { return }
    voci[i].stato = stato
  }
}
