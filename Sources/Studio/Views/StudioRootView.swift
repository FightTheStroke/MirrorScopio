import SwiftUI
import Combine
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class StudioRuntime {
  static let shared = StudioRuntime()
  let store: StudioStore
  let tracker: StudioSessionTracker
  let audio = StudioAudio()
  let importer = StudioImporter()
  private var terminationObserver: AnyCancellable?
  @discardableResult
  func startGuided() -> Bool {
    guard store.flushStaged(), store.startGuided(),
          let id = store.archive.guidedRun?.lessonID,
          tracker.start(lessonID: id) else { return false }
    audio.stop()
    return true
  }
  private init() {
    store = StudioStore()
    tracker = StudioSessionTracker(store: store)
    audio.onInterruption = { [weak self] in self?.tracker.pause() }
    #if os(macOS)
    let notification = NSApplication.willTerminateNotification
    #else
    let notification = UIApplication.willTerminateNotification
    #endif
    terminationObserver = NotificationCenter.default.publisher(for: notification).sink { [weak self] _ in
      _ = self?.store.flushStaged()
      self?.audio.stop()
      self?.tracker.pause()
    }
  }
}

enum StudioDestination: Equatable {
  case home, add, lesson(UUID), adult, path, library, guided, generation, help
}

struct StudioRootView: View {
  private typealias Panel = StudioDestination
  @StateObject private var store: StudioStore
  @StateObject private var tracker: StudioSessionTracker
  @StateObject private var audio: StudioAudio
  @StateObject private var importer: StudioImporter
  @State private var localPanel: Panel = .home
  private let destination: Binding<StudioDestination>?
  private var panel: Panel {
    get { destination?.wrappedValue ?? localPanel }
    nonmutating set {
      if let destination { destination.wrappedValue = newValue }
      else { localPanel = newValue }
    }
  }
  @State private var showHelp = false
  @State private var scrollPosition = ScrollPosition(edge: .top)
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.palette) private var palette
  @Environment(\.impostazioni) private var a11y
  private let onLegacy: (() -> Void)?
  private let onSettings: (() -> Void)?
  private let onProgress: (() -> Void)?
  private let onAudioCheck: (() -> Void)?
  private let onHome: (() -> Void)?
  private let greeting: String
  private let heartbeat = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

  init(destination: Binding<StudioDestination>? = nil, onLegacy: (() -> Void)? = nil,
       onSettings: (() -> Void)? = nil, onProgress: (() -> Void)? = nil,
       onAudioCheck: (() -> Void)? = nil, greeting: String = "", onHome: (() -> Void)? = nil) {
    let runtime = StudioRuntime.shared
    _store = StateObject(wrappedValue: runtime.store)
    _tracker = StateObject(wrappedValue: runtime.tracker)
    _audio = StateObject(wrappedValue: runtime.audio)
    _importer = StateObject(wrappedValue: runtime.importer)
    self.onLegacy = onLegacy
    self.onSettings = onSettings
    self.onProgress = onProgress
    self.onAudioCheck = onAudioCheck
    self.onHome = onHome
    self.greeting = greeting
    self.destination = destination
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        switch panel {
        case .home, .guided: EmptyView()
        default:
          StudioButton("Casa", icon: "house", id: "studio.home") { goHome() }
        }
        if let error = store.error {
          VStack(alignment: .leading, spacing: 8) {
            Label("Dati da controllare", systemImage: "exclamationmark.triangle").studioFont(.headline)
            Text(error).textSelection(.enabled)
            StudioButton("Riprova", icon: "arrow.clockwise") { store.retry() }
            if store.recovery {
              Text("Puoi recuperare una copia da Per l'adulto. Non verrà cancellato l'originale.")
            }
          }.padding().background(palette.surface, in: RoundedRectangle(cornerRadius: Metrica.raggio))
        }
        switch panel {
        case .home: home
        case .add:
          StudioAddView(store: store, importer: importer) { id in
            openLesson(id)
          }
        case .lesson(let id):
          if let lesson = store.displayArchive.lessons.first(where: { $0.id == id }) {
            StudioLessonView(store: store, tracker: tracker, audio: audio, lesson: lesson)
          } else { Text("La lezione non è disponibile. Torna alle tue lezioni.") }
        case .adult:
          StudioAdultView(store: store, tracker: tracker, audio: audio, onLegacy: onLegacy,
                          onSettings: onSettings)
        case .path:
          StudioPathEditor(store: store, add: { navigate(.add) }, generate: { navigate(.generation) },
                           settings: { navigate(.adult) }, open: openLesson)
        case .library:
          library
        case .guided:
          StudioGuidedView(store: store, tracker: tracker, audio: audio) { goHome() }
        case .generation:
          StudioGenerationView(store: store) { _ in
            navigate(.path)
          }
        case .help:
          StudioHelpView(onClose: goHome)
        }
      }
      .padding()
      .frame(maxWidth: a11y.size(860), alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .scrollPosition($scrollPosition)
    .onChange(of: store.displayArchive.guidedRun) { _, _ in showGuidedTop() }
    .onChange(of: store.displayArchive.reviewRun?.remaining.first) { _, _ in showGuidedTop() }
    .onChange(of: store.displayArchive.reviewRun?.revealed) { _, _ in showGuidedTop() }
    .scrollDismissesKeyboard(.interactively)
    .font(a11y.font(.corpo))
    .foregroundStyle(palette.foreground)
    .background(palette.background)
    .interlinea(a11y)
    .onAppear { syncPresentation() }
    .onChange(of: a11y) { _, _ in syncPresentation() }
    .textFieldStyle(.roundedBorder)
    .onReceive(heartbeat) { _ in tracker.checkpoint() }
    .onChange(of: scenePhase) { _, phase in
      if phase != .active { _ = store.flushStaged(); audio.background(); tracker.pause() }
    }
    .onDisappear { _ = store.flushStaged(); audio.stop(); tracker.pause() }
    .sheet(isPresented: $showHelp) { StudioHelpView(onClose: { showHelp = false }) }
    .alert("Modifica non accettata", isPresented: Binding(
      get: { store.rejectedEdit != nil },
      set: { if !$0 { store.rejectedEdit = nil } }
    )) {
      Button("Torna al testo") { store.rejectedEdit = nil }
    } message: {
      Text(store.rejectedEdit ?? "")
    }
  }

  private func showGuidedTop() {
    if panel == .guided { scrollPosition.scrollTo(edge: .top) }
  }

  private var home: some View {
    StudioHomeView(archive: store.displayArchive, start: {
      if StudioRuntime.shared.startGuided() { panel = .guided }
    }, library: { navigate(.library) }, parent: { navigate(.path) }, help: {
      audio.stop(); tracker.pause(); showHelp = true
    }, games: onLegacy.map { legacy in {
      guard store.flushStaged() else { return }
      audio.stop(); tracker.pause(); legacy()
    } }, settings: onSettings)
    .disabled(store.recovery || store.hasPendingSave)
    .overlay(alignment: .bottom) {
      if store.recovery {
        StudioButton("Recupera una copia", icon: "externaldrive") { navigate(.adult) }
      }
    }
  }

  private var library: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Le mie lezioni").studioFont(.title, weight: .bold).accessibilityAddTraits(.isHeader)
      Text("Qui ritrovi sempre testi, ascolto, mappe, formulari e domande. Per farti accompagnare, torna a casa e premi Inizia.")
      if store.displayArchive.lessons.isEmpty { Text("Il primo esempio è già pronto: torna a casa e premi Inizia.") }
      ForEach(store.displayArchive.lessons) { lesson in
        VStack(alignment: .leading, spacing: 4) {
          StudioButton(lesson.title, icon: "book", id: "studio.openLesson") { openLesson(lesson.id) }
          if !lesson.subject.isEmpty { Text(lesson.subject).studioMuted() }
          Text("Parte \(lesson.position + 1) di \(lesson.segments.count)").studioFont(.callout)
        }
      }
      StudioButton("Prepara il percorso", icon: "person.crop.circle", id: "studio.parent") { navigate(.path) }
    }
  }

  private func navigate(_ destination: Panel) {
    _ = store.flushStaged()
    audio.stop()
    tracker.pause()
    panel = destination
  }

  private func openLesson(_ id: UUID) {
    navigate(.lesson(id))
  }

  private func goHome() {
    navigate(.home)
    onHome?()
  }

  private func syncPresentation() {
    guard onSettings != nil else { return }
    let voice = a11y.voiceIdentifier ?? ""
    guard store.displayArchive.settings.voiceID != voice || store.displayArchive.settings.rate != a11y.voiceRate else { return }
    _ = store.change {
      $0.settings.voiceID = voice
      $0.settings.rate = a11y.voiceRate
    }
  }
}

extension StudioStore {
  func binding<Value>(_ path: WritableKeyPath<StudioArchive, Value>) -> Binding<Value> {
    Binding(get: { self.displayArchive[keyPath: path] }, set: { value in
      _ = self.change { $0[keyPath: path] = value }
    })
  }

  func binding(_ path: WritableKeyPath<StudioArchive, String>) -> Binding<String> {
    Binding(get: { self.displayArchive[keyPath: path] }, set: { value in
      self.stage { $0[keyPath: path] = value }
    })
  }
}

struct StudioTransferDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
  var data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents, data.count <= StudioLimits.fileBytes else {
      throw StudioFailure("Scegli un file fino a 20 MB.")
    }
    self.data = data
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
