// swift-tools-version: 6.0
import PackageDescription

// Questo pacchetto **non** costruisce l'applicazione: quella la costruisce
// `./build.sh`, che assembla il pacchetto .app, ci mette dentro l'icona e i
// font e lo firma. Serve a una cosa sola: dare un bersaglio a `swift test`,
// così le verifiche deterministiche si scrivono con Swift Testing invece che
// come programmi a sé stanti che stampano righe e che qualcuno deve leggere.
//
// Le prove che parlano col microfono e col modello vocale di sistema restano
// programmi a parte, dentro `Tests/`: hanno bisogno di girare dentro un
// pacchetto applicazione firmato, altrimenti macOS non concede il modello
// italiano. Non è pigrizia, è un vincolo del sistema — e infatti `./test.sh`
// li impacchetta in un .app usa e getta prima di eseguirli.
let package = Package(
  name: "MirrorScopio",
  // La stessa versione che usa `./build.sh` (`-target arm64-apple-macos26.0`):
  // se qui fosse più bassa, il compilatore rifiuterebbe il modello di
  // Intelligence, che esiste solo da macOS 26.
  platforms: [.macOS("26.0")],
  targets: [
    .target(
      name: "MirrorScopioCore",
      path: "Sources",
      // `App.swift` porta il `@main` dell'applicazione: dentro una libreria
      // non ci sta, e non serve a nessuna verifica.
      exclude: ["App.swift"],
      // `./build.sh` compila in modalità Swift 5, quindi anche qui: se le due
      // costruzioni usassero regole diverse, le verifiche direbbero la verità
      // su un programma che non è quello che poi si installa.
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .testTarget(
      name: "MirrorScopioTests",
      dependencies: ["MirrorScopioCore"],
      path: "Verifiche",
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
  ]
)
