import UIKit
import Flutter
import Libmtorrentserver
import app_links

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static let ankiMobilePasteboardType = "net.ankimobile.json"
  private var ankiMobileMediaBackgroundTask: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
      let mChannel = FlutterMethodChannel(name: "com.kodjodevf.mangayomi.libmtorrentserver", binaryMessenger: controller.binaryMessenger)
              mChannel.setMethodCallHandler({
                  (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
                  switch call.method {
                  case "start":
                      let args = call.arguments as? Dictionary<String, Any>
                      let config = args?["config"] as? String
                      var error: NSError?
                      let mPort = UnsafeMutablePointer<Int>.allocate(capacity: MemoryLayout<Int>.stride)
                      if LibmtorrentserverStart(config, mPort, &error){
                          result(mPort.pointee)
                      }else{
                          result(FlutterError(code: "ERROR", message: error.debugDescription, details: nil))
                      }
                  default:
                      result(FlutterMethodNotImplemented)
                  }
              })

      let ankiMobileChannel = FlutterMethodChannel(
        name: "com.selxo.mangatan.ankimobile",
        binaryMessenger: controller.binaryMessenger)
      ankiMobileChannel.setMethodCallHandler({ [weak self]
          (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
          switch call.method {
          case "consumeInfoForAddingPasteboard":
              if let data = UIPasteboard.general.data(
                forPasteboardType: Self.ankiMobilePasteboardType
              ) {
                  UIPasteboard.general.setData(
                    Data(),
                    forPasteboardType: Self.ankiMobilePasteboardType)
                  result(String(data: data, encoding: .utf8))
              } else {
                  result(nil)
              }
          case "beginMediaImportBackgroundTask":
              self?.beginAnkiMobileMediaBackgroundTask()
              result(nil)
          case "endMediaImportBackgroundTask":
              self?.endAnkiMobileMediaBackgroundTask()
              result(nil)
          default:
              result(FlutterMethodNotImplemented)
          }
      })

      let embeddedMihonChannel = FlutterMethodChannel(
        name: "com.selxo.mangatan.embedded_mihon",
        binaryMessenger: controller.binaryMessenger)
      embeddedMihonChannel.setMethodCallHandler({
          (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
          switch call.method {
          case "start":
              let args = call.arguments as? [String: Any]
              let port = Int32(args?["port"] as? Int ?? 0)
              MangatanEmbeddedMihonStart(port) { startedPort, error in
                  if let error = error {
                      result(FlutterError(
                        code: "EMBEDDED_MIHON_START",
                        message: error.localizedDescription,
                        details: nil))
                  } else {
                      result([
                        "port": Int(startedPort),
                        "baseUrl": "http://127.0.0.1:\(startedPort)",
                      ])
                  }
              }
          case "stop":
              MangatanEmbeddedMihonStop { error in
                  if let error = error {
                      result(FlutterError(
                        code: "EMBEDDED_MIHON_STOP",
                        message: error.localizedDescription,
                        details: nil))
                  } else {
                      result(nil)
                  }
              }
          case "status":
              MangatanEmbeddedMihonIsRunning { isRunning, error in
                  if let error = error {
                      result(FlutterError(
                        code: "EMBEDDED_MIHON_STATUS",
                        message: error.localizedDescription,
                        details: nil))
                  } else {
                      result(isRunning)
                  }
              }
          default:
              result(FlutterMethodNotImplemented)
          }
      })

    GeneratedPluginRegistrant.register(with: self)

    if let url = AppLinks.shared.getLink(launchOptions: launchOptions) {
      AppLinks.shared.handleLink(url: url)
      return true
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func beginAnkiMobileMediaBackgroundTask() {
    endAnkiMobileMediaBackgroundTask()
    ankiMobileMediaBackgroundTask = UIApplication.shared.beginBackgroundTask(
      withName: "AnkiMobile media import"
    ) { [weak self] in
      self?.endAnkiMobileMediaBackgroundTask()
    }
  }

  private func endAnkiMobileMediaBackgroundTask() {
    guard ankiMobileMediaBackgroundTask != .invalid else { return }
    let task = ankiMobileMediaBackgroundTask
    ankiMobileMediaBackgroundTask = .invalid
    UIApplication.shared.endBackgroundTask(task)
  }
}
