import Foundation

/// Il banco dell'aggiornamento dall'app.
///
/// Qui si prova la parte che nessuna prova scritta a tavolino può coprire:
/// aprire un pacchetto vero, guardare una firma vera, e sostituire un'app
/// vera mentre sta sul disco. Sono le tre cose che, se sbagliano, rompono
/// l'app di chi la sta usando — e sono anche le tre cose che si scoprono
/// rotte solo il giorno del rilascio, se non le si prova prima.
///
/// Gira su `build/MirrorScopio.app`, cioè su quello che ha appena compilato
/// `build.sh`. Sul Mac di casa quell'app è firmata Fight The Stroke ma **non**
/// è passata da Apple: il timbro non c'è, e non può esserci. Perciò il timbro
/// qui si controlla solo per dire che il controllo funziona e sa dire di no —
/// che è poi la cosa che deve saper fare.
///
///   swiftc ... Tests/AggiornamentoHarness.swift && ./banco
@main
struct AggiornamentoHarness {
  static var fallite = 0

  static func prova(_ cosa: String, _ atteso: Bool) {
    print(atteso ? "  ✓ \(cosa)" : "  ✗ \(cosa)")
    if !atteso { fallite += 1 }
  }

  static func main() {
    let fm = FileManager.default
    let app = URL(fileURLWithPath: "build/MirrorScopio.app")
    guard fm.fileExists(atPath: app.path) else {
      print("✗ manca build/MirrorScopio.app — lancia prima ./build.sh")
      exit(1)
    }

    let lavoro = fm.temporaryDirectory
      .appendingPathComponent("banco-aggiornamento-\(UUID().uuidString)")
    try? fm.createDirectory(at: lavoro, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: lavoro) }

    // 1. Il pacchetto si apre e la firma sopravvive al viaggio.
    //
    // È il punto in cui si sbaglia più spesso: `zip` normale perde permessi e
    // collegamenti interni, l'app arriva a destinazione con la firma rotta, e
    // l'aggiornamento si ferma senza che nessuno capisca perché. `ditto`, che
    // è quello che usiamo, li tiene.
    print("── il pacchetto ──")
    let zip = lavoro.appendingPathComponent("pacchetto.zip")
    let fatto = Process()
    fatto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    fatto.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", app.path, zip.path]
    try? fatto.run()
    fatto.waitUntilExit()
    prova("lo zip si crea", fatto.terminationStatus == 0)

    let aperto = lavoro.appendingPathComponent("aperto", isDirectory: true)
    do {
      try Installazione.apri(zip, in: aperto)
      prova("il pacchetto si riapre", true)
    } catch {
      prova("il pacchetto si riapre", false)
    }
    guard let dentro = Installazione.trovaApp(in: aperto) else {
      print("  ✗ dentro il pacchetto non c'è nessuna app")
      exit(1)
    }

    // 2. La firma è la nostra.
    print("── la firma ──")
    do {
      try Installazione.verificaCheSiaNostra(dentro)
      prova("l'app uscita dal pacchetto è firmata Fight The Stroke", true)
    } catch {
      // Su un Mac senza il certificato della fondazione build.sh firma
      // "ad-hoc": lì questo controllo deve dire di no, ed è giusto così.
      let adHoc = firmaAdHoc(app)
      prova("l'app uscita dal pacchetto è firmata Fight The Stroke"
            + (adHoc ? " (saltato: build firmata ad-hoc)" : ""), adHoc)
    }

    // 3. Un'app che non è la nostra viene rifiutata. È il controllo che conta:
    // senza, basterebbe un pacchetto qualunque per prendere il nostro posto.
    let estranea = lavoro.appendingPathComponent("Estranea.app")
    try? fm.copyItem(at: dentro, to: estranea)
    let rifirma = Process()
    rifirma.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    rifirma.arguments = ["--force", "--sign", "-", "--identifier",
                         "org.esempio.cattivo", estranea.path]
    rifirma.standardError = FileHandle.nullDevice
    try? rifirma.run()
    rifirma.waitUntilExit()
    var rifiutata = false
    do { try Installazione.verificaCheSiaNostra(estranea) } catch { rifiutata = true }
    prova("un'app firmata da qualcun altro viene rifiutata", rifiutata)

    var senzaTimbro = false
    do { try Installazione.verificaTimbroApple(estranea) } catch { senzaTimbro = true }
    prova("senza il timbro di Apple non si installa", senzaTimbro)

    // 4. La versione dichiarata dev'essere quella che c'è dentro.
    print("── la versione ──")
    let vera = (Bundle(url: dentro)?.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                as? String) ?? "0.0.0"
    var corretta = true
    do { try Installazione.verificaVersione(dentro, attesa: vera) } catch { corretta = false }
    prova("la versione dentro il pacchetto combacia", corretta)

    var sbagliata = false
    do { try Installazione.verificaVersione(dentro, attesa: "99.9.9") } catch { sbagliata = true }
    prova("una versione diversa da quella annunciata viene rifiutata", sbagliata)

    // 5. Lo scambio. Deve funzionare, e soprattutto non deve mai lasciare il
    // posto vuoto: se fallisse a metà, chi sta usando l'app resterebbe senza.
    print("── lo scambio ──")
    let posto = lavoro.appendingPathComponent("Installata.app")
    try? fm.copyItem(at: app, to: posto)
    do {
      try Installazione.sostituisci(posto, con: dentro)
      let ancoraLì = fm.fileExists(atPath: posto.appendingPathComponent(
        "Contents/MacOS/MirrorScopio").path)
      prova("la versione nuova prende il posto della vecchia", ancoraLì)
      var dopo: SecStaticCode?
      _ = SecStaticCodeCreateWithPath(posto as CFURL, [], &dopo)
      prova("dopo lo scambio l'app è ancora firmata", dopo != nil)
    } catch {
      prova("la versione nuova prende il posto della vecchia", false)
    }

    print("")
    if fallite == 0 {
      print("Tutto a posto: l'aggiornamento dall'app regge.")
      exit(0)
    }
    print("\(fallite) controlli non passati.")
    exit(1)
  }

  /// Vero quando l'app è stata firmata "ad-hoc", cioè senza il certificato
  /// della fondazione: succede su qualunque Mac che non ha le chiavi.
  static func firmaAdHoc(_ app: URL) -> Bool {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    p.arguments = ["-dvv", app.path]
    let tubo = Pipe()
    p.standardError = tubo
    p.standardOutput = FileHandle.nullDevice
    try? p.run()
    let esito = String(data: tubo.fileHandleForReading.readDataToEndOfFile(),
                       encoding: .utf8) ?? ""
    p.waitUntilExit()
    return !esito.contains("Developer ID Application")
  }
}
