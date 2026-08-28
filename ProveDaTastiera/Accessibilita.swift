import XCTest
import ApplicationServices
import AppKit

/// Il canale di VoiceOver, aperto dalle prove.
///
/// XCUITest su macOS non sa dire quale comando ha il fuoco della tastiera:
/// `hasFocus` esiste su iPhone e iPad, ma nell'intestazione di sistema è
/// racchiuso in `#if !TARGET_OS_OSX`. Non è una mancanza da aggirare con
/// un trucco: significa che su Mac la domanda «dov'è il fuoco?» si fa a un
/// altro sportello, quello dell'accessibilità di sistema.
///
/// È lo stesso sportello a cui si presenta VoiceOver. Quello che si legge qui
/// sotto è, parola per parola, quello che una persona che non vede lo schermo
/// si sentirebbe pronunciare. Per questo vale la pena di scriverlo: una prova
/// che passa da qui non «assomiglia» a un controllo di accessibilità, è
/// esattamente quel controllo.
enum Accessibilita {

  /// Il processo dell'applicazione sotto prova.
  static func processo(bundleID: String) -> pid_t? {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
      .first?.processIdentifier
  }

  /// Questo processo ha il permesso di guardare dentro le altre applicazioni?
  ///
  /// Senza il permesso di accessibilità lo sportello risponde «niente» a ogni
  /// domanda, esattamente come risponderebbe un'applicazione davvero priva di
  /// fuoco da tastiera. Le due cose vanno distinte prima di dare la colpa a
  /// qualcuno: una prova che accusa l'app di un difetto che è invece un
  /// permesso mancante insegna a non fidarsi delle prove.
  static var permessoConcesso: Bool { AXIsProcessTrusted() }

  /// L'ultimo errore incontrato interrogando lo sportello, in chiaro.
  static private(set) var ultimoErrore: String?

  /// Il comando che ha il fuoco della tastiera, descritto come lo direbbe
  /// VoiceOver: prima il nome, poi che cosa è.
  static func comandoAFuoco(pid: pid_t) -> String? {
    let app = AXUIElementCreateApplication(pid)
    var fuoco: CFTypeRef?
    let esito = AXUIElementCopyAttributeValue(
      app, kAXFocusedUIElementAttribute as CFString, &fuoco)
    if esito != .success { ultimoErrore = "AXError \(esito.rawValue)" }
    guard esito == .success,
      let elemento = fuoco, CFGetTypeID(elemento) == AXUIElementGetTypeID()
    else { return nil }

    let ax = unsafeBitCast(elemento, to: AXUIElement.self)
    let nome = [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute]
      .compactMap { stringa(ax, $0) }
      .first { !$0.isEmpty } ?? ""
    let ruolo = stringa(ax, kAXRoleDescriptionAttribute) ?? stringa(ax, kAXRoleAttribute) ?? "?"
    return "\(nome.isEmpty ? "«senza nome»" : nome) (\(ruolo))"
  }

  private static func stringa(_ elemento: AXUIElement, _ attributo: String) -> String? {
    var valore: CFTypeRef?
    guard AXUIElementCopyAttributeValue(elemento, attributo as CFString, &valore) == .success
    else { return nil }
    return (valore as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Il Mac permette davvero di raggiungere tutti i comandi con il tasto Tab?
  ///
  /// Su macOS è un'impostazione di sistema («Navigazione da tastiera»): finché
  /// è spenta, Tab salta da un campo di testo all'altro e ignora i pulsanti.
  /// Nessuna applicazione può accenderla da sola, quindi una prova che la
  /// ignorasse racconterebbe una bugia in un verso o nell'altro: direbbe «non
  /// si naviga» quando invece si naviga, o passerebbe senza aver provato
  /// niente.
  static var navigazioneDaTastieraAttiva: Bool {
    let globale = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)
    let modo = (globale?["AppleKeyboardUIMode"] as? NSNumber)?.intValue ?? 0
    // Il bit 1 è «tutti i comandi», non solo i campi di testo.
    return modo & 2 != 0
  }
}
