#if os(macOS)
import FlutterMacOS
#else
import Flutter
#endif
import Foundation
import ImageIO
import Vision

final class AppleVisionOcrPlugin {
  private static let channelName = "com.mangatan.ocr/apple_vision"

  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "supportedLanguages":
        do {
          result(try supportedLanguages())
        } catch {
          result(flutterError(code: "VISION_LANGUAGES", error: error))
        }
      case "recognize":
        recognize(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func recognize(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let typedData = arguments["bytes"] as? FlutterStandardTypedData,
          let language = arguments["language"] as? String,
          !language.isEmpty else {
      result(FlutterError(
        code: "INVALID_ARGUMENTS",
        message: "Expected non-empty image bytes and language",
        details: nil
      ))
      return
    }

    let data = typedData.data
    Task.detached(priority: .userInitiated) {
      do {
        let response = try await recognize(data: data, language: language)
        DispatchQueue.main.async { result(response) }
      } catch {
        DispatchQueue.main.async {
          result(flutterError(code: "VISION_RECOGNIZE", error: error))
        }
      }
    }
  }

  static func recognize(
    data: Data,
    language: String
  ) async throws -> [String: Any] {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw AppleVisionOcrError.invalidImage
    }
    let languages = try supportedLanguages()
    guard languages.contains(language) else {
      throw AppleVisionOcrError.unsupportedLanguage(language)
    }

    let recognized: [RecognizedBlock]
    if #available(macOS 15.0, iOS 18.0, *) {
      recognized = try await recognizeModern(image: image, language: language)
    } else {
      recognized = try recognizeLegacy(image: image, language: language)
    }
    let blocks: [[String: Any]] = recognized.map { block in
      let converted = topLeftBounds(block.bounds)
      return [
        "text": block.text,
        "xmin": converted.minX,
        "ymin": converted.minY,
        "xmax": converted.maxX,
        "ymax": converted.maxY,
        "rotation": 0.0,
        "vertical": block.vertical,
        "confidence": block.confidence,
      ]
    }
    return [
      "imageWidth": image.width,
      "imageHeight": image.height,
      "blocks": blocks,
    ]
  }

  @available(macOS 15.0, iOS 18.0, *)
  private static func recognizeModern(
    image: CGImage,
    language: String
  ) async throws -> [RecognizedBlock] {
    var request = RecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = [Locale.Language(identifier: language)]
    request.automaticallyDetectsLanguage = false
    request.usesLanguageCorrection = true

    let observations = try await request.perform(on: image)
    return observations.compactMap { observation in
      guard let candidate = observation.topCandidates(1).first else { return nil }
      let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else { return nil }
      let bounds = observation.boundingBox.cgRect
      var vertical = bounds.height > bounds.width * 1.1
      if #available(macOS 26.0, iOS 26.0, *) {
        switch observation.textDirection {
        case .topToBottom:
          vertical = true
        case .leftToRight, .rightToLeft:
          vertical = false
        case .none:
          break
        @unknown default:
          break
        }
      }
      return RecognizedBlock(
        text: text,
        bounds: bounds,
        confidence: candidate.confidence,
        vertical: vertical
      )
    }
  }

  private static func recognizeLegacy(
    image: CGImage,
    language: String
  ) throws -> [RecognizedBlock] {
    var recognized: [RecognizedBlock] = []
    for orientation in recognitionOrientations(language: language) {
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.recognitionLanguages = [language]
      // Language correction is useful for prose but tends to replace short
      // names, sound effects, and fragments found in manga artwork.
      request.usesLanguageCorrection = false
      request.minimumTextHeight = 0
      request.revision = recognitionRevision()

      let handler = VNImageRequestHandler(
        cgImage: image,
        orientation: orientation,
        options: [:]
      )
      try handler.perform([request])
      for observation in request.results ?? [] {
        guard let candidate = observation.topCandidates(1).first else { continue }
        let bounds = originalBounds(
          observation.boundingBox,
          orientation: orientation
        )
        addDeduplicated(
          RecognizedBlock(
            text: candidate.string,
            bounds: bounds,
            confidence: candidate.confidence,
            vertical: bounds.height > bounds.width * 1.5
          ),
          to: &recognized
        )
      }
    }
    return recognized
  }

  static func supportedLanguages() throws -> [String] {
    try VNRecognizeTextRequest.supportedRecognitionLanguages(
      for: .accurate,
      revision: recognitionRevision()
    )
  }

  static func topLeftBounds(_ visionBounds: CGRect) -> CGRect {
    CGRect(
      x: visionBounds.minX,
      y: 1.0 - visionBounds.maxY,
      width: visionBounds.width,
      height: visionBounds.height
    )
  }

  static func originalBounds(
    _ orientedBounds: CGRect,
    orientation: CGImagePropertyOrientation
  ) -> CGRect {
    let corners = [
      CGPoint(x: orientedBounds.minX, y: orientedBounds.minY),
      CGPoint(x: orientedBounds.maxX, y: orientedBounds.minY),
      CGPoint(x: orientedBounds.minX, y: orientedBounds.maxY),
      CGPoint(x: orientedBounds.maxX, y: orientedBounds.maxY),
    ].map { point -> CGPoint in
      switch orientation {
      case .down:
        return CGPoint(x: 1 - point.x, y: 1 - point.y)
      case .left:
        return CGPoint(x: point.y, y: 1 - point.x)
      case .right:
        return CGPoint(x: 1 - point.y, y: point.x)
      default:
        return point
      }
    }
    let xs = corners.map(\.x)
    let ys = corners.map(\.y)
    return CGRect(
      x: xs.min() ?? 0,
      y: ys.min() ?? 0,
      width: (xs.max() ?? 0) - (xs.min() ?? 0),
      height: (ys.max() ?? 0) - (ys.min() ?? 0)
    )
  }

  private static func recognitionOrientations(
    language: String
  ) -> [CGImagePropertyOrientation] {
    let base = language.lowercased().split(separator: "-").first ?? ""
    if base == "ja" || base == "zh" {
      // Vision overwhelmingly favors horizontal text. Running the other
      // orientations recovers vertical CJK columns, then originalBounds maps
      // their observations back onto the unrotated page.
      return [.up, .down, .left, .right]
    }
    return [.up]
  }

  private static func addDeduplicated(
    _ block: RecognizedBlock,
    to blocks: inout [RecognizedBlock]
  ) {
    let duplicates = blocks.indices.filter { index in
      blocks[index].vertical == block.vertical &&
        overlapOverSmallerArea(block.bounds, blocks[index].bounds) >= 0.7
    }
    guard !duplicates.isEmpty else {
      blocks.append(block)
      return
    }
    let existing = duplicates.map { blocks[$0] }
    let best = (existing + [block]).max { $0.quality < $1.quality } ?? block
    for index in duplicates.reversed() {
      blocks.remove(at: index)
    }
    blocks.append(best)
  }

  private static func overlapOverSmallerArea(
    _ left: CGRect,
    _ right: CGRect
  ) -> CGFloat {
    let intersection = left.intersection(right)
    if intersection.isNull || intersection.isEmpty { return 0 }
    let intersectionArea = intersection.width * intersection.height
    let smallerArea = min(left.width * left.height, right.width * right.height)
    return smallerArea > 0 ? intersectionArea / smallerArea : 0
  }

  private static func recognitionRevision() -> Int {
    VNRecognizeTextRequest.currentRevision
  }

  private static func flutterError(code: String, error: Error) -> FlutterError {
    FlutterError(
      code: code,
      message: error.localizedDescription,
      details: String(describing: error)
    )
  }
}

private struct RecognizedBlock {
  let text: String
  let bounds: CGRect
  let confidence: VNConfidence
  let vertical: Bool

  var quality: Double {
    let characters = text.unicodeScalars.filter {
      !CharacterSet.whitespacesAndNewlines.contains($0)
    }.count
    return Double(characters) + Double(confidence)
  }
}

private enum AppleVisionOcrError: LocalizedError {
  case invalidImage
  case unsupportedLanguage(String)

  var errorDescription: String? {
    switch self {
    case .invalidImage:
      return "The supplied OCR image could not be decoded"
    case .unsupportedLanguage(let language):
      return "Apple Vision OCR does not support \(language) on this OS version"
    }
  }
}
