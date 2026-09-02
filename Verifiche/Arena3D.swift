import AppKit
import SceneKit
import SwiftUI
import Testing
@testable import MirrorScopio

@Suite("L'arena 3D resta accessibile e visibile")
@MainActor
struct Arena3D {
  private func palette(_ tema: ThemeChoice, _ vista: ColorVision,
                       sistema: ColorScheme = .light) -> (Palette, PaletteArena) {
    let base = Palette.resolve(theme: tema, vision: vista, system: sistema)
    return (base, PaletteArena.resolve(theme: tema, palette: base, vision: vista))
  }

  @Test("In modalità calma il battito non ridisegna la scena")
  func calmaIgnoraIlBattito() {
    let prima = stato(fermo: true, battiti: 1)
    let dopo = stato(fermo: true, battiti: 99)
    #expect(prima == dopo)
    #expect(stato(fermo: false, battiti: 1) != stato(fermo: false, battiti: 2))
  }

  @Test("Riduci movimento non lascia il gioco bloccato a metà salto o salita")
  func movimentoFermatoDuranteLaSalita() {
    var salto: Double? = 0.5
    var salita = 0.4
    let completa = GiocoCorsa.fermaMovimento(
      fase: .salita, salto: &salto, salita: &salita)
    #expect(salto == nil)
    #expect(salita == 1)
    #expect(completa)

    salto = 0.5
    salita = 0
    let continua = GiocoCorsa.fermaMovimento(
      fase: .gioco, salto: &salto, salita: &salita)
    #expect(salto == nil)
    #expect(!continua)
  }

  @Test("Ogni cambiamento del gioco cambia lo stato dell'arena")
  func cambiamentiMateriali() {
    let base = stato()
    var gemma = base
    gemma.gemme = []
    var squadra = base
    squadra.squadra = 2
    var salto = base
    salto.salto = 12
    #expect(base != gemma)
    #expect(base != squadra)
    #expect(base != salto)
  }

  @Test("Gli aggiornamenti non accumulano nodi")
  func aggiornamentiPuliti() throws {
    let (_, colori) = palette(.scuro, .standard, sistema: .dark)
    let mondo = ScenaCorsa3D(colori: colori)
    let dinamici = try #require(
      mondo.scena.rootNode.childNode(withName: "dinamici", recursively: false))

