import Flutter
import Foundation
import WidgetKit

final class RegisterWidgetBridge {
  private let channel: FlutterMethodChannel
  init(registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(name: "register/widget", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard ["saveAgenda", "clearAgenda"].contains(call.method) else {
        result(FlutterMethodNotImplemented); return
      }
      guard let directory = RegisterWidgetStore.directory else {
        result(FlutterError(code: "widget_group", message: "Widget sharing is unavailable.", details: nil)); return
      }
      do {
        if call.method == "clearAgenda" {
          try RegisterWidgetStore.clear(in: directory)
        } else {
          guard let json = call.arguments as? String, let data = json.data(using: .utf8), data.count <= 1_000_000 else {
            result(FlutterError(code: "widget_data", message: "Invalid widget snapshot.", details: nil)); return
          }
          try RegisterWidgetStore.save(data, in: directory)
        }
        WidgetCenter.shared.reloadAllTimelines()
        result(nil)
      } catch {
        result(FlutterError(code: "widget_save", message: "Could not update the widget.", details: nil))
      }
    }
  }
}
