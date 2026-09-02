import AppKit
import SceneKit
import SwiftUI

struct PersonaggioCorsa3D {
  let nodo: SCNNode
  let braccioSinistro: SCNNode
  let braccioDestro: SCNNode
  let gambaSinistra: SCNNode
  let gambaDestra: SCNNode
}

enum ModelliCorsa3D {
  static let angoloBracciaFesta: CGFloat = 2.10

  static func materiale(_ colore: Color, emissione: Color? = nil) -> SCNMaterial {
    let materiale = SCNMaterial()
    materiale.lightingModel = .physicallyBased
    materiale.diffuse.contents = NSColor(colore)
    materiale.roughness.contents = 0.48
    materiale.metalness.contents = 0.08
    if let emissione {
      materiale.emission.contents = NSColor(emissione)
      materiale.emission.intensity = 0.35
    }
    return materiale
  }

  static func scatola(larghezza: Double, altezza: Double, profondita: Double,
                      raggio: Double, colore: Color,
                      proiettaOmbra: Bool = true) -> SCNNode {
    let forma = SCNBox(width: larghezza, height: altezza, length: profondita,
                       chamferRadius: raggio)
    forma.materials = [materiale(colore)]
    let nodo = SCNNode(geometry: forma)
    nodo.castsShadow = proiettaOmbra
    return nodo
  }

  static func sfera(raggio: Double, colore: Color, emissione: Color? = nil,
                    segmenti: Int = 16, proiettaOmbra: Bool = true) -> SCNNode {
    let forma = SCNSphere(radius: raggio)
    forma.segmentCount = segmenti
    forma.materials = [materiale(colore, emissione: emissione)]
    let nodo = SCNNode(geometry: forma)
    nodo.castsShadow = proiettaOmbra
    return nodo
  }

  static func capsula(raggio: Double, altezza: Double, colore: Color,
                      proiettaOmbra: Bool = true) -> SCNNode {
    let forma = SCNCapsule(capRadius: raggio, height: altezza)
    forma.radialSegmentCount = 10
    forma.capSegmentCount = 4
    forma.materials = [materiale(colore)]
    let nodo = SCNNode(geometry: forma)
    nodo.castsShadow = proiettaOmbra
    return nodo
  }

  static func personaggio(colore: Color, dettaglio: Color,
                          scala: Double = 1) -> PersonaggioCorsa3D {
    let radice = SCNNode()
    radice.scale = SCNVector3(scala, scala, scala)

    let torso = scatola(larghezza: 0.92, altezza: 1.35, profondita: 0.58,
                        raggio: 0.20, colore: colore)
    torso.position = SCNVector3(0, 1.35, 0)
    radice.addChildNode(torso)

    let pettorale = scatola(larghezza: 0.72, altezza: 0.38, profondita: 0.10,
                            raggio: 0.08, colore: dettaglio)
    pettorale.position = SCNVector3(0, 1.48, 0.34)
    radice.addChildNode(pettorale)

    let testa = sfera(raggio: 0.42, colore: colore, segmenti: 14)
    testa.position = SCNVector3(0, 2.38, 0)
    radice.addChildNode(testa)

    let visiera = scatola(larghezza: 0.66, altezza: 0.16, profondita: 0.14,
                          raggio: 0.07, colore: dettaglio)
    visiera.position = SCNVector3(0, 2.43, 0.37)
    radice.addChildNode(visiera)

    let braccioSinistro = artoSuperiore(
      nome: "braccioSinistro", x: -0.48, rotazione: -0.60,
      colore: colore, dettaglio: dettaglio)
    radice.addChildNode(braccioSinistro)
    let braccioDestro = artoSuperiore(
      nome: "braccioDestro", x: 0.48, rotazione: 0.60,
      colore: colore, dettaglio: dettaglio)
    radice.addChildNode(braccioDestro)

    let gambaSinistra = capsula(raggio: 0.17, altezza: 1.25, colore: dettaglio)
    gambaSinistra.name = "gambaSinistra"
    gambaSinistra.position = SCNVector3(-0.28, 0.42, 0)
    gambaSinistra.eulerAngles.z = -0.18
    radice.addChildNode(gambaSinistra)
    let gambaDestra = capsula(raggio: 0.17, altezza: 1.25, colore: dettaglio)
    gambaDestra.name = "gambaDestra"
    gambaDestra.position = SCNVector3(0.28, 0.42, 0)
    gambaDestra.eulerAngles.z = 0.18
    radice.addChildNode(gambaDestra)

    for x in [-0.35, 0.35] {
      let scarpa = scatola(larghezza: 0.50, altezza: 0.22, profondita: 0.82,
                           raggio: 0.10, colore: dettaglio)
      scarpa.position = SCNVector3(x, -0.16, 0.20)
      radice.addChildNode(scarpa)
    }

    return PersonaggioCorsa3D(
      nodo: radice,
      braccioSinistro: braccioSinistro,
      braccioDestro: braccioDestro,
      gambaSinistra: gambaSinistra,
      gambaDestra: gambaDestra)
  }

