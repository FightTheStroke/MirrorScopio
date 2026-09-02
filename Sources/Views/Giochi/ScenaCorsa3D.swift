import AppKit
import SceneKit
import SwiftUI

@MainActor
final class ScenaCorsa3D {
  let scena = SCNScene()
  let camera = SCNNode()

  private let colori: PaletteArena
  private let dinamici: NodiDinamiciCorsa3D
  private let eroe: PersonaggioCorsa3D
  private var spettatori: [SCNNode] = []
  private var bandiere: [SCNNode] = []
  private var decorazioniInCalma: Bool?

  init(colori: PaletteArena) {
    self.colori = colori
    self.dinamici = NodiDinamiciCorsa3D(colori: colori)
    self.eroe = ModelliCorsa3D.personaggio(
      colore: colori.eroe, dettaglio: colori.segno, scala: 1.0)
    self.eroe.nodo.name = "eroe"
    costruisciArena()
    scena.rootNode.addChildNode(dinamici.radice)
    scena.rootNode.addChildNode(eroe.nodo)
  }

  func aggiorna(_ stato: StatoCampoCorsa3D) {
    SCNTransaction.begin()
    SCNTransaction.animationDuration = 0
    SCNTransaction.disableActions = true
    dinamici.aggiorna(stato)
    aggiornaDecorazioni(fermo: stato.fermo)
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
                             antialiasingMode: .multisampling2X)
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
    sole.name = "lucePrincipale"
    sole.light = SCNLight()
    sole.light?.type = .directional
    sole.light?.color = NSColor.white
    sole.light?.intensity = colori.altoContrasto ? 1050 : 1450
    sole.light?.castsShadow = true
    sole.light?.shadowMode = .forward
    sole.light?.shadowMapSize = CGSize(width: 1024, height: 1024)
    sole.light?.shadowSampleCount = 8
    sole.light?.shadowRadius = 2
    sole.light?.shadowColor = NSColor(colori.ombra).withAlphaComponent(0.55)
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
    pista.name = "pista"
    if let geometria = pista.geometry {
      let lato = ModelliCorsa3D.materiale(colori.pistaLato)
      let sopra = ModelliCorsa3D.materiale(colori.pista)
      geometria.materials = [lato, lato, lato, lato, sopra, lato]
    }
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
              ? colori.decorazione : colori.terraLuce,
            segmenti: 8, proiettaOmbra: false)
          spettatore.name = "spettatore"
          spettatore.position = SCNVector3(
            lato * (6.2 + Double(fila) * 0.65),
            0.35 + Double(fila) * 0.45,
            3.5 - Double(posto) * 4.1)
          spettatori.append(spettatore)
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
      montagna.castsShadow = false
      montagna.position = SCNVector3(x, altezza / 2 - 0.5, z)
      scena.rootNode.addChildNode(montagna)
    }

    let sole = ModelliCorsa3D.sfera(
      raggio: 3.8, colore: colori.premio, emissione: colori.premio,
      segmenti: 24, proiettaOmbra: false)
    sole.position = SCNVector3(10, 10, -42)
    scena.rootNode.addChildNode(sole)
  }

  private func aggiungiPortaliLaterali() {
    for lato in [-1.0, 1.0] {
      for z in stride(from: -2.2, through: -23.0, by: -5.2) {
        let palo = ModelliCorsa3D.scatola(
          larghezza: 0.24, altezza: 2.6, profondita: 0.24, raggio: 0.06,
          colore: colori.decorazione, proiettaOmbra: false)
        palo.position = SCNVector3(lato * 5.6, 1.3, z)
        scena.rootNode.addChildNode(palo)
        let bandiera = SCNNode()
        bandiera.name = "bandiera"
        let pannello = ModelliCorsa3D.scatola(
          larghezza: 1.15, altezza: 0.62, profondita: 0.10, raggio: 0.04,
          colore: colori.decorazione, proiettaOmbra: false)
        bandiera.addChildNode(pannello)
        for verso in [-1.0, 1.0] {
          let tratto = ModelliCorsa3D.scatola(
            larghezza: 0.48, altezza: 0.10, profondita: 0.13, raggio: 0.03,
            colore: colori.segno, proiettaOmbra: false)
          tratto.position = SCNVector3(0.05, verso * 0.15, 0.08)
          tratto.eulerAngles.z = CGFloat(verso * 0.55)
          bandiera.addChildNode(tratto)
        }
        bandiera.position = SCNVector3(lato * 5.6, 2.15, z)
        bandiere.append(bandiera)
        scena.rootNode.addChildNode(bandiera)
      }
    }
  }

  private func aggiornaDecorazioni(fermo: Bool) {
    guard decorazioniInCalma != fermo else { return }
    decorazioniInCalma = fermo
    for (indice, spettatore) in spettatori.enumerated() {
      spettatore.isHidden = fermo && !indice.isMultiple(of: 4)
    }
    for (indice, bandiera) in bandiere.enumerated() {
      bandiera.isHidden = fermo && !indice.isMultiple(of: 2)
    }
  }

  private func aggiornaEroe(_ stato: StatoCampoCorsa3D) {
    let altezza = stato.fase == .gioco
      ? stato.salto / Corsa.altezzaMassimaSalto * 2.2
      : 0
    let conservaSalita = stato.fase == .salita || stato.fase == .tappaFatta
    let avanzamentoSalita = conservaSalita ? stato.salita * 7.0 : 0
    eroe.nodo.position = SCNVector3(0, 0.12 + altezza, 4.0 - avanzamentoSalita)
    eroe.nodo.eulerAngles.y = 0

    let passo = stato.fermo ? 0.55
      : ((stato.battiti / 5).isMultiple(of: 2) ? 1.0 : -1.0)
    eroe.gambaSinistra.eulerAngles.x = CGFloat(0.48 * passo)
    eroe.gambaDestra.eulerAngles.x = CGFloat(-0.48 * passo)
    eroe.braccioSinistro.eulerAngles.x = CGFloat(-0.58 * passo)
    eroe.braccioDestro.eulerAngles.x = CGFloat(0.58 * passo)
    if stato.fase == .fine {
      eroe.braccioSinistro.eulerAngles.z = -ModelliCorsa3D.angoloBracciaFesta
      eroe.braccioDestro.eulerAngles.z = ModelliCorsa3D.angoloBracciaFesta
    } else if stato.fermo {
      eroe.braccioSinistro.eulerAngles.z = -0.75
      eroe.braccioDestro.eulerAngles.z = 0.45
    } else {
      eroe.braccioSinistro.eulerAngles.z = -0.60
      eroe.braccioDestro.eulerAngles.z = 0.60
    }
  }

  private func sfondoSfumato() -> NSImage {
    let cieloAlto = colori.cieloAlto
    let cieloBasso = colori.cieloBasso
    return NSImage(size: NSSize(width: 128, height: 128), flipped: false) { rect in
      NSGradient(starting: NSColor(cieloAlto),
                 ending: NSColor(cieloBasso))?
        .draw(in: rect, angle: -90)
      return true
    }
  }
}
