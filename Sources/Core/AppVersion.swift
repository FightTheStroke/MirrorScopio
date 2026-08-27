import Foundation

/// La versione dell'app, letta dal bundle. Unica fonte di verità: il file
/// `VERSION` alla radice del repository, che `build.sh` scrive nell'Info.plist.
/// Niente costanti duplicate nel codice: si disallineano sempre.
enum AppVersion {
  /// Versione leggibile, per esempio "0.1.0".
  static let short: String = info("CFBundleShortVersionString") ?? "0.0.0"

  /// Numero di build progressivo: quanti commit ha il repository.
  static let build: String = info("CFBundleVersion") ?? "0"

  /// Il commit da cui è stato compilato questo binario.
  static let commit: String = info("FTSGitCommit") ?? "sconosciuto"

  /// Vero quando è stato compilato con modifiche non salvate: utile per capire
  /// se quello che si sta guardando corrisponde davvero a un commit.
  static let isDirty: Bool = (info("FTSGitDirty") ?? "no") == "si"

  static let buildDate: String = info("FTSBuildDate") ?? ""

  /// Quello che si mostra all'adulto nelle impostazioni.
  static var display: String {
    "MirrorScopio \(short) (build \(build))" + (isDirty ? " · con modifiche locali" : "")
  }

  /// La riga lunga, per il supporto e per i referti.
  static var detail: String {
    var parts = ["versione \(short)", "build \(build)", "commit \(commit)"]
    if !buildDate.isEmpty { parts.append("compilata il \(buildDate)") }
    if isDirty { parts.append("con modifiche locali") }
    return parts.joined(separator: " · ")
  }

  private static func info(_ key: String) -> String? {
    Bundle.main.object(forInfoDictionaryKey: key) as? String
  }
}
