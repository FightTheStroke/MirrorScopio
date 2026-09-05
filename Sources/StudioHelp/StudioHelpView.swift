import SwiftUI

struct StudioHelpView: View {
  let onClose: () -> Void
  @State private var expanded: Set<String> = ["iniziare"]
  @AppStorage("studioGuidaTestoGrande") private var largeText = false
  @StateObject private var speaker = Speaker()
  @Environment(\.scenePhase) private var scenePhase
  @ScaledMetric(relativeTo: .body) private var baseSize = 17

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text("Studia con gli strumenti che ti aiutano, senza correre.")
            .font(.system(size: fontSize, weight: .semibold))
          Text("Ogni parte spiega cosa fare e perché l'app è fatta così. Puoi leggerla o ascoltarla.")
          Toggle(isOn: $largeText) {
            Text("Testo doppio").frame(minHeight: 44)
          }
            .toggleStyle(.button)
            .accessibilityIdentifier("studio.help.largeText")
          if speaker.isSpeaking {
            Button { speaker.stop() } label: {
              Label("Ferma la lettura", systemImage: "stop.fill").frame(minHeight: 44)
            }
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
            .buttonStyle(.bordered)
            .accessibilityValue(expanded.contains(topic.id) ? "Aperto" : "Chiuso")
            .accessibilityIdentifier("studio.help.\(topic.id)")
            if expanded.contains(topic.id) {
              VStack(alignment: .leading, spacing: 12) {
                Text("Come si usa").bold()
                Text(topic.how)
                Text("Perché questa scelta").bold()
                Text(topic.why)
                if Speaker.bestItalianVoice != nil {
                  Button {
                    speaker.say("\(topic.title). Come si usa. \(topic.how) Perché questa scelta. \(topic.why)")
                  } label: {
                    Label("Ascolta questa parte", systemImage: "speaker.wave.2").frame(minHeight: 44)
                  }
                  .buttonStyle(.bordered)
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
        .font(.system(size: fontSize))
        .padding(24)
        .frame(maxWidth: fontSize / 17 * 800, alignment: .leading)
        .frame(maxWidth: .infinity)
      }
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

  private var fontSize: CGFloat { baseSize * (largeText ? 2 : 1) }

}
