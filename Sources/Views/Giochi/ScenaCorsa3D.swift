import AppKit
import SceneKit
import SwiftUI

@MainActor
final class ScenaCorsa3D {
  let scena = SCNScene()
  let camera = SCNNode()

  private let colori: PaletteArena
  private let dinamici = SCNNode()
  private let eroe: PersonaggioCorsa3D
  private var modelliOstacolo: [SCNNode] = []
  private var modelloGemma = SCNNode()
  private var modelloCompagno = SCNNode()
  private var modelloTraguardo = SCNNode()

  init(colori: PaletteArena) {
    self.colori = colori
    self.eroe = ModelliCorsa3D.personaggio(
      colore: colori.eroe, dettaglio: colori.segno, scala: 1.0)
    costruisciArena()
    preparaModelliDinamici()
    scena.rootNode.addChildNode(dinamici)
    scena.rootNode.addChildNode(eroe.nodo)
  }

  func aggiorna(_ stato: StatoCampoCorsa3D) {
    SCNTransaction.begin()
    SCNTransaction.animationDuration = 0
    SCNTransaction.disableActions = true
    dinamici.childNodes.forEach { $0.removeFromParentNode() }

    let progresso = min(1, max(0, (stato.xEroe - Corsa.partenza)
                                  / (Corsa.traguardo - Corsa.partenza)))
    aggiungiTraguardo(progresso: progresso)
    aggiungiOstacoli(stato)
    aggiungiGemme(stato)
    aggiungiCompagni(stato)
    aggiornaEroe(stato)
    SCNTransaction.commit()
  }

  static func fotografia(stato: StatoCampoCorsa3D, colori: PaletteArena,
                         dimensione: CGSize) -> NSImage {
    let mondo = ScenaCorsa3D(colori: colori)
    mondo.aggiorna(stato)
    let renderer = SCNRenderer(device: nil, options: nil)
    renderer.scene = mondo.scena
    renderer.pointOfView = mondo.camera
    renderer.autoenablesDefaultLighting = false
    return renderer.snapshot(atTime: 0, with: dimensione,
                             antialiasingMode: .multisampling4X)
  }

  private func costruisciArena() {
    scena.background.contents = sfondoSfumato()
    scena.fogColor = NSColor(colori.cieloBasso)
    scena.fogStartDistance = 28
    scena.fogEndDistance = 58

    let bersaglio = SCNNode()
    bersaglio.position = SCNVector3(0, 1.0, -8)
    scena.rootNode.addChildNode(bersaglio)
    camera.camera = SCNCamera()
    camera.camera?.fieldOfView = 54
    camera.camera?.zNear = 0.1
    camera.camera?.zFar = 100
    camera.position = SCNVector3(0, 7.2, 14.5)
    let guarda = SCNLookAtConstraint(target: bersaglio)
    guarda.isGimbalLockEnabled = true
    camera.constraints = [guarda]
    scena.rootNode.addChildNode(camera)

    let ambiente = SCNNode()
    ambiente.light = SCNLight()
    ambiente.light?.type = .ambient
    ambiente.light?.color = NSColor.white.withAlphaComponent(
      colori.altoContrasto ? 0.78 : 0.46)
    scena.rootNode.addChildNode(ambiente)

    let sole = SCNNode()
    sole.light = SCNLight()
    sole.light?.type = .directional
    sole.light?.color = NSColor.white
    sole.light?.intensity = colori.altoContrasto ? 1050 : 1450
    sole.light?.castsShadow = true
    sole.light?.shadowMode = .forward
    sole.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
    sole.light?.shadowSampleCount = 24
    sole.light?.shadowRadius = 2
    sole.eulerAngles = SCNVector3(-0.88, -0.52, -0.18)
    scena.rootNode.addChildNode(sole)

    let terreno = ModelliCorsa3D.scatola(
      larghezza: 38, altezza: 0.8, profondita: 44, raggio: 0.4,
      colore: colori.terra)
    terreno.position = SCNVector3(0, -0.68, -8)
    scena.rootNode.addChildNode(terreno)

    let pista = ModelliCorsa3D.scatola(
      larghezza: 9.4, altezza: 0.48, profondita: 34, raggio: 0.24,
      colore: colori.pista)
    pista.position = SCNVector3(0, -0.18, -7)
    scena.rootNode.addChildNode(pista)

    for x in [-1.55, 1.55] {
      let linea = ModelliCorsa3D.scatola(
        larghezza: 0.09, altezza: 0.04, profondita: 33, raggio: 0.02,
        colore: colori.segno)
      linea.position = SCNVector3(x, 0.09, -7)
      scena.rootNode.addChildNode(linea)
    }

    aggiungiTribune()
    aggiungiMontagne()
    aggiungiPortaliLaterali()
  }

