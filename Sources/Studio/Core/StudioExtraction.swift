import Foundation
import PDFKit
import Vision
import ImageIO
import Combine

struct StudioExtractedText: Sendable {
  var text: String
  var warning = ""
}

enum StudioExtraction {
  static func extract(url: URL, progress: @Sendable (String) async -> Void) async throws -> StudioExtractedText {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    let data = try StudioStore.readFile(url)
    try Task.checkCancellation()
    switch url.pathExtension.lowercased() {
    case "txt":
      await progress("Lettura del testo…")
      guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
        throw StudioFailure("Il testo non è in UTF-8 o UTF-16. Salvalo in uno di questi formati e riprova.")
      }
      return StudioExtractedText(text: try checked(text))
    case "pdf":
      return try await pdf(data: data, progress: progress)
    default:
      await progress("Riconoscimento locale della pagina…")
      return StudioExtractedText(text: try checked(recognize(image(data))))
    }
  }

  static func imageText(_ data: Data) throws -> StudioExtractedText {
    guard data.count <= StudioLimits.fileBytes else { throw StudioFailure("La foto supera 20 MB.") }
    return StudioExtractedText(text: try checked(recognize(image(data))))
  }

  private static func checked(_ text: String) throws -> String {
    guard text.count <= StudioLimits.text else { throw StudioFailure("Il testo supera 120.000 caratteri. Dividi il documento.") }
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw StudioFailure("Non ho trovato testo leggibile. Prova una pagina più nitida oppure incolla il testo.")
    }
    return text
  }

  private static func image(_ data: Data) throws -> CGImage {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          CGImageSourceGetCount(source) == 1 else {
      throw StudioFailure("Scegli un'immagine con una sola pagina (PNG, JPEG o HEIC).")
    }
    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 2_400]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
      throw StudioFailure("Non posso leggere questa immagine.")
    }
    return image
  }

  private static func recognize(_ image: CGImage) throws -> String {
    try Task.checkCancellation()
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["it-IT", "en-US"]
    request.usesLanguageCorrection = true
    try VNImageRequestHandler(cgImage: image).perform([request])
    try Task.checkCancellation()
    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
  }

  private static func pdf(data: Data, progress: @Sendable (String) async -> Void) async throws -> StudioExtractedText {
    guard let document = PDFDocument(data: data), !document.isLocked else {
      throw StudioFailure("PDF non leggibile o protetto da password. Usa una copia senza protezione.")
    }
    guard document.pageCount > 0, document.pageCount <= StudioLimits.pages else {
      throw StudioFailure("Scegli un PDF da 1 a 30 pagine. Puoi dividerlo in più lezioni.")
    }
    var result = ""
    var scanned = 0
    var emptyPages: [Int] = []
    for index in 0..<document.pageCount {
      try Task.checkCancellation()
      await progress("Pagina \(index + 1) di \(document.pageCount)…")
      guard let page = document.page(at: index) else { throw StudioFailure("Pagina \(index + 1) non leggibile.") }
      let text: String
      if let embedded = page.string, !embedded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        text = embedded
      } else {
        scanned += 1
        guard scanned <= StudioLimits.scannedPages else {
          throw StudioFailure("Il PDF richiede più di 10 pagine da riconoscere. Dividilo: nessuna parte è stata salvata.")
        }
        await progress("Pagina \(index + 1): riconoscimento locale del testo…")
        text = try recognize(render(page))
      }
      if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { emptyPages.append(index + 1) }
      result += (index == 0 ? "" : "\n\n") + text
      guard result.count <= StudioLimits.text else {
        throw StudioFailure("Il PDF supera 120.000 caratteri. Dividilo: nessuna parte è stata salvata.")
      }
    }
    let warning = emptyPages.isEmpty ? "" :
      "Pagine senza testo riconoscibile: \(emptyPages.map(String.init).joined(separator: ", ")). Controllale nel documento originale: potrebbero essere vuote oppure non essere state lette."
    return StudioExtractedText(text: try checked(result), warning: warning)
  }

  private static func render(_ page: PDFPage) throws -> CGImage {
    let bounds = page.bounds(for: .mediaBox)
    guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else {
      throw StudioFailure("La pagina ha dimensioni non valide.")
    }
    let scale = 2_400 / max(bounds.width, bounds.height)
    let width = max(1, Int(bounds.width * scale))
    let height = max(1, Int(bounds.height * scale))
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
      throw StudioFailure("Memoria insufficiente per leggere la pagina.")
    }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -bounds.minX, y: -bounds.minY)
    page.draw(with: .mediaBox, to: context)
    guard let image = context.makeImage() else { throw StudioFailure("Non posso preparare la pagina da leggere.") }
    return image
  }
}

@MainActor
final class StudioImporter: ObservableObject {
  @Published private(set) var busy = false
  @Published private(set) var message: String?
  @Published var extracted: String?
  private var task: Task<Void, Never>?

  func start(url: URL) {
    run { progress in try await StudioExtraction.extract(url: url, progress: progress) }
  }

  func start(image: Data) {
    run { progress in
      await progress("Riconoscimento locale della foto…")
      return try StudioExtraction.imageText(image)
    }
  }

  private func run(_ operation: @escaping @Sendable (@Sendable (String) async -> Void) async throws -> StudioExtractedText) {
    guard !busy else { message = "Attendi la lettura in corso oppure annullala."; return }
    extracted = nil
    busy = true
    message = "Preparazione…"
    let report: @Sendable (String) async -> Void = { [weak self] text in await self?.progress(text) }
    task = Task { [weak self] in
      let worker = Task.detached(priority: .userInitiated) {
        try await operation(report)
      }
      do {
        let text = try await withTaskCancellationHandler {
          try await worker.value
        } onCancel: { worker.cancel() }
        try Task.checkCancellation()
        self?.extracted = text.text
        self?.message = "Testo estratto sul dispositivo. L'ordine di colonne, formule e parole può richiedere correzioni: rileggi prima di salvare. \(text.warning)"
      } catch is CancellationError {
        self?.message = "Importazione annullata. La tua bozza non è stata modificata."
      } catch {
        self?.message = "Importazione non riuscita: \(error.localizedDescription)"
      }
      self?.busy = false
    }
  }

  private func progress(_ text: String) { message = text }
  func cancel() {
    task?.cancel()
    message = "Annullamento dopo la pagina in corso…"
  }
}