  static func ostacolo(livello: Int, colore: Color, dettaglio: Color) -> SCNNode {
    let radice = SCNNode()
    switch livello {
    case 0:
      for x in [-0.75, 0, 0.75] {
        let onda = SCNTorus(ringRadius: 0.48, pipeRadius: 0.16)
        onda.ringSegmentCount = 12
        onda.pipeSegmentCount = 6
        onda.materials = [materiale(x == 0 ? dettaglio : colore)]
        let nodo = SCNNode(geometry: onda)
        if x == 0 { nodo.name = "contrastoOstacolo" }
        nodo.eulerAngles.x = .pi / 2
        nodo.position = SCNVector3(x, 0.34, 0)
        radice.addChildNode(nodo)
      }
    case 1:
      let sbarra = scatola(larghezza: 3.2, altezza: 0.40, profondita: 0.52,
                           raggio: 0.14, colore: colore)
      sbarra.position = SCNVector3(0, 1.22, 0)
      radice.addChildNode(sbarra)
      for x in [-0.9, 0.9] {
        let banda = scatola(
          larghezza: 0.42, altezza: 0.44, profondita: 0.56, raggio: 0.05,
          colore: dettaglio, proiettaOmbra: false)
        banda.name = "contrastoOstacolo"
        banda.position = SCNVector3(x, 1.22, 0.03)
        radice.addChildNode(banda)
      }
      for x in [-1.25, 1.25] {
        let gamba = scatola(larghezza: 0.28, altezza: 1.10, profondita: 0.34,
                            raggio: 0.10, colore: colore)
        gamba.position = SCNVector3(x, 0.55, 0)
        radice.addChildNode(gamba)
      }
    case 2:
      let roccia = sfera(raggio: 1.15, colore: colore, segmenti: 8)
      roccia.scale = SCNVector3(1.15, 0.82, 1)
      roccia.position.y = 0.82
      radice.addChildNode(roccia)
      let banda = scatola(
        larghezza: 2.25, altezza: 0.24, profondita: 1.10, raggio: 0.06,
        colore: dettaglio, proiettaOmbra: false)
      banda.name = "contrastoOstacolo"
      banda.position = SCNVector3(0, 0.85, 0.95)
      radice.addChildNode(banda)
    default:
      let cassa = scatola(larghezza: 2.2, altezza: 2.4, profondita: 1.2,
                          raggio: 0.22, colore: colore)
      cassa.position.y = 1.2
      radice.addChildNode(cassa)
      for y in [0.75, 1.65] {
        let cono = SCNCone(topRadius: 0.28, bottomRadius: 0.62, height: 0.35)
        cono.materials = [materiale(dettaglio)]
        let nodo = SCNNode(geometry: cono)
        nodo.name = "contrastoOstacolo"
        nodo.eulerAngles.x = .pi / 2
        nodo.position = SCNVector3(0, y, 0.68)
        radice.addChildNode(nodo)
      }
    }
    return radice
  }

  private static func artoSuperiore(nome: String, x: Double, rotazione: CGFloat,
                                    colore: Color, dettaglio: Color) -> SCNNode {
    let perno = SCNNode()
    perno.name = nome
    perno.position = SCNVector3(x, 1.72, 0)
    perno.eulerAngles.z = rotazione

    let braccio = capsula(raggio: 0.14, altezza: 1.05, colore: colore)
    braccio.position.y = -0.45
    perno.addChildNode(braccio)

    let mano = sfera(raggio: 0.18, colore: dettaglio, segmenti: 10)
    mano.position.y = -1.0
    perno.addChildNode(mano)
    return perno
  }

  static func gemma(colore: Color, dettaglio: Color) -> SCNNode {
    let forma = SCNTorus(ringRadius: 0.52, pipeRadius: 0.15)
    forma.ringSegmentCount = 12
    forma.pipeSegmentCount = 6
    forma.materials = [materiale(colore, emissione: colore)]
    let anello = SCNNode(geometry: forma)
    anello.eulerAngles.x = .pi / 2
    let radice = SCNNode()
    radice.addChildNode(anello)
    let centro = sfera(raggio: 0.30, colore: dettaglio, segmenti: 10)
    centro.position.z = 0.03
    radice.addChildNode(centro)
    return radice
  }
}