  private func aggiungiTribune() {
    for lato in [-1.0, 1.0] {
      for gradino in 0..<3 {
        let tribuna = ModelliCorsa3D.scatola(
          larghezza: 5.0, altezza: 0.7 + Double(gradino) * 0.65,
          profondita: 28, raggio: 0.18,
          colore: gradino.isMultiple(of: 2) ? colori.terraLuce : colori.terra)
        tribuna.position = SCNVector3(
          lato * (7.3 + Double(gradino) * 1.4),
          -0.2 + Double(gradino) * 0.32, -8)
        scena.rootNode.addChildNode(tribuna)
      }

      for fila in 0..<4 {
        for posto in 0..<7 {
          let spettatore = ModelliCorsa3D.sfera(
            raggio: 0.20,
            colore: (fila + posto).isMultiple(of: 3)
              ? colori.ostacolo : colori.squadra,
            segmenti: 8)
          spettatore.position = SCNVector3(
            lato * (6.2 + Double(fila) * 0.65),
            0.35 + Double(fila) * 0.45,
            3.5 - Double(posto) * 4.1)
          scena.rootNode.addChildNode(spettatore)
        }
      }
    }
  }

  private func aggiungiMontagne() {
    for (x, altezza, z) in [(-13.0, 9.0, -31.0), (-4.0, 12.0, -38.0),
                            (8.0, 10.0, -34.0), (16.0, 8.0, -30.0)] {
      let forma = SCNPyramid(width: altezza, height: altezza, length: altezza * 0.8)
      forma.materials = [ModelliCorsa3D.materiale(colori.terraLuce)]
      let montagna = SCNNode(geometry: forma)
      montagna.position = SCNVector3(x, altezza / 2 - 0.5, z)
      scena.rootNode.addChildNode(montagna)
    }

    let sole = ModelliCorsa3D.sfera(
      raggio: 3.8, colore: colori.premio, emissione: colori.premio, segmenti: 24)
    sole.position = SCNVector3(10, 10, -42)
    scena.rootNode.addChildNode(sole)
  }

  private func aggiungiPortaliLaterali() {
    for lato in [-1.0, 1.0] {
      for z in stride(from: 3.0, through: -23.0, by: -5.2) {
        let palo = ModelliCorsa3D.scatola(
          larghezza: 0.32, altezza: 3.2, profondita: 0.32, raggio: 0.08,
          colore: colori.segno)
        palo.position = SCNVector3(lato * 5.2, 1.6, z)
        scena.rootNode.addChildNode(palo)
        let bandiera = ModelliCorsa3D.scatola(
          larghezza: 1.5, altezza: 0.9, profondita: 0.10, raggio: 0.04,
          colore: z.truncatingRemainder(dividingBy: 10.4) == 3
            ? colori.ostacolo : colori.pista)
        bandiera.position = SCNVector3(lato * 5.2, 2.5, z)
        scena.rootNode.addChildNode(bandiera)
      }
    }
  }

