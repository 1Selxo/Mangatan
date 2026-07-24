import Cocoa
import FlutterMacOS

private final class ReaderFlutterViewController: FlutterViewController {
  private var pagedWheelOwner: String?
  private var pagedWheelChannel: FlutterMethodChannel?

  func configurePagedWheelChannel() {
    let channel = FlutterMethodChannel(
      name: "com.mangatan.reader/paged_wheel",
      binaryMessenger: engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setPagedReaderWheelMode",
            let arguments = call.arguments as? [String: Any],
            let owner = arguments["owner"] as? String,
            let enabled = arguments["enabled"] as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }

      if enabled {
        self?.pagedWheelOwner = owner
      } else if self?.pagedWheelOwner == owner {
        self?.pagedWheelOwner = nil
      }
      result(nil)
    }
    pagedWheelChannel = channel
  }

  override func scrollWheel(with event: NSEvent) {
    guard pagedWheelOwner != nil,
          event.modifierFlags.intersection([.command, .control]).isEmpty else {
      super.scrollWheel(with: event)
      return
    }

    if !event.momentumPhase.isEmpty {
      return
    }

    // Wheel drivers can label their synthesized smoothing tail as either
    // precise or non-precise. The discrete CGEvent axes are the reliable
    // distinction: physical wheel detents carry +/- values while interpolated
    // pixel events carry zero. Require a detent for every unmodified paged
    // event instead of trusting AppKit's precision label.
    let verticalDetents = event.cgEvent?.getIntegerValueField(
      .scrollWheelEventDeltaAxis1
    ) ?? 0
    let horizontalDetents = event.cgEvent?.getIntegerValueField(
      .scrollWheelEventDeltaAxis2
    ) ?? 0
    if verticalDetents == 0 && horizontalDetents == 0 {
      return
    }

    super.scrollWheel(with: event)
  }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = ReaderFlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    flutterViewController.configurePagedWheelChannel()

    super.awakeFromNib()
  }
}
