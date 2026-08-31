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

/// L'altezza che la vista prende davvero, alla larghezza data.
///
/// Serve quando si fotografa qualcosa che cresce col testo: se l'immagine
/// fosse più corta, le righe si accavallerebbero **nella foto** e non nella
/// realtà — e la foto racconterebbe un difetto che non c'è, o ne
/// nasconderebbe uno che c'è.
@MainActor
func altezzaNaturale<V: View>(_ vista: V, larghezza: CGFloat) -> CGFloat {
  let r = ImageRenderer(content: vista.frame(width: larghezza).fixedSize(horizontal: false, vertical: true))
  return r.nsImage?.size.height ?? 0
}

/// Un campionario dei mattoncini condivisi, in un tema.
struct Campionario: View {
  var a11y: EffettiveImpostazioniAccessibilita
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

      let base = EffettiveImpostazioniAccessibilita()
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
      var manopoleIngrandite = A11ySettings()
      manopoleIngrandite.textScale = 1.4
      manopoleIngrandite.typeface = .openDyslexic
      let ingrandito = EffettiveImpostazioniAccessibilita(manopoleIngrandite)
      disegna(Campionario(a11y: ingrandito, tema: .chiaro, nomeTema: "Ingrandito 1,4"),
              nome: "mattoncini-ingranditi", larghezza: 1100, altezza: 900)

      print("")
      print("── Il riquadro dell'aggiornamento, nei suoi quattro stati ──")
      // Questo riquadro compare solo quando qualcuno pubblica una versione
      // nuova: senza queste immagini nessuno lo guarderebbe mai prima che lo
      // guardi una famiglia. Gli stati sono quelli che contano — pronto,
      // mentre scarica, quando c'è una sessione in corso, quando l'app sta
      // dove non si può scrivere.
      let chiara = Palette.resolve(theme: .chiaro, vision: .standard, system: .light)
      let finta = Updates.Release(
        version: "0.6.0",
        pageURL: URL(string: "https://github.com/FightTheStroke/MirrorScopio/releases")!,
        notes: "La lettura ad alta voce sente meglio le parole corte, e le impostazioni si aprono dove le avevi lasciate.",
        packageURL: URL(string: "https://github.com/x/y/releases/download/v0.6.0/MirrorScopio-0.6.0.zip")!,
        packageSize: 2_000_000)
      let statiRiquadro: [(String, Installazione.Fase, Bool, Bool)] = [
        ("pronto", .ferma, false, true),
        ("scarico", .scarico(0.42), false, true),
        ("sessione-in-corso", .ferma, true, true),
        ("cartella-non-scrivibile", .ferma, false, false),
      ]
      for (nome, fase, inSessione, scrivibile) in statiRiquadro {
        disegna(
          RiquadroAggiornamento(release: finta, fase: fase,
                                sessioneInCorso: inSessione,
                                puòInstallare: scrivibile,
                                a11y: EffettiveImpostazioniAccessibilita())
            .padding(Metrica.spazio)
            .frame(width: 720, alignment: .leading)
            .background(chiara.background)
            .environment(\.palette, chiara),
          nome: "aggiornamento-\(nome)", larghezza: 720, altezza: 300)
      }
      // Anche ingrandito e con il carattere per la dislessia: è la prova che
      // il riquadro regge il testo grande senza tagliare le parole.
      var manopoleGrandi = A11ySettings()
      manopoleGrandi.textScale = 2.0
      manopoleGrandi.typeface = .openDyslexic
      let grande = EffettiveImpostazioniAccessibilita(manopoleGrandi)
      let riquadroGrande = RiquadroAggiornamento(
        release: finta, fase: .verifico, sessioneInCorso: false,
        puòInstallare: true, a11y: grande)
        .padding(Metrica.spazio)
        .frame(width: 900, alignment: .leading)
        .background(chiara.background)
        .environment(\.palette, chiara)
      disegna(riquadroGrande, nome: "aggiornamento-ingrandito", larghezza: 900,
              altezza: altezzaNaturale(riquadroGrande, larghezza: 900))

      // I tredici giochi premio. È l'unico modo di *guardarli* senza aprire
      // l'app: ognuno si fotografa a metà partita, con il campo pieno.
      let manopoleGioco = A11ySettings()
      let perGiocare = EffettiveImpostazioniAccessibilita(manopoleGioco)
      let paletteGioco = Palette.resolve(theme: perGiocare.theme,
                                         vision: perGiocare.colorVision,
                                         system: .light)
      disegna(StaffettaView(a11y: perGiocare, onClose: {}, perFotografia: true),
              nome: "gioco-sala", larghezza: 900, altezza: 1900)
      disegna(
        GiocoCorsa(a11y: perGiocare, difficolta: .media, onClose: {}, perFotografia: true)
          .environment(\.palette, paletteGioco),
        nome: "gioco-corsa", larghezza: 900, altezza: 900)

