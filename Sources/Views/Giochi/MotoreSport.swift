import SwiftUI
import Combine

/// La cornice moderna dei giochi FightCamp.
///
/// Il campo resta il posto in cui si gioca; titolo, stato e comando sono testo
/// vero, così seguono tema, carattere, ingrandimento e VoiceOver dell'app.
struct CorniceSport<Campo: View>: View {
  @Environment(\.palette) private var palette

  var a11y: EffettiveImpostazioniAccessibilita
  var titolo: String
  var sottotitolo: String
  var punti: Int
  var statoDestra: String
  var frase: String
  var invito: String
  var etichettaVoce: String
  var lampo: LampoRetro?
  var azioneAttiva: Bool
  var onPremi: () -> Void
  var onBattito: () -> Void
  var onClose: () -> Void
  var campo: Campo
  var perFotografia: Bool

  private let battito = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

  private var stato: StatoCorniceSport {
    StatoCorniceSport(
      nascondePunti: a11y.hideScore, azioneAttiva: azioneAttiva, lampo: lampo)
  }

  init(a11y: EffettiveImpostazioniAccessibilita,
       titolo: String,
       sottotitolo: String,
       punti: Int,
       statoDestra: String,
       frase: String,
       invito: String,
       etichettaVoce: String,
       lampo: LampoRetro?,
       azioneAttiva: Bool = true,
       onPremi: @escaping () -> Void,
       onBattito: @escaping () -> Void,
       onClose: @escaping () -> Void,
       campo: Campo,
       perFotografia: Bool = false) {
    self.a11y = a11y
    self.titolo = titolo
    self.sottotitolo = sottotitolo
    self.punti = punti
    self.statoDestra = statoDestra
    self.frase = frase
    self.invito = invito
    self.etichettaVoce = etichettaVoce
    self.lampo = lampo
    self.azioneAttiva = azioneAttiva
    self.onPremi = onPremi
    self.onBattito = onBattito
    self.onClose = onClose
    self.campo = campo
    self.perFotografia = perFotografia
  }

  var body: some View {
    ZStack {
      palette.background.ignoresSafeArea()

      if perFotografia {
        contenuto
          .padding(a11y.size(Metrica.spazioPiccolo))
          .padding(.top, a11y.size(Metrica.spazioGrande + Metrica.spazioLargo))
      } else {
        ScrollView {
          contenuto
            .frame(maxWidth: .infinity, minHeight: a11y.size(500))
            .padding(a11y.size(Metrica.spazioPiccolo))
            .padding(.top, a11y.size(Metrica.spazioGrande + Metrica.spazioLargo))
        }
        .scrollIndicators(.automatic)
      }

      VStack {
        HStack {
          Spacer()
          PulsanteChiudi(a11y: a11y, cosa: "il gioco", action: onClose)
        }
        .padding(.horizontal, a11y.size(Metrica.spazioMedio))
        .padding(.top, a11y.size(Metrica.spazioPiccolo))
        Spacer()
      }
    }
    .onReceive(battito) { _ in onBattito() }
  }

  private var contenuto: some View {
    VStack(spacing: a11y.size(Metrica.spazioMedio)) {
      ZStack {
        Button(action: premiSeDisponibile) {
          ZStack {
            RoundedRectangle(cornerRadius: a11y.size(Metrica.raggioGrande))
              .fill(palette.surface)
            campo
          }
          .aspectRatio(MisureCampoSport.proporzione, contentMode: .fit)
          .frame(maxWidth: a11y.size(900))
          .fixedSize(horizontal: false, vertical: true)
          .layoutPriority(1)
          .clipShape(RoundedRectangle(cornerRadius: a11y.size(Metrica.raggioGrande)))
          .overlay {
            RoundedRectangle(cornerRadius: a11y.size(Metrica.raggioGrande))
              .strokeBorder(palette.muted, lineWidth: a11y.theme == .altoContrasto ? 3 : 2)
          }
          .contentShape(RoundedRectangle(cornerRadius: a11y.size(Metrica.raggioGrande)))
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)

        VStack {
          barra
          Spacer()
        }
        .padding(a11y.size(Metrica.spazioMedio))
        .allowsHitTesting(false)

        scrittaLampo
          .allowsHitTesting(false)
      }

      Text(frase)
        .font(a11y.font(.corpo))
        .foregroundStyle(palette.muted)
        .frame(maxWidth: a11y.size(640), minHeight: a11y.size(72))
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.center)

      Button(action: premiSeDisponibile) {
        VStack(spacing: a11y.size(Metrica.filo)) {
          Text(invito)
            .font(a11y.font(.guida, .bold))
          if stato.azioneAttiva {
            Text("Spazio o Invio")
              .font(a11y.font(.nota, .semibold))
          }
        }
          .padding(.horizontal, a11y.size(Metrica.spazioLargo))
          .padding(.vertical, a11y.size(Metrica.spazioPiccolo))
          .frame(maxWidth: a11y.size(520), minHeight: a11y.bersaglio)
          .contentShape(RoundedRectangle(cornerRadius: a11y.size(Metrica.raggio)))
      }
      .buttonStyle(StilePulsante(forma: .arrotondata(a11y.size(Metrica.raggio)), a11y: a11y))
      .foregroundStyle(palette.onAccent)
      .background {
        ZStack {
          RoundedRectangle(cornerRadius: a11y.size(Metrica.raggio))
            .fill(palette.foreground)
            .offset(y: a11y.size(Metrica.briciola))
          RoundedRectangle(cornerRadius: a11y.size(Metrica.raggio))
            .fill(palette.accent)
        }
      }
      .opacity(stato.azioneAttiva ? 1 : 0.65)
      .keyboardShortcut(.space, modifiers: [])
      .accessibilityIdentifier("azione-gioco")
      .accessibilityLabel(invito)
      .accessibilityValue(
        stato.testoLampo.map { "\(etichettaVoce) \($0)" } ?? etichettaVoce)
      .accessibilityHint("Puoi anche premere Invio o fare clic sul campo.")

      Button("", action: premiSeDisponibile)
        .keyboardShortcut(.return, modifiers: [])
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
    .frame(maxWidth: a11y.size(1040))
  }

