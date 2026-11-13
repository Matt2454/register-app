import Flutter
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var calendarExporter: RegisterCalendarExporter?
  private var widgetBridge: RegisterWidgetBridge?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // FlutterAppDelegate forwards foreground notifications to the plugin.
    UNUserNotificationCenter.current().delegate = self
    // Background check for news (see lib/background_check.dart); iOS decides
    // when it actually runs.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.webandgrow.register.check",
      frequency: NSNumber(value: 15 * 60)
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RegisterCalendarExporter") {
      calendarExporter = RegisterCalendarExporter(registrar: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RegisterWidgetBridge") {
      widgetBridge = RegisterWidgetBridge(registrar: registrar)
    }
  }
}
