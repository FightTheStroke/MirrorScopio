import Foundation
import FoundationModels

/// Sintesi clinica della sessione prodotta dal modello Apple on-device.
@Generable
struct ClinicalSummary {
  @Guide(description: "Due o tre frasi che descrivono il profilo di lettura emerso dalla sessione.")
  var profilo: String

  @Guide(description: "Il pattern di errore più ricorrente, indicato in termini logopedici.")
  var patternPrevalente: String

  @Guide(description: "Da una a tre proposte operative concrete per la seduta successiva.")
  var proposte: [String]
}

/// Etichetta clinica dell'errore prodotta dal modello on-device.
@Generable
struct ResponseJudgement {
  @Guide(description: "Categoria dell'errore: inversione, sostituzione, omissione, aggiunta, lessicalizzazione, altro.")
  var categoria: String
}

/// Wrapper sul modello linguistico on-device di Apple Intelligence.
/// Tutto resta sul Mac: nessuna chiamata di rete, nessun dato clinico esposto.
@MainActor
final class Intelligence {

  enum State {
    case available
    case unavailable(String)
  }

  static var state: State {
    switch SystemLanguageModel.default.availability {
    case .available:
      return .available
    case .unavailable(let reason):
      switch reason {
      case .deviceNotEligible:
        return .unavailable("Questo Mac non supporta Apple Intelligence.")
      case .appleIntelligenceNotEnabled:
        return .unavailable("Attiva Apple Intelligence in Impostazioni di Sistema.")
      case .modelNotReady:
        return .unavailable("Il modello on-device si sta ancora scaricando.")
      @unknown default:
        return .unavailable("Modello on-device non disponibile.")
      }
    @unknown default:
      return .unavailable("Modello on-device non disponibile.")
    }
  }

  static var isAvailable: Bool {
    if case .available = state { return true }
    return false
  }

  /// Etichetta qualitativa dell'errore. Il modello non può ribaltare il verdetto:
  /// l'esito resta deciso dal confronto testuale, che è verificabile e riproducibile.
  static func judge(target: String, transcript: String) async -> ResponseJudgement? {
    guard isAvailable, !transcript.isEmpty else { return nil }
    let session = LanguageModelSession(instructions: """
      Sei un supporto per logopedisti italiani. Ricevi la parola bersaglio mostrata a un \
      paziente e la trascrizione di ciò che il paziente ha pronunciato. Le due stringhe \
      sono diverse. Classifica il tipo di differenza in termini logopedici, con una sola \
      parola. Rispondi solo con il campo richiesto.
      """)
    let prompt = "Bersaglio: \"\(target)\". Trascrizione: \"\(transcript)\"."
    do {
      let response = try await session.respond(to: prompt, generating: ResponseJudgement.self)
      return response.content
    } catch {
      return nil
    }
  }

  /// Descrittori qualitativi: al modello non vengono passate cifre, perché tenderebbe
  /// a ricopiarle o rielaborarle e un numero sbagliato invaliderebbe la sintesi.
  private static func qualitative(trials: [Trial], config: SessionConfig) -> String {
    let correct = trials.filter(\.correct).count
    let ratio = Double(correct) / Double(trials.count)
    let accuracy = switch ratio {
    case 0.9...: "quasi tutte le prove sono state lette correttamente"
    case 0.7..<0.9: "la maggior parte delle prove è stata letta correttamente"
    case 0.4..<0.7: "le prove corrette e quelle errate si equivalgono all'incirca"
    default: "le prove errate sono nettamente più numerose di quelle corrette"
    }

    let ranked = Dictionary(grouping: trials.filter { !$0.correct }, by: \.errorKind)
      .sorted { $0.value.count > $1.value.count }
      .map(\.key.label)
    let errors = ranked.isEmpty
      ? "nessun errore rilevato"
      : "categorie di errore in ordine di frequenza: " + ranked.joined(separator: ", ")

    let examples = trials.filter { !$0.correct }.prefix(10)
      .map { "\($0.stimulus) → \($0.response.isEmpty ? "nessuna risposta" : $0.response)" }
      .joined(separator: "; ")

    var facts = """
      Lista di stimoli: \(config.set.label).
      Andamento: \(accuracy).
      \(errors).
      Procedura: \(config.staircase == .fixed ? "esposizione fissa" : "esposizione adattiva").
      """
    if !examples.isEmpty { facts += "\nEsempi di errore: \(examples)." }
    return facts
  }

  /// Relazione finale sulla sessione, da allegare alla cartella del paziente.
  static func summarize(trials: [Trial], thresholdMs: Double?, config: SessionConfig) async -> ClinicalSummary? {
    guard isAvailable, !trials.isEmpty else { return nil }

    let session = LanguageModelSession(instructions: """
      Sei un supporto per logopedisti italiani. Ricevi la descrizione qualitativa di una \
      sessione tachistoscopica di lettura e produci una sintesi sobria e professionale \
      in italiano. Non formulare diagnosi. Basati solo su ciò che ti viene detto. \
      Non inventare e non citare numeri, percentuali o millisecondi: le cifre sono già \
      nel resoconto e una cifra sbagliata renderebbe la sintesi inutilizzabile. \
      Sii concreto e breve.
      """)
    do {
      let response = try await session.respond(
        to: qualitative(trials: trials, config: config),
        generating: ClinicalSummary.self)
      return response.content
    } catch {
      return nil
    }
  }
}
