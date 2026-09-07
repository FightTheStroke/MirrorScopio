import SwiftUI

struct StudioHelpView: View {
  let onClose: () -> Void
  @State private var expanded: Set<String> = ["iniziare"]
  @StateObject private var speaker = Speaker()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.palette) private var palette
  @Environment(\.impostazioni) private var a11y

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text("Studia con gli strumenti che ti aiutano, senza correre.")
            .font(a11y.font(.guida, .semibold))
          Text("Ogni parte spiega cosa fare e perché l'app è fatta così. Puoi leggerla o ascoltarla.")
          if speaker.isSpeaking {
            StudioButton("Ferma la lettura", icon: "stop.fill") { speaker.stop() }
          }
          ForEach(StudioHelpTopic.all) { topic in
            Button {
              if expanded.contains(topic.id) { expanded.remove(topic.id) }
              else { expanded.insert(topic.id) }
            } label: {
              HStack {
                Text(topic.title).bold().multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: expanded.contains(topic.id) ? "chevron.up" : "chevron.down")
                  .accessibilityHidden(true)
              }
              .frame(minHeight: 44)
            }
            .buttonStyle(StilePulsante(forma: .arrotondata(Metrica.raggioPiccolo), a11y: a11y))
            .padding(Metrica.spazioPiccolo)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: Metrica.raggioPiccolo))
            .accessibilityValue(expanded.contains(topic.id) ? "Aperto" : "Chiuso")
            .accessibilityIdentifier("studio.help.\(topic.id)")
            if expanded.contains(topic.id) {
              VStack(alignment: .leading, spacing: 12) {
                Text("Come si usa").bold()
                Text(topic.how)
                Text("Perché questa scelta").bold()
                Text(topic.why)
                if Speaker.bestItalianVoice != nil {
                  StudioButton("Ascolta questa parte", icon: "speaker.wave.2") {
                    speaker.voiceIdentifier = a11y.voiceIdentifier
                    speaker.say("\(topic.title). Come si usa. \(topic.how) Perché questa scelta. \(topic.why)",
                                rate: Float(a11y.voiceRate))
                  }
                  .accessibilityLabel("Ascolta: \(topic.title)")
                } else {
                  Text("Per ascoltare questa guida serve una voce italiana installata sul dispositivo.")
                }
              }
              .padding(.top, 12)
              .textSelection(.enabled)
            }
            Divider()
          }
        }
        .font(a11y.font(.corpo))
        .foregroundStyle(palette.foreground)
        .padding(24)
        .frame(maxWidth: a11y.size(800), alignment: .leading)
        .frame(maxWidth: .infinity)
      }
      .background(palette.background)
      .navigationTitle("Come funziona")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button { speaker.stop(); onClose() } label: {
            Text("Chiudi").frame(minHeight: 44)
          }
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("studio.help.close")
        }
      }
    }
    #if os(macOS)
    .frame(idealWidth: 640, idealHeight: 520)
    #endif
    .onDisappear { speaker.stop() }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { speaker.stop() }
    }
  }

}