  private func preparaModelliDinamici() {
    modelliOstacolo = (0..<4).map {
      ModelliCorsa3D.ostacolo(
        livello: $0, colore: colori.ostacolo, dettaglio: colori.segno)
    }
    modelloGemma = ModelliCorsa3D.gemma(
      colore: colori.premio, dettaglio: colori.pista)
    modelloGemma.scale = SCNVector3(1.25, 1.25, 1.25)

    let compagno = ModelliCorsa3D.personaggio(
      colore: colori.squadra, dettaglio: colori.segno, scala: 0.72)
    compagno.braccioSinistro.eulerAngles.z = -1.05
    compagno.braccioDestro.eulerAngles.z = 1.05
    modelloCompagno = compagno.nodo

    for x in [-4.0, 4.0] {
      let palo = ModelliCorsa3D.scatola(
        larghezza: 0.42, altezza: 4.0, profondita: 0.42, raggio: 0.10,
        colore: colori.segno)
      palo.position = SCNVector3(x, 2.0, 0)
      modelloTraguardo.addChildNode(palo)
    }
    let arco = ModelliCorsa3D.scatola(
      larghezza: 8.4, altezza: 0.72, profondita: 0.72, raggio: 0.18,
      colore: colori.ostacolo)
    arco.position = SCNVector3(0, 4.0, 0)
    modelloTraguardo.addChildNode(arco)
  }

  private func aggiungiTraguardo(progresso: Double) {
    let z = 4.3 - (1 - progresso) * 29
    let traguardo = modelloTraguardo.clone()
    traguardo.position.z = z
    dinamici.addChildNode(traguardo)
  }

  private func aggiungiOstacoli(_ stato: StatoCampoCorsa3D) {
    for ostacolo in stato.ostacoli {
      let distanza = ostacolo.x - stato.xEroe
      guard distanza > -24, distanza < 230 else { continue }
      let nodo = modelliOstacolo[min(stato.livello, modelliOstacolo.count - 1)].clone()
      nodo.position = SCNVector3(0, 0.10, 4.0 - distanza * 0.125)
      dinamici.addChildNode(nodo)
    }
  }

  private func aggiungiGemme(_ stato: StatoCampoCorsa3D) {
    for gemma in stato.gemme {
      let distanza = gemma - stato.xEroe
      guard distanza > -20, distanza < 230 else { continue }
      let nodo = modelloGemma.clone()
      nodo.position = SCNVector3(0, 2.0, 4.0 - distanza * 0.125)
      nodo.eulerAngles.y = CGFloat(stato.fermo ? 0 : Double(stato.battiti) * 0.08)
      dinamici.addChildNode(nodo)
    }
  }

  private func aggiungiCompagni(_ stato: StatoCampoCorsa3D) {
    for i in 0..<stato.squadra {
      let compagno = modelloCompagno.clone()
      compagno.position = stato.fase == .fine
        ? SCNVector3(-2.2 + Double(i) * 1.45, 0.12, 3.2)
        : SCNVector3(i.isMultiple(of: 2) ? -5.9 : 5.9,
                     0.35, 2.5 - Double(i) * 4.0)
      dinamici.addChildNode(compagno)
    }
  }

  private func aggiornaEroe(_ stato: StatoCampoCorsa3D) {
    let altezza = stato.salto / 26 * 2.2
    let avanzamentoSalita = stato.fase == .salita ? stato.salita * 7.0 : 0
    eroe.nodo.position = SCNVector3(0, 0.12 + altezza, 4.0 - avanzamentoSalita)
    eroe.nodo.eulerAngles.y = 0

    let passo = stato.fermo ? 0 : ((stato.battiti / 5).isMultiple(of: 2) ? 1.0 : -1.0)
    eroe.gambaSinistra.eulerAngles.x = CGFloat(0.48 * passo)
    eroe.gambaDestra.eulerAngles.x = CGFloat(-0.48 * passo)
    eroe.braccioSinistro.eulerAngles.x = CGFloat(-0.58 * passo)
    eroe.braccioDestro.eulerAngles.x = CGFloat(0.58 * passo)
    if stato.fase == .fine {
      eroe.braccioSinistro.eulerAngles.z = -1.05
      eroe.braccioDestro.eulerAngles.z = 1.05
    } else {
      eroe.braccioSinistro.eulerAngles.z = 0.60
      eroe.braccioDestro.eulerAngles.z = -0.60
    }
  }

  private func sfondoSfumato() -> NSImage {
    let dimensione = NSSize(width: 16, height: 16)
    let immagine = NSImage(size: dimensione)
    immagine.lockFocus()
    NSGradient(starting: NSColor(colori.cieloAlto),
               ending: NSColor(colori.cieloBasso))?
      .draw(in: NSRect(origin: .zero, size: dimensione), angle: -90)
    immagine.unlockFocus()
    return immagine
  }
}