      var manopoleCorsaScura = A11ySettings()
      manopoleCorsaScura.theme = .scuro
      let corsaScura = EffettiveImpostazioniAccessibilita(manopoleCorsaScura)
      let paletteCorsaScura = Palette.resolve(theme: .scuro, vision: .standard, system: .dark)
      disegna(
        GiocoCorsa(a11y: corsaScura, difficolta: .media, onClose: {}, perFotografia: true)
          .environment(\.palette, paletteCorsaScura),
        nome: "gioco-corsa-scuro", larghezza: 900, altezza: 900)

      var manopoleCorsaCalma = A11ySettings()
      manopoleCorsaCalma.theme = .altoContrasto
      manopoleCorsaCalma.calmMode = true
      manopoleCorsaCalma.reducedMotion = true
      manopoleCorsaCalma.hideScore = true
      let corsaCalma = EffettiveImpostazioniAccessibilita(manopoleCorsaCalma)
      let paletteCorsaCalma = Palette.resolve(
        theme: .altoContrasto, vision: .monocromia, system: .dark)
      disegna(
        GiocoCorsa(a11y: corsaCalma, difficolta: .media, onClose: {}, perFotografia: true)
          .environment(\.palette, paletteCorsaCalma),
        nome: "gioco-corsa-calma", larghezza: 900, altezza: 900)

      disegna(GiocoTraversata(a11y: perGiocare, difficolta: .media, onClose: {}, perFotografia: true),
              nome: "gioco-traversata", larghezza: 900, altezza: 660)
      disegna(GiocoBolle(a11y: perGiocare, difficolta: .media, onClose: {}, perFotografia: true),
              nome: "gioco-bolle", larghezza: 900, altezza: 660)
      disegna(GiocoMuro(a11y: perGiocare, difficolta: .media, onClose: {}, perFotografia: true),
              nome: "gioco-muro", larghezza: 900, altezza: 660)
      disegna(GiocoGrotta(a11y: perGiocare, difficolta: .media, onClose: {}, perFotografia: true),
              nome: "gioco-grotta", larghezza: 900, altezza: 660)
      disegna(GiocoArrampicata(a11y: perGiocare, difficolta: .media, onClose: {}, perFotografia: true),
              nome: "gioco-arrampicata", larghezza: 900, altezza: 660)
      disegna(GiocoScherma(a11y: perGiocare, difficolta: .media, onClose: {}, perFotografia: true),
              nome: "gioco-scherma", larghezza: 900, altezza: 660)
      disegna(GiocoVela(a11y: perGiocare, difficolta: .media, onClose: {}, perFotografia: true),
              nome: "gioco-vela", larghezza: 900, altezza: 660)
      disegna(GiocoTriciclo(a11y: perGiocare, difficolta: .media, onClose: {}, perFotografia: true),
              nome: "gioco-triciclo", larghezza: 900, altezza: 660)
      disegna(GiocoSkate(a11y: perGiocare, difficolta: .media, onClose: {}, perFotografia: true),
              nome: "gioco-skate", larghezza: 900, altezza: 660)
      disegna(GiocoBeach(a11y: perGiocare, difficolta: .media, onClose: {}, perFotografia: true),
              nome: "gioco-beach", larghezza: 900, altezza: 660)
      disegna(GiocoBoxe(a11y: perGiocare, difficolta: .media, onClose: {}, perFotografia: true),
              nome: "gioco-boxe", larghezza: 900, altezza: 660)
      disegna(GiocoHipHop(a11y: perGiocare, difficolta: .media, onClose: {}, perFotografia: true),
              nome: "gioco-hiphop", larghezza: 900, altezza: 660)

      // La pagina «I giochi» delle impostazioni: l'elenco da cui l'adulto
      // apre un gioco preciso senza passare dalla sala.
      let elenco = ElencoGiochi(a11y: perGiocare, apri: { _ in })
        .padding(Metrica.spazio)
        .background(Palette.resolve(theme: .chiaro, vision: .standard, system: .light).background)
      disegna(elenco, nome: "impostazioni-giochi", larghezza: 900,
              altezza: max(620, altezzaNaturale(elenco, larghezza: 900)))

      print("")
      print("Le immagini sono in build/schermate/.")
    }
  }
}
