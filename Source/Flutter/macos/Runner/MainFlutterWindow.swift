import Cocoa
import FlutterMacOS
import WidgetKit

class MainFlutterWindow: NSWindow {
  private var calendarExporter: RegisterCalendarExporter?
  private var windowChannel: FlutterMethodChannel?

  func showSettings() {
    makeKeyAndOrderFront(nil)
    windowChannel?.invokeMethod("openSettings", arguments: nil)
  }
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerWidgetChannel(messenger: flutterViewController.engine.binaryMessenger)

    calendarExporter = RegisterCalendarExporter(messenger: flutterViewController.engine.binaryMessenger, window: self)
    windowChannel = FlutterMethodChannel(name: "register/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    title = "Register"
    minSize = NSSize(width: 560, height: 640)
    setContentSize(NSSize(width: 1180, height: 820))
    center()
    super.awakeFromNib()
  }

  /// Receives the current week from Dart and stores it where the desktop
  /// widget can read it (the shared app group container).
  private func registerWidgetChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "register/widget", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard ["saveWeek", "clearWeek"].contains(call.method) else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let group = Bundle.main.object(forInfoDictionaryKey: "RegisterAppGroup") as? String,
        let container = FileManager.default.containerURL(
          forSecurityApplicationGroupIdentifier: group)
      else {
        result(FlutterError(code: "no_app_group", message: "App group not available", details: nil))
        return
      }
      do {
        let file = container.appendingPathComponent("week.json")
        if call.method == "clearWeek" {
          if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
        } else {
          guard let json = call.arguments as? String, let data = json.data(using: .utf8), data.count <= 1_000_000,
                (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else {
            result(FlutterError(code: "widget_data", message: "Invalid widget data", details: nil)); return
          }
          try data.write(to: file, options: .atomic)
        }
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      } catch {
        result(FlutterError(code: "write_failed", message: error.localizedDescription, details: nil))
      }
    }
  }
}
