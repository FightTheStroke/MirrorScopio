import AppKit
import SwiftUI

// Un banco di prova che *disegna* l'interfaccia in PNG.
//
// Serve perché l'accessibilità di sistema su questo Mac non risponde, e senza
// quella non si può leggere l'albero delle viste né catturare una finestra:
// per settimane l'unico modo di «vedere» una schermata è stato leggere il
// codice e immaginarsela. Immaginarsela non basta — è così che i pulsanti
// principali sono finiti bianchi su giallo in altissimo contrasto, un difetto
// che sarebbe saltato all'occhio in mezzo secondo guardandolo.
//
// `ImageRenderer` disegna una vista SwiftUI fuori dallo schermo, senza finestre
// e senza permessi. Non prova che l'app *funzioni*: prova che quello che si
// vede è quello che si crede di aver scritto.

@MainActor
func disegna<V: View>(_ vista: V, nome: String, larghezza: CGFloat = 900, altezza: CGFloat = 620) {
  let r = ImageRenderer(content: vista.frame(width: larghezza, height: altezza))
  r.scale = 2
  guard let img = r.nsImage,
        let tiff = img.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:]) else {
    print("✗ \(nome) — non si e' riusciti a disegnarla")
    return
  }
  let url = URL(fileURLWithPath: "build/schermate/\(nome).png")
  try? png.write(to: url)
  print("· \(nome).png  \(Int(img.size.width))×\(Int(img.size.height))")
}

/// Quanto e' alto davvero il contenuto di una vista, senza costringerlo.
///
/// Serve per rispondere a una domanda che finora non ci eravamo posti: quando
/// qualcuno alza «Dimensione di tutto» a 1,8 — cioe' l'impostazione che apre
/// chi vede poco — il contenuto ci sta ancora nella finestra? Se non ci sta e
/// la schermata non scorre, i pulsanti finiscono fuori e non si raggiungono
/// piu' in nessun modo. Chi ha ipovisione resterebbe chiuso fuori proprio
/// dall'impostazione fatta per lui.
@MainActor
func altezzaNaturale<V: View>(_ vista: V, larghezza: CGFloat) -> CGFloat {
  let r = ImageRenderer(content: vista.frame(width: larghezza).fixedSize(horizontal: false, vertical: true))
  return r.nsImage?.size.height ?? 0
}

/// Un campionario dei mattoncini condivisi, in un tema.
struct Campionario: View {
  var a11y: A11ySettings
  var tema: ThemeChoice
  var nomeTema: String

  var body: some View {
    let pal = Palette.resolve(theme: tema, vision: a11y.colorVision, system: .light)
    VStack(alignment: .leading, spacing: Metrica.spazio) {
      IntestazionePagina(titolo: nomeTema, sottotitolo: "campionario dei mattoncini",
                         a11y: a11y) {}

      Group {
        SectionTitle(text: "I pulsanti", a11y: a11y)
        BigButton(title: "Via!", symbol: "play.fill", a11y: a11y) {}
        BigButton(title: "Torna indietro", a11y: a11y, prominent: false) {}
        HStack(spacing: Metrica.spazioPiccolo) {
          SmallButton(title: "Consenti il microfono", a11y: a11y, prominente: true) {}
          SmallButton(title: "Esporta PDF", symbol: "doc.fill", a11y: a11y) {}
          SmallButton(title: "Cancella", symbol: "trash", a11y: a11y, distruttivo: true) {}
        }
        HStack(spacing: Metrica.spazioPiccolo) {
          StopButton(a11y: a11y) {}
          PulsanteChiudi(a11y: a11y, cosa: "il campionario") {}
        }

        SectionTitle(text: "Le scelte e gli esiti", a11y: a11y)
        HStack(spacing: Metrica.spazioPiccolo) {
          ChoiceCard(title: "Leggi", subtitle: "si legge ad alta voce",
                     symbol: "mic.fill", selected: true, a11y: a11y) {}
          ChoiceCard(title: "Scrivi", subtitle: "si scrive con la tastiera",
                     symbol: "keyboard", selected: false, a11y: a11y) {}
          VStack(alignment: .leading, spacing: Metrica.spazioMinimo) {
            Verdict(correct: true, a11y: a11y)
            Verdict(correct: false, a11y: a11y)
          }
        }
        Explain(text: "Il testo che dice **perché**, mai per riempire.", a11y: a11y)
      }
      .padding(.horizontal, Metrica.margine)
      Spacer(minLength: 0)
    }
    .background(pal.background)
    .environment(\.palette, pal)
  }
}

// MARK: - Il contrasto, misurato

