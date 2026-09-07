import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Che cosa ha già chiesto al Mac chi lo sta usando.
///
/// Nasce da un difetto vero: l'app guardava soltanto le proprie manopole. Un
/// ragazzo che aveva già acceso «Riduci movimento» nelle Impostazioni di
/// Sistema apriva MirrorScopio e si vedeva addosso tutte le animazioni, perché
/// qui dentro quella richiesta non arrivava. Chiedere due volte la stessa cosa
/// è già una fatica; chiederla e non essere ascoltati è peggio.
///
/// Sono quattro richieste, quelle che macOS espone alle applicazioni:
/// meno movimento, più contrasto, meno trasparenza, e «non farmi distinguere
/// le cose dal colore». Si leggono all'avvio e si riascoltano quando cambiano,
/// così l'app si adegua mentre è aperta, senza doverla riavviare.
@MainActor
final class AccessibilitaDelMac: ObservableObject {
  @Published private(set) var stato = StatoAccessibilitaDelMac()

  /// `nonisolated(unsafe)` perché `deinit` gira fuori dal filo principale e
  /// deve restituire questo gettone. È sicuro perché quando `deinit` parte
  /// nessun altro ha più un riferimento a questo oggetto.
  #if os(macOS)
  nonisolated(unsafe) private var osservatore: NSObjectProtocol?
  #else
  nonisolated(unsafe) private var osservatori: [NSObjectProtocol] = []
  #endif

  init() {
    rileggi()
    #if os(macOS)
    osservatore = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
      object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.rileggi() }
    }
    #else
    let notifiche = [
      UIAccessibility.reduceMotionStatusDidChangeNotification,
      UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
      UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      UIAccessibility.differentiateWithoutColorDidChangeNotification,
      UIApplication.didBecomeActiveNotification,
    ]
    osservatori = notifiche.map { nome in
      NotificationCenter.default.addObserver(forName: nome, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.rileggi() }
      }
    }
    #endif
  }

  deinit {
    #if os(macOS)
    if let osservatore {
      NSWorkspace.shared.notificationCenter.removeObserver(osservatore)
    }
    #else
    for osservatore in osservatori { NotificationCenter.default.removeObserver(osservatore) }
    #endif
  }

  private func rileggi() {
    #if os(macOS)
    let w = NSWorkspace.shared
    stato = StatoAccessibilitaDelMac(
      menoMovimento: w.accessibilityDisplayShouldReduceMotion,
      piuContrasto: w.accessibilityDisplayShouldIncreaseContrast,
      menoTrasparenza: w.accessibilityDisplayShouldReduceTransparency,
      senzaColore: w.accessibilityDisplayShouldDifferentiateWithoutColor)
    #else
    stato = StatoAccessibilitaDelMac(
      menoMovimento: UIAccessibility.isReduceMotionEnabled,
      piuContrasto: UIAccessibility.isDarkerSystemColorsEnabled,
      menoTrasparenza: UIAccessibility.isReduceTransparencyEnabled,
      senzaColore: UIAccessibility.shouldDifferentiateWithoutColor)
    #endif
  }
}

/// Le quattro richieste, ferme in un valore che si può confrontare e provare.
struct StatoAccessibilitaDelMac: Equatable {
  var menoMovimento = false
  var piuContrasto = false
  var menoTrasparenza = false
  var senzaColore = false

  /// Il Mac non sta chiedendo niente di particolare: è il caso più comune, e
  /// serve alle prove per partire da una situazione pulita.
  static let nessunaRichiesta = StatoAccessibilitaDelMac()

  var nessuna: Bool { self == .nessunaRichiesta }

  /// Che cosa dire a chi apre le impostazioni e trova una manopola già accesa
  /// che non ha acceso lui. Se l'app sa qualcosa, lo dice.
  var frase: String? {
    var richieste: [String] = []
    if menoMovimento { richieste.append("meno movimento") }
    if piuContrasto { richieste.append("più contrasto") }
    if menoTrasparenza { richieste.append("meno trasparenze") }
    if senzaColore { richieste.append("di non distinguere le cose solo dal colore") }
    guard !richieste.isEmpty else { return nil }
    let elenco: String
    if richieste.count == 1 {
      elenco = richieste[0]
    } else {
      elenco = richieste.dropLast().joined(separator: ", ") + " e " + richieste[richieste.count - 1]
    }
    #if os(macOS)
    return "Nelle Impostazioni di Sistema hai già chiesto \(elenco): MirrorScopio lo rispetta da solo."
    #else
    return "Nelle Impostazioni del dispositivo hai già chiesto \(elenco): MirrorScopio lo rispetta da solo."
    #endif
  }
}
