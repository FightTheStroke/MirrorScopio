import AppKit
import SceneKit

/// Riusa i nodi che cambiano mentre si corre.
///
/// Le geometrie nascono una volta sola; a ogni fotogramma cambiano posizione,
/// rotazione e visibilità. Così il filo principale non crea migliaia di nodi.
@MainActor
final class NodiDinamiciCorsa3D {
  let radice = SCNNode()

  private enum Profondita {
    static let davanti = 4.0
    static let scala = 0.125

    static func posizione(distanza: Double) -> Double {
      davanti - distanza * scala
    }
  }

  private let modelliOstacolo: [SCNNode]
  private let modelloGemma: SCNNode
  private let modelloCompagno: SCNNode
  private let traguardo: SCNNode
  private var ostacoli: [SCNNode] = []
  private var gemme: [SCNNode] = []
  private var compagni: [SCNNode] = []
  private var livelloOstacoli = -1

  init(colori: PaletteArena) {
    radice.name = "dinamici"
    modelliOstacolo = (0..<4).map {
      let nodo = ModelliCorsa3D.ostacolo(
        livello: $0, colore: colori.ostacolo,
        dettaglio: colori.dettaglioOstacolo)
      nodo.name = "ostacolo"
      return nodo
    }

    modelloGemma = ModelliCorsa3D.gemma(
      colore: colori.premio, dettaglio: colori.pista)
    modelloGemma.name = "gemma"
    modelloGemma.scale = SCNVector3(1.25, 1.25, 1.25)

    let compagno = ModelliCorsa3D.personaggio(
      colore: colori.squadra, dettaglio: colori.segno, scala: 0.72)
    compagno.braccioSinistro.eulerAngles.z = -ModelliCorsa3D.angoloBracciaFesta
    compagno.braccioDestro.eulerAngles.z = ModelliCorsa3D.angoloBracciaFesta
    modelloCompagno = compagno.nodo
    modelloCompagno.name = "compagno"

    traguardo = SCNNode()
    traguardo.name = "traguardo"
    for x in [-4.0, 4.0] {
      let palo = ModelliCorsa3D.scatola(
        larghezza: 0.42, altezza: 4.0, profondita: 0.42, raggio: 0.10,
        colore: colori.traguardo)
      palo.position = SCNVector3(x, 2.0, 0)
      traguardo.addChildNode(palo)
      for y in [0.8, 2.0, 3.2] {
        let banda = ModelliCorsa3D.scatola(
          larghezza: 0.48, altezza: 0.34, profondita: 0.48, raggio: 0.04,
          colore: colori.ombra, proiettaOmbra: false)
        banda.name = "contrastoTraguardo"
        banda.position = SCNVector3(x, y, 0.03)
        traguardo.addChildNode(banda)
      }
    }
    let arco = ModelliCorsa3D.scatola(
      larghezza: 8.4, altezza: 0.72, profondita: 0.72, raggio: 0.18,
      colore: colori.traguardo)
    arco.position = SCNVector3(0, 4.0, 0)
    traguardo.addChildNode(arco)
    for x in stride(from: -3.15, through: 3.15, by: 2.1) {
      let scacco = ModelliCorsa3D.scatola(
        larghezza: 1.05, altezza: 0.76, profondita: 0.76, raggio: 0.06,
        colore: colori.ombra, proiettaOmbra: false)
      scacco.name = "contrastoTraguardo"
      scacco.position = SCNVector3(x, 4.0, 0.03)
      traguardo.addChildNode(scacco)
    }
    radice.addChildNode(traguardo)
  }

  func aggiorna(_ stato: StatoCampoCorsa3D) {
    aggiornaTraguardo(stato)
    aggiornaOstacoli(stato)
    aggiornaGemme(stato)
    aggiornaCompagni(stato)
  }

  private func aggiornaTraguardo(_ stato: StatoCampoCorsa3D) {
    let distanza = max(0, Corsa.traguardo - stato.xEroe)
    traguardo.position.z = Profondita.posizione(distanza: distanza)
  }

