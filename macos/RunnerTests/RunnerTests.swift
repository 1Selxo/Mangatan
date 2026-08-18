import FlutterMacOS
import Cocoa
import XCTest
@testable import Mangatan

class RunnerTests: XCTestCase {
  func testAppleVisionConvertsVisionCoordinatesToTopLeft() {
    let converted = AppleVisionOcrPlugin.topLeftBounds(
      CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
    )

    XCTAssertEqual(converted.minX, 0.1, accuracy: 0.000_001)
    XCTAssertEqual(converted.minY, 0.4, accuracy: 0.000_001)
    XCTAssertEqual(converted.maxX, 0.4, accuracy: 0.000_001)
    XCTAssertEqual(converted.maxY, 0.8, accuracy: 0.000_001)
  }

  func testAppleVisionMapsSupplementalOrientationsToOriginalImage() {
    let bounds = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
    let down = AppleVisionOcrPlugin.originalBounds(
      bounds,
      orientation: .down
    )
    XCTAssertEqual(down.minX, 0.6, accuracy: 0.000_001)
    XCTAssertEqual(down.minY, 0.4, accuracy: 0.000_001)
    XCTAssertEqual(down.width, 0.3, accuracy: 0.000_001)
    XCTAssertEqual(down.height, 0.4, accuracy: 0.000_001)

    let left = AppleVisionOcrPlugin.originalBounds(
      bounds,
      orientation: .left
    )
    XCTAssertEqual(left.minX, 0.2, accuracy: 0.000_001)
    XCTAssertEqual(left.minY, 0.6, accuracy: 0.000_001)
    XCTAssertEqual(left.width, 0.4, accuracy: 0.000_001)
    XCTAssertEqual(left.height, 0.3, accuracy: 0.000_001)

    let right = AppleVisionOcrPlugin.originalBounds(
      bounds,
      orientation: .right
    )
    XCTAssertEqual(right.minX, 0.4, accuracy: 0.000_001)
    XCTAssertEqual(right.minY, 0.1, accuracy: 0.000_001)
    XCTAssertEqual(right.width, 0.4, accuracy: 0.000_001)
    XCTAssertEqual(right.height, 0.3, accuracy: 0.000_001)
  }

  func testAppleVisionReportsSupportedLanguages() throws {
    XCTAssertFalse(try AppleVisionOcrPlugin.supportedLanguages().isEmpty)
  }

  func testAppleVisionRejectsMalformedImages() async {
    do {
      _ = try await AppleVisionOcrPlugin.recognize(
        data: Data([0x00, 0x01, 0x02]),
        language: "en-US"
      )
      XCTFail("Malformed image should fail")
    } catch {}
  }

  func testAppleVisionRecognizesGeneratedFixture() async throws {
    let languages = try AppleVisionOcrPlugin.supportedLanguages()
    guard let language = languages.first(where: { $0.hasPrefix("en") }) else {
      throw XCTSkip("English Apple Vision OCR is unavailable")
    }
    let image = NSImage(size: NSSize(width: 500, height: 140))
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(origin: .zero, size: image.size).fill()
    ("HELLO" as NSString).draw(
      at: NSPoint(x: 20, y: 25),
      withAttributes: [
        .font: NSFont.systemFont(ofSize: 80, weight: .bold),
        .foregroundColor: NSColor.black,
      ]
    )
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
      XCTFail("Could not generate OCR fixture")
      return
    }

    let result = try await AppleVisionOcrPlugin.recognize(
      data: png,
      language: language
    )
    let blocks = result["blocks"] as? [[String: Any]]
    XCTAssertTrue(
      blocks?.contains(where: {
        ($0["text"] as? String)?.localizedCaseInsensitiveContains("HELLO")
          == true
      }) == true
    )
  }
}
