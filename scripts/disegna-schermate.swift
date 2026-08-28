import AppKit
import SwiftUI

// Disegna l'interfaccia in PNG, per guardarla.
//
// Non e' una prova e non boccia niente: quello lo fanno le prove vere in
// Verifiche/ (contrasto, scorrimento, testo sotto il bordo) e in
// ProveDaTastiera/. Per un po' questo file rifaceva anche quei controlli, con
// il proprio calcolo del contrasto e il proprio elenco di schermate: due
// copie della stessa regola che potevano dire cose diverse senza che nessuno
// se ne accorgesse. Adesso qui si disegna e basta.
//
// Serve perche' un'immagine si guarda in mezzo secondo. E' cosi' che sono
// saltati fuori i pulsanti principali bianchi su giallo in altissimo
// contrasto: leggendo il codice non se ne era accorto nessuno.
//
// `ImageRenderer` disegna una vista SwiftUI fuori dallo schermo, senza
// finestre e senza permessi.

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

@main
struct DisegnaSchermate {
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
      print("Le immagini sono in build/schermate/.")
    }
  }
}