    mondo.aggiorna(stato())
    let iniziali = dinamici.childNodes.count
    let primoOstacolo = try #require(
      dinamici.childNode(withName: "ostacolo", recursively: false))
    for passo in 1...20 {
      var nuovo = stato()
      nuovo.xEroe += Double(passo)
      nuovo.battiti = passo
      mondo.aggiorna(nuovo)
      #expect(dinamici.childNodes.count == iniziali)
      #expect(dinamici.childNode(withName: "ostacolo", recursively: false) === primoOstacolo)
    }
  }

  @Test("Cambiare tappa sostituisce il modello senza accumulare ostacoli")
  func cambioTappaSullaScenaViva() throws {
    let mondo = scena()
    var prima = stato()
    prima.livello = 0
    prima.ostacoli = [.init(x: 150, tipo: 0)]
    mondo.aggiorna(prima)
    let primoNodo = try #require(
      dinamici(mondo).childNode(withName: "ostacolo", recursively: false))

    var dopo = prima
    dopo.livello = 3
    mondo.aggiorna(dopo)
    let secondoNodo = try #require(
      dinamici(mondo).childNode(withName: "ostacolo", recursively: false))
    let ostacoli = dinamici(mondo).childNodes.filter { $0.name == "ostacolo" }
    #expect(ostacoli.count == 1)
    #expect(secondoNodo !== primoNodo)
  }

  @Test("Il traguardo si avvicina con l'avanzamento")
  func traguardoSiAvvicina() throws {
    let mondo = scena()
    var partenza = stato()
    partenza.xEroe = Corsa.partenza
    mondo.aggiorna(partenza)
    let lontano = try #require(
      dinamici(mondo).childNode(withName: "traguardo", recursively: false)).position.z

    var arrivo = partenza
    arrivo.xEroe = Corsa.traguardo
    mondo.aggiorna(arrivo)
    let vicino = try #require(
      dinamici(mondo).childNode(withName: "traguardo", recursively: false)).position.z
    #expect(vicino > lontano)
    #expect(abs(vicino - 4.0) < 0.01)

    var percorso = partenza
    percorso.xEroe = 120
    percorso.ostacoli = [.init(x: 268, tipo: 1)]
    mondo.aggiorna(percorso)
    let traguardo = try #require(
      dinamici(mondo).childNode(withName: "traguardo", recursively: false))
    let ostacolo = try #require(
      dinamici(mondo).childNode(withName: "ostacolo", recursively: false))
    #expect(ostacolo.position.z > traguardo.position.z,
            "un ostacolo prima del traguardo deve apparire più vicino")
  }

  @Test("Gli oggetti fuori dal campo non vengono disegnati")
  func ritaglioDegliOggetti() {
    let mondo = scena()
    var prova = stato()
    prova.ostacoli = [.init(x: 140, tipo: 1), .init(x: 400, tipo: 2)]
    prova.gemme = [150, 420]
    mondo.aggiorna(prova)
    #expect(dinamici(mondo).childNodes.filter { $0.name == "ostacolo" }.count == 1)
    #expect(dinamici(mondo).childNodes.filter { $0.name == "gemma" }.count == 1)
  }

  @Test("Le gemme ruotano solo quando il movimento è acceso")
  func gemmeFermeInCalma() throws {
    let mondo = scena()
    var viva = stato(fermo: false, battiti: 12)
    viva.gemme = [150]
    mondo.aggiorna(viva)
    let rotazione = try #require(
      dinamici(mondo).childNode(withName: "gemma", recursively: false)).eulerAngles.y
    #expect(abs(rotazione) > 0.1)

    var calma = viva
    calma.fermo = true
    mondo.aggiorna(calma)
    let ferma = try #require(
      dinamici(mondo).childNode(withName: "gemma", recursively: false)).eulerAngles.y
    #expect(abs(ferma) < 0.001)
  }

  @Test("In calma premio e decorazioni diventano più discreti")
  func scenaPiùCalma() throws {
    let mondo = scena()
    var viva = stato(fermo: false, battiti: 12)
    viva.gemme = [150]
    mondo.aggiorna(viva)
    let gemma = try #require(
      dinamici(mondo).childNode(withName: "gemma", recursively: false))
    let spettatori = mondo.scena.rootNode.childNodes {
      nodo, _ in nodo.name == "spettatore"
    }
    let bandiere = mondo.scena.rootNode.childNodes {
      nodo, _ in nodo.name == "bandiera"
    }
    let spettatoriVivi = spettatori.filter { !$0.isHidden }.count
    let bandiereVive = bandiere.filter { !$0.isHidden }.count

    var calma = viva
    calma.fermo = true
    mondo.aggiorna(calma)
    let anello = try #require(
      gemma.childNodes.first { $0.geometry is SCNTorus })
    #expect(gemma.opacity <= 0.5)
    #expect(gemma.scale.x < 1)
    #expect((anello.geometry?.firstMaterial?.emission.intensity ?? 1) <= 0.05)
    #expect((anello.geometry?.firstMaterial?.diffuse.intensity ?? 1) <= 0.31)
    #expect(anello.geometry?.firstMaterial?.lightingModel == .constant)
    #expect(spettatori.filter { !$0.isHidden }.count < spettatoriVivi)
    #expect(bandiere.filter { !$0.isHidden }.count < bandiereVive)
  }

  @Test("Il traguardo è a scacchi e ogni ostacolo porta un segno distinto")
  func formeConRuoliDiversi() throws {
    let mondo = scena()
    let traguardo = try #require(
      dinamici(mondo).childNode(withName: "traguardo", recursively: false))
    #expect(traguardo.childNodes.contains { $0.name == "contrastoTraguardo" })

    for livello in 0..<RegoleCorsa.numeroTappe {
      var prova = stato()
      prova.livello = livello
      prova.ostacoli = [.init(x: 150, tipo: 0)]
      mondo.aggiorna(prova)
      let ostacolo = try #require(
        dinamici(mondo).childNode(withName: "ostacolo", recursively: false))
      #expect(
        ostacolo.childNode(withName: "contrastoOstacolo", recursively: true) != nil,
        "l'ostacolo della tappa \(livello + 1) non ha un segno distinto")
    }
  }

  @Test("Il premio è un gettone, non una freccia")
  func formaDelPremio() {
    let (_, colori) = palette(.altoContrasto, .monocromia, sistema: .dark)
    let gemma = ModelliCorsa3D.gemma(
      colore: colori.premio, dettaglio: colori.pista)
    let anelli = gemma.childNodes { nodo, _ in nodo.geometry is SCNTorus }
    let piramidi = gemma.childNodes { nodo, _ in nodo.geometry is SCNPyramid }
    #expect(anelli.count == 1)
    #expect(piramidi.isEmpty)
  }

  @Test("Le bandiere restano dietro il compagno più vicino")
  func compagnoDavantiAlleBandiere() throws {
    let mondo = scena()
    var prova = stato()
    prova.squadra = 1
    mondo.aggiorna(prova)
    let compagno = try #require(
      dinamici(mondo).childNode(withName: "compagno", recursively: false))
    let bandiere = mondo.scena.rootNode.childNodes {
      nodo, _ in nodo.name == "bandiera" && !nodo.isHidden
    }
    #expect(!bandiere.isEmpty)
    #expect(bandiere.allSatisfy { $0.position.z < compagno.position.z })
  }

  @Test("Salto e salita muovono l'eroe sugli assi giusti")
  func saltoESalita() throws {
    let mondo = scena()
    var salto = stato()
    salto.salto = Corsa.altezzaMassimaSalto
    mondo.aggiorna(salto)
    let eroe = try #require(
      mondo.scena.rootNode.childNode(withName: "eroe", recursively: false))
    #expect(eroe.position.y > 2)
    #expect(abs(eroe.position.z - 4) < 0.001)

    var salita = stato()
    salita.fase = .salita
    salita.salita = 1
    mondo.aggiorna(salita)
    #expect(abs(eroe.position.y - 0.12) < 0.001)
    #expect(abs(eroe.position.z + 3) < 0.001)

    var tappaFatta = salita
    tappaFatta.fase = .tappaFatta
    tappaFatta.salto = Corsa.altezzaMassimaSalto
    mondo.aggiorna(tappaFatta)
    #expect(abs(eroe.position.y - 0.12) < 0.001)
    #expect(abs(eroe.position.z + 3) < 0.001)
  }

  @Test("La scena costruisce camera, luce e pista")
  func strutturaStatica() throws {
    let mondo = scena()
    #expect(mondo.camera.camera != nil)
    let luce = try #require(
      mondo.scena.rootNode.childNode(withName: "lucePrincipale", recursively: false))
    #expect(luce.light?.castsShadow == true)
    #expect(luce.light?.shadowMode == .forward)
    let pista = try #require(
      mondo.scena.rootNode.childNode(withName: "pista", recursively: false))
    #expect(pista.geometry?.materials.count == 6)
  }

  @Test("Cambio tema ricostruisce, stesso stato non ridisegna")
  func politicaDiAggiornamento() {
    #expect(PoliticaAggiornamentoScena3D.ricostruisce(
      mondoPresente: false, chiaveAttuale: "", chiaveNuova: "chiaro"))
    #expect(PoliticaAggiornamentoScena3D.ricostruisce(
      mondoPresente: true, chiaveAttuale: "chiaro", chiaveNuova: "scuro"))
    #expect(!PoliticaAggiornamentoScena3D.ricostruisce(
      mondoPresente: true, chiaveAttuale: "scuro", chiaveNuova: "scuro"))
    let s = stato()
    #expect(!PoliticaAggiornamentoScena3D.ridisegna(ultimo: s, nuovo: s))
    #expect(PoliticaAggiornamentoScena3D.ridisegna(ultimo: nil, nuovo: s))
  }

  @Test("Tutti i quattro modelli di ostacolo entrano nella scena",
        arguments: [0, 1, 2, 3])
  func modelliOstacolo(livello: Int) {
    let mondo = scena()
    var prova = stato()
    prova.livello = livello
    prova.ostacoli = [.init(x: 150, tipo: 0)]
    mondo.aggiorna(prova)
    let ostacolo = dinamici(mondo).childNode(withName: "ostacolo", recursively: false)
    #expect(ostacolo != nil)
    #expect(ostacolo?.childNodes.contains { $0.geometry != nil } == true)
  }

  @Test("I tre tipi cambiano davvero la forma dell'ostacolo")
  func tipiOstacolo() throws {
    let mondo = scena()
    var trasformazioni: Set<String> = []
    for tipo in 0...2 {
      var prova = stato()
      prova.livello = 1
      prova.ostacoli = [.init(x: 150, tipo: tipo)]
      mondo.aggiorna(prova)
      let nodo = try #require(
        dinamici(mondo).childNode(withName: "ostacolo", recursively: false))
      trasformazioni.insert(
        "\(nodo.scale.x)-\(nodo.scale.y)-\(nodo.eulerAngles.y)")
    }
    #expect(trasformazioni.count == 3)
  }

  @Test("Il corpo corre, si ferma in calma e festeggia all'arrivo")
  func poseDellEroe() throws {
    let mondo = scena()
    var passoUno = stato(fermo: false, battiti: 0)
    mondo.aggiorna(passoUno)
    let eroe = try #require(
      mondo.scena.rootNode.childNode(withName: "eroe", recursively: false))
    let gamba = try #require(
      eroe.childNode(withName: "gambaSinistra", recursively: true))
    let braccioSinistro = try #require(
      eroe.childNode(withName: "braccioSinistro", recursively: true))
    let braccioDestro = try #require(
      eroe.childNode(withName: "braccioDestro", recursively: true))
    let primoAngolo = gamba.eulerAngles.x

    passoUno.battiti = 5
    mondo.aggiorna(passoUno)
    #expect(gamba.eulerAngles.x == -primoAngolo)

    var calma = passoUno
    calma.fermo = true
    mondo.aggiorna(calma)
    let posaCalma = gamba.eulerAngles.x
    #expect(abs(posaCalma) > 0.1)
    calma.battiti = 99
    mondo.aggiorna(calma)
    #expect(gamba.eulerAngles.x == posaCalma)

    var arrivo = calma
    arrivo.fase = .fine
    mondo.aggiorna(arrivo)
    #expect(abs(braccioSinistro.eulerAngles.z + ModelliCorsa3D.angoloBracciaFesta) < 0.001)
    #expect(abs(braccioDestro.eulerAngles.z - ModelliCorsa3D.angoloBracciaFesta) < 0.001)
  }

  @Test("All'arrivo i compagni sono sulla pista", arguments: [1, 2, 3, 4])
  func compagniAllArrivo(quanti: Int) throws {
    let (_, colori) = palette(.altoContrasto, .monocromia, sistema: .dark)
    let mondo = ScenaCorsa3D(colori: colori)
    var fine = stato()
    fine.fase = .fine
    fine.squadra = quanti
    mondo.aggiorna(fine)

    let dinamici = try #require(
      mondo.scena.rootNode.childNode(withName: "dinamici", recursively: false))
    let compagni = dinamici.childNodes.filter { $0.name == "compagno" }
    #expect(compagni.count == quanti)
    #expect(compagni.allSatisfy { abs($0.position.x) < 4.7 })
  }

  @Test("Rigiocare nasconde i compagni della partita precedente")
  func rigiocaSenzaCompagniResidui() {
    let mondo = scena()
    var fine = stato()
    fine.fase = .fine
    fine.squadra = 4
    mondo.aggiorna(fine)

    var rigioca = fine
    rigioca.fase = .titolo
    rigioca.squadra = 0
    mondo.aggiorna(rigioca)
    let compagni = dinamici(mondo).childNodes.filter { $0.name == "compagno" }
    #expect(compagni.count == 4)
    #expect(compagni.allSatisfy { $0.isHidden })
  }

  @Test("La fotografia 3D ha la misura chiesta e non è vuota")
  func fotografiaNonVuota() throws {
    let (_, colori) = palette(.chiaro, .standard)
    let immagine = ScenaCorsa3D.fotografia(
      stato: stato(), colori: colori, dimensione: CGSize(width: 320, height: 200))
    let tiff = try #require(immagine.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiff))
    #expect(bitmap.pixelsWide == 320)
    #expect(bitmap.pixelsHigh == 200)

    var coloriDiversi: Set<String> = []
    for x in stride(from: 8, to: bitmap.pixelsWide, by: 24) {
      for y in stride(from: 8, to: bitmap.pixelsHigh, by: 24) {
        guard let colore = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
        coloriDiversi.insert(String(format: "%.2f-%.2f-%.2f",
                                    colore.redComponent,
                                    colore.greenComponent,
                                    colore.blueComponent))
      }
    }
    #expect(coloriDiversi.count >= 12,
            "la fotografia ha solo \(coloriDiversi.count) colori: la scena 3D potrebbe essere vuota")
  }

  @Test("Chiudere il gioco libera tutta la scena 3D")
  func scenaLiberataAllaChiusura() {
    weak var riferimento: ScenaCorsa3D?
    autoreleasepool {
      let mondo = scena()
      riferimento = mondo
      #expect(riferimento != nil)
    }
    #expect(riferimento == nil,
            "l'immagine di sfondo trattiene la scena dopo la chiusura")
  }

  private func stato(fermo: Bool = false, battiti: Int = 12) -> StatoCampoCorsa3D {
    StatoCampoCorsa3D(
      fase: .gioco,
      livello: 1,
      xEroe: 120,
      squadra: 1,
      salto: 0,
      salita: 0,
      ostacoli: [.init(x: 186, tipo: 1), .init(x: 268, tipo: 2)],
      gemme: [226],
      battiti: battiti,
      fermo: fermo)
  }

  private func scena() -> ScenaCorsa3D {
    let (_, colori) = palette(.scuro, .standard, sistema: .dark)
    return ScenaCorsa3D(colori: colori)
  }

  private func dinamici(_ mondo: ScenaCorsa3D) -> SCNNode {
    mondo.scena.rootNode.childNode(withName: "dinamici", recursively: false) ?? SCNNode()
  }

}
