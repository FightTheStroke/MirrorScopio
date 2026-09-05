import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import Testing
#if os(iOS)
@testable import MirrorScopioMobile
#else
@testable import MirrorScopio
#endif

@Suite("Estrazione Studio con documenti reali generati localmente")
struct StudioExtractionTests {
  private let sentence = "Il costo riguarda le risorse."

  @Test("Il testo UTF-8 e quello incorporato nel PDF vengono estratti")
  func textAndPDF() async throws {
    let folder = try makeFolder()
    defer { removeFolder(folder) }
    let textURL = folder.appendingPathComponent("lezione.txt")
    try Data(sentence.utf8).write(to: textURL)
    let text = try await StudioExtraction.extract(url: textURL, progress: { _ in })
    #expect(text.text == sentence)

    let pdfURL = folder.appendingPathComponent("lezione.pdf")
    try makePDF(pages: 1).write(to: pdfURL)
    let pdf = try await StudioExtraction.extract(url: pdfURL, progress: { _ in })
    #expect(pdf.text.contains(sentence))
    #expect(pdf.warning.isEmpty)
  }

  @Test("Vision legge una pagina raster, senza testo incorporato")
  func rasterRecognition() throws {
    let context = try #require(CGContext(
      data: nil, width: 1200, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 1200, height: 300))
    drawText(in: context, size: 48, position: CGPoint(x: 50, y: 150))
    let image = try #require(context.makeImage())
    let bytes = NSMutableData()
    let destination = try #require(CGImageDestinationCreateWithData(
      bytes, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    try #require(CGImageDestinationFinalize(destination))
    let result = try StudioExtraction.imageText(bytes as Data)
    #expect(result.text.contains(sentence))
  }

  @Test("PDF troppo lunghi e immagini illeggibili non producono un falso successo")
  func invalidDocuments() async throws {
    let folder = try makeFolder()
    defer { removeFolder(folder) }
    let url = folder.appendingPathComponent("troppo-lungo.pdf")
    try makePDF(pages: 31).write(to: url)
    await #expect(throws: (any Error).self) {
      _ = try await StudioExtraction.extract(url: url, progress: { _ in })
    }
    #expect(throws: (any Error).self) {
      _ = try StudioExtraction.imageText(Data("Non è un'immagine".utf8))
    }
  }

  private func makePDF(pages: Int) throws -> Data {
    let bytes = NSMutableData()
    let consumer = try #require(CGDataConsumer(data: bytes))
    var bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
    let context = try #require(CGContext(consumer: consumer, mediaBox: &bounds, nil))
    for _ in 0..<pages {
      context.beginPDFPage(nil)
      drawText(in: context, size: 24, position: CGPoint(x: 50, y: 740))
      context.endPDFPage()
    }
    context.closePDF()
    return bytes as Data
  }

  private func drawText(in context: CGContext, size: CGFloat, position: CGPoint) {
    let text = NSAttributedString(string: sentence, attributes: [
      NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, size, nil)
    ])
    context.textPosition = position
    CTLineDraw(CTLineCreateWithAttributedString(text), context)
  }

  private func makeFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("studio-estrazione-\(UUID())")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
  }

  private func removeFolder(_ folder: URL) {
    do { try FileManager.default.removeItem(at: folder) }
    catch { Issue.record(error, "La cartella temporanea non è stata rimossa.") }
  }
}
