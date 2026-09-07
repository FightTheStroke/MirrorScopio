import SwiftUI

struct StudioInstructionsView: View {
  let instruction: StudioInstruction
  private let automaticallyExpanded: Bool
  private let listen: (() -> Void)?
  @State private var expanded: Bool
  @Environment(\.palette) private var palette
  @Environment(\.impostazioni) private var a11y

  init(_ instruction: StudioInstruction, automaticallyExpanded: Bool, listen: (() -> Void)? = nil) {
    self.instruction = instruction
    self.automaticallyExpanded = automaticallyExpanded
    self.listen = listen
    _expanded = State(initialValue: automaticallyExpanded)
  }

  var body: some View {
    DisclosureGroup(isExpanded: $expanded) {
      Text(instruction.explanation)
        .font(a11y.font(.corpo))
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, Metrica.spazioPiccolo)
        .accessibilityIdentifier("studio.instructions.\(instruction.rawValue)")
      if let listen {
        StudioButton("Spiegami a voce", icon: "speaker.wave.2",
                     id: "studio.instructions.listen", action: listen)
          .padding(.bottom, Metrica.spazioPiccolo)
      }
    } label: {
      Text(instruction.title)
        .font(a11y.font(.corpo, .semibold))
        .frame(minHeight: a11y.bersaglio, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, a11y.size(Metrica.spazioLargo))
    .background(palette.surface, in: RoundedRectangle(cornerRadius: Metrica.raggio))
    .foregroundStyle(palette.foreground)
    .onChange(of: instruction) { _, _ in expanded = automaticallyExpanded }
  }
}