/// Il rapporto di contrasto fra due colori, come lo definisce la WCAG.
/// Sotto 4,5 a 1 un testo normale non e' leggibile da chi ha ipovisione.
@MainActor
func contrasto(_ a: Color, _ b: Color) -> Double {
  func luminanza(_ c: Color) -> Double {
    let n = NSColor(c).usingColorSpace(.sRGB) ?? .black
    func canale(_ v: Double) -> Double {
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * canale(Double(n.redComponent))
         + 0.7152 * canale(Double(n.greenComponent))
         + 0.0722 * canale(Double(n.blueComponent))
  }
  let x = luminanza(a), y = luminanza(b)
  return (max(x, y) + 0.05) / (min(x, y) + 0.05)
}

/// Controlla che ogni parola che l'app scrive si legga davvero, in ogni tema e
/// per ogni modo di vedere i colori.
///
/// Esiste perche' due volte di fila abbiamo messo del testo illeggibile senza
/// accorgercene: bianco su giallo nei pulsanti principali, e la parola
/// «giusta» a 1,76 a 1 per chi vede in grigio e usa il tema scuro. Un occhio
/// distratto non se ne accorge; una divisione si'.
@MainActor
func verificaContrasti() -> Bool {
  var tutteAPosto = true
  let soglia = 4.5

  for tema in ThemeChoice.allCases where tema != .auto {
    for vista in ColorVision.allCases {
      let p = Palette.resolve(theme: tema, vision: vista, system: .light)
      let prove: [(String, Color, Color)] = [
        ("testo sul fondo",       p.foreground, p.background),
        ("testo sulla carta",     p.foreground, p.surface),
        ("testo smorzato",        p.muted,      p.background),
        ("«giusta»",              p.ok,         p.background),
        ("«ancora»",              p.wrong,      p.background),
        ("«giusta» sulla carta",  p.ok,         p.surface),
        ("«ancora» sulla carta",  p.wrong,      p.surface),
        ("scritta sull'accento",  p.onAccent,   p.accent),
      ]
      for (che, a, b) in prove {
        let r = contrasto(a, b)
        if r < soglia {
          print("  ✗ \(tema.label) · \(vista.label) · \(che): \(String(format: "%.2f", r)) a 1")
          tutteAPosto = false
        }
      }
    }
  }
  return tutteAPosto
}

@main
struct SchermateHarness {
  static func main() {
    MainActor.assumeIsolated {
      try? FileManager.default.createDirectory(
        atPath: "build/schermate", withIntermediateDirectories: true)
      FontLoader.registerBundledFonts(da: URL(fileURLWithPath: "Resources/Fonts"))

      var base = A11ySettings()
      print("── I mattoncini, in tutti i temi ──")
      for (tema, nome) in [(ThemeChoice.chiaro, "Chiaro"),
                           (.scuro, "Scuro"),
                           (.altoContrasto, "Altissimo contrasto"),
                           (.sabbia, "Carta")] {
        disegna(Campionario(a11y: base, tema: tema, nomeTema: nome),
                nome: "mattoncini-\(tema.rawValue)", altezza: 700)
      }

      print("")
      print("── Lo stesso, ingrandito e con il carattere per la dislessia ──")
      base.textScale = 1.4
      base.typeface = .openDyslexic
      disegna(Campionario(a11y: base, tema: .chiaro, nomeTema: "Ingrandito 1,4"),
              nome: "mattoncini-ingranditi", larghezza: 1100, altezza: 900)

      print("")
      print("── Le schermate vere, quando si ingrandisce tutto ──")
      // La finestra piu' piccola in cui l'app puo' trovarsi su un portatile.
      let finestra: CGFloat = 700
      for scala in [1.0, 1.8] as [Double] {
        var s = A11ySettings()
        s.textScale = scala
        let h = altezzaNaturale(
          InstructionsView(engine: SessionEngine(), a11y: s)
            .environment(\.palette, Palette.resolve(theme: .chiaro, vision: .standard, system: .light)),
          larghezza: 1000)
        print("  «Pronti?» ×\(String(format: "%.1f", scala)): il contenuto e' alto \(Int(h)) punti, la finestra \(Int(finestra))"
              + (h > finestra ? " — piu' della finestra, quindi deve scorrere" : ""))
      }

      // Misurare l'altezza dice che il contenuto non ci sta; non dice se si
      // riesce comunque a raggiungerlo. Quello dipende da una cosa sola: che
      // la schermata scorra. Si controlla sul codice, che e' l'unico posto
      // dove la risposta e' netta.
      print("")
      print("── Ogni schermata intera scorre? ──")
      let intere = ["HomeView", "SettingsView", "DashboardView", "AiutoView",
                    "ReportView", "OnboardingView", "ReadinessView",
                    "AudioCheckView", "InstructionsView"]
      var senzaScorrimento: [String] = []
      for nome in intere {
        let testo = (try? String(contentsOfFile: "Sources/Views/\(nome).swift", encoding: .utf8)) ?? ""
        // «PaginaConElenco» porta con se' il proprio scorrimento: Impostazioni
        // e Progressi non scrivono piu' «ScrollView» perche' lo fa il guscio.
        if !testo.contains("ScrollView") && !testo.contains("PaginaConElenco") {
          senzaScorrimento.append(nome)
        }
      }
      if senzaScorrimento.isEmpty {
        print("  si', tutte e \(intere.count)")
      } else {
        print("  ✗ non scorrono: \(senzaScorrimento.joined(separator: ", "))")
        print("    chi ingrandisce il testo perde i pulsanti sotto il bordo, senza rimedio")
        exit(1)
      }

      print("")
      print("── Il contrasto di ogni parola, in ogni tema e per ogni modo di vedere ──")
      // Prima di fidarsi di un controllo, bisogna vederlo fallire. Questa e'
      // esattamente la combinazione che avevamo scritto per sbaglio: bianco
      // sul giallo dell'altissimo contrasto. Se un giorno questa riga non
      // dovesse piu' segnalare niente, vorrebbe dire che il controllo ha
      // smesso di controllare e nessuno se ne sarebbe accorto.
      let giallo = Palette.resolve(theme: .altoContrasto, vision: .standard, system: .light).accent
      let bianchoSuGiallo = contrasto(.white, giallo)
      if bianchoSuGiallo >= 4.5 {
        print("  ✗ il controllo del contrasto non funziona: dice che bianco su giallo va bene")
        exit(1)
      }
      print("  (il controllo sa fallire: bianco su giallo = \(String(format: "%.2f", bianchoSuGiallo)) a 1)")
      if verificaContrasti() {
        print("  tutte le combinazioni stanno sopra 4,5 a 1")
      } else {
        print("")
        print("✗ ci sono scritte che non si leggono")
        exit(1)
      }

      print("")
      print("Le immagini sono in build/schermate/.")
    }
  }
}