  private func premiSeDisponibile() {
    guard stato.azioneAttiva else { return }
    onPremi()
  }

  private var barra: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top, spacing: a11y.size(Metrica.spazioMedio)) {
        titoloHUD
        Spacer(minLength: a11y.size(Metrica.spazio))
        statisticheHUD
      }
      VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioPiccolo)) {
        titoloHUD
        statisticheHUD
      }
    }
    .frame(maxWidth: a11y.size(860), alignment: .leading)
  }

  private var titoloHUD: some View {
    VStack(alignment: .leading, spacing: a11y.size(Metrica.filo)) {
      Text(titolo)
        .font(a11y.font(.titolo, .heavy))
      Text(sottotitolo)
        .font(a11y.font(.etichetta, .semibold))
    }
    .foregroundStyle(palette.onAccent)
    .padding(.horizontal, a11y.size(Metrica.spazioMedio))
    .padding(.vertical, a11y.size(Metrica.spazioPiccolo))
    .background {
      RoundedRectangle(cornerRadius: a11y.size(Metrica.raggio))
        .fill(palette.accent)
    }
  }

  private var statisticheHUD: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: a11y.size(Metrica.spazioMedio)) { indicatori }
      VStack(alignment: .leading, spacing: a11y.size(Metrica.spazioPiccolo)) { indicatori }
    }
    .padding(.horizontal, a11y.size(Metrica.spazioMedio))
    .padding(.vertical, a11y.size(Metrica.spazioPiccolo))
    .background {
      RoundedRectangle(cornerRadius: a11y.size(Metrica.raggio))
        .fill(palette.surface)
    }
    .overlay {
      RoundedRectangle(cornerRadius: a11y.size(Metrica.raggio))
        .strokeBorder(palette.foreground,
                      lineWidth: a11y.theme == .altoContrasto ? 3 : 1)
    }
  }

  @ViewBuilder
  private var indicatori: some View {
    if stato.mostraPunti {
      indicatore(simbolo: "sparkles", etichetta: "Punti", valore: String(punti))
    }
    indicatore(simbolo: "person.2.fill", etichetta: "Squadra", valore: statoDestra)
  }

  private func indicatore(simbolo: String, etichetta: String, valore: String) -> some View {
    HStack(spacing: a11y.size(Metrica.spazioStretto)) {
      Image(systemName: simbolo)
        .font(.system(size: a11y.size(18), weight: .bold))
        .foregroundStyle(palette.accent)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: a11y.size(Metrica.filo)) {
        Text(etichetta)
          .font(a11y.font(.nota, .semibold))
          .foregroundStyle(palette.muted)
        Text(valore)
          .font(a11y.font(.corpo, .bold))
          .foregroundStyle(palette.foreground)
      }
    }
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var scrittaLampo: some View {
    if let lampo, let testo = stato.testoLampo {
      let ancora = stato.simboloLampo != nil
      HStack(spacing: a11y.size(Metrica.spazioStretto)) {
        if let simbolo = stato.simboloLampo {
          Image(systemName: simbolo)
            .font(.system(size: a11y.size(22), weight: .bold))
            .accessibilityHidden(true)
        }
        Text(testo)
      }
      .font(a11y.font(lampo.grande ? .titoloGrande : .sezione, .heavy))
      .foregroundStyle(palette.foreground)
      .padding(.horizontal, a11y.size(Metrica.spazioLargo))
      .padding(.vertical, a11y.size(Metrica.spazioMedio))
      .background {
        RoundedRectangle(cornerRadius: a11y.size(Metrica.raggio))
          .fill(palette.surface)
      }
      .overlay {
        RoundedRectangle(cornerRadius: a11y.size(Metrica.raggio))
          .strokeBorder(ancora ? palette.wrong : palette.premio,
                        lineWidth: a11y.theme == .altoContrasto ? 4 : 3)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(testo)
    }
  }
}