  private func aggiornaOstacoli(_ stato: StatoCampoCorsa3D) {
    let livello = max(0, min(stato.livello, modelliOstacolo.count - 1))
    if livello != livelloOstacoli {
      ostacoli.forEach { $0.removeFromParentNode() }
      ostacoli.removeAll(keepingCapacity: true)
      livelloOstacoli = livello
    }
    let visibili = stato.ostacoli.compactMap { ostacolo -> (StatoCampoCorsa3D.Ostacolo, Double)? in
      let distanza = ostacolo.x - stato.xEroe
      return distanza > -24 && distanza < 230 ? (ostacolo, distanza) : nil
    }
    while ostacoli.count < visibili.count {
      let nodo = modelliOstacolo[livello].clone()
      radice.addChildNode(nodo)
      ostacoli.append(nodo)
    }
    for indice in ostacoli.indices {
      let nodo = ostacoli[indice]
      guard indice < visibili.count else { nodo.isHidden = true; continue }
      nodo.isHidden = false
      nodo.scale = SCNVector3(1, 1, 1)
      nodo.eulerAngles = SCNVector3Zero
      let (ostacolo, distanza) = visibili[indice]
      switch abs(ostacolo.tipo) % 3 {
      case 1: nodo.scale = SCNVector3(1.20, 0.84, 1)
      case 2:
        nodo.scale = SCNVector3(0.86, 1.18, 1)
        nodo.eulerAngles.y = 0.18
      default: break
      }
      nodo.position = SCNVector3(0, 0.10, Profondita.posizione(distanza: distanza))
    }
  }

  private func aggiornaGemme(_ stato: StatoCampoCorsa3D) {
    let visibili = stato.gemme.compactMap { gemma -> Double? in
      let distanza = gemma - stato.xEroe
      return distanza > -20 && distanza < 230 ? distanza : nil
    }
    while gemme.count < visibili.count {
      let nodo = modelloGemma.clone()
      radice.addChildNode(nodo)
      gemme.append(nodo)
    }
    for indice in gemme.indices {
      let nodo = gemme[indice]
      guard indice < visibili.count else { nodo.isHidden = true; continue }
      nodo.isHidden = false
      let scala = stato.fermo ? 0.98 : 1.25
      nodo.scale = SCNVector3(scala, scala, scala)
      nodo.opacity = stato.fermo ? 0.46 : 1
      // I cloni condividono i materiali di proposito: tutti i gettoni seguono
      // la stessa modalità calma. Un effetto per singolo gettone dovrà copiarli.
      for parte in nodo.childNodes {
        parte.geometry?.materials.forEach {
          $0.emission.intensity = stato.fermo ? 0.04 : 0.35
          $0.diffuse.intensity = stato.fermo ? 0.30 : 1
          $0.specular.contents = stato.fermo ? NSColor.black : nil
          $0.roughness.contents = stato.fermo ? 1.0 : 0.48
          $0.metalness.contents = stato.fermo ? 0.0 : 0.08
          $0.lightingModel = stato.fermo ? .constant : .physicallyBased
        }
      }
      nodo.position = SCNVector3(
        0, 2.0, Profondita.posizione(distanza: visibili[indice]))
      nodo.eulerAngles.y = CGFloat(stato.fermo ? 0 : Double(stato.battiti) * 0.08)
    }
  }

  private func aggiornaCompagni(_ stato: StatoCampoCorsa3D) {
    while compagni.count < stato.squadra {
      let nodo = modelloCompagno.clone()
      radice.addChildNode(nodo)
      compagni.append(nodo)
    }
    for indice in compagni.indices {
      let nodo = compagni[indice]
      guard indice < stato.squadra else { nodo.isHidden = true; continue }
      nodo.isHidden = false
      nodo.position = stato.fase == .fine
        ? SCNVector3(-2.2 + Double(indice) * 1.45, 0.12, 3.2)
        : SCNVector3(indice.isMultiple(of: 2) ? -7.0 : 7.0,
                     0.35, 1.0 - Double(indice) * 4.0)
    }
  }
}
