import Foundation

enum MisureCampoSport {
  static let proporzione: Double = 1.6
}

struct StatoCorniceSport: Equatable {
  let mostraPunti: Bool
  let azioneAttiva: Bool
  let testoLampo: String?
  let simboloLampo: String?

  init(nascondePunti: Bool, azioneAttiva: Bool, lampo: LampoRetro?) {
    self.mostraPunti = !nascondePunti
    self.azioneAttiva = azioneAttiva
    let visibile = !(nascondePunti && lampo?.soloPunteggio == true)
    if visibile, let lampo {
      let ancora = lampo == .ancora
      self.testoLampo = ancora ? "Ancora" : lampo.testo
      self.simboloLampo = ancora ? ColorVision.wrongSymbol : nil
    } else {
      self.testoLampo = nil
      self.simboloLampo = nil
    }
  }
}
