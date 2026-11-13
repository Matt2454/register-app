import CryptoKit
import EventKit
import EventKitUI
import Flutter
import UIKit

/// Explicit, one-way export. iOS 17+ needs write-only access; no calendar events
/// are read. A local ledger avoids re-exporting the same source item.
final class RegisterCalendarExporter: NSObject, EKCalendarChooserDelegate {
  private let registrar: FlutterPluginRegistrar
  private let channel: FlutterMethodChannel
  private let store = EKEventStore()
  private var pending: FlutterResult?
  private var drafts: [Draft] = []
  private var scope = ""
  private var skipExisting = true
  private let ledgerKey = "register.calendar.exports.v1"

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    channel = FlutterMethodChannel(name: "register/apple_calendar", binaryMessenger: registrar.messenger())
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "calendar_unavailable", message: "Kalenderexport nicht verfügbar.", details: nil))
        return
      }
      self.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "openSettings" {
      guard let url = URL(string: UIApplication.openSettingsURLString) else { result(false); return }
      UIApplication.shared.open(url, options: [:]) { result($0) }
      return
    }
    guard call.method == "export" else { result(FlutterMethodNotImplemented); return }
    guard pending == nil else {
      result(FlutterError(code: "calendar_busy", message: "Ein Kalenderexport ist bereits geöffnet.", details: nil)); return
    }
    guard let args = call.arguments as? [String: Any],
          let raw = args["events"] as? [[String: Any]], !raw.isEmpty, raw.count <= 1000,
          let accountScope = args["scope"] as? String, !accountScope.isEmpty,
          let decoded = try? raw.map({ try Draft($0) }) else {
      result(FlutterError(code: "calendar_invalid", message: "Die Termine enthalten ungültige Daten.", details: nil)); return
    }
    drafts = decoded
    scope = accountScope
    skipExisting = args["skipExisting"] as? Bool ?? true
    pending = result
    let completion: (Bool, Error?) -> Void = { [weak self] granted, error in
      DispatchQueue.main.async {
        guard let self = self else { return }
        guard granted else {
          self.finish(FlutterError(code: "calendar_permission", message:
            "Bitte erlaube Register in den iPhone-Einstellungen, Termine zum Kalender hinzuzufügen.", details: nil))
          return
        }
        self.presentCalendarChooser()
      }
    }
    if #available(iOS 17.0, *) {
      store.requestWriteOnlyAccessToEvents(completion: completion)
    } else {
      store.requestAccess(to: .event, completion: completion)
    }
  }

  private func presentCalendarChooser() {
    guard let presenter = registrar.viewController, presenter.viewIfLoaded?.window != nil,
          presenter.presentedViewController == nil else {
      finish(FlutterError(code: "calendar_busy", message: "Bitte schließe den offenen Dialog und versuche es erneut.", details: nil)); return
    }
    let chooser = EKCalendarChooser(selectionStyle: .single, displayStyle: .writableCalendarsOnly,
                                     entityType: .event, eventStore: store)
    chooser.title = "Kalender auswählen"
    chooser.showsDoneButton = true
    chooser.showsCancelButton = true
    chooser.delegate = self
    if let calendar = store.defaultCalendarForNewEvents { chooser.selectedCalendars = [calendar] }
    let navigation = UINavigationController(rootViewController: chooser)
    // All cancellation goes through the delegate so the Flutter call always ends.
    navigation.isModalInPresentation = true
    presenter.present(navigation, animated: true)
  }

  func calendarChooserDidCancel(_ calendarChooser: EKCalendarChooser) {
    calendarChooser.dismiss(animated: true) { self.finish(["cancelled": true]) }
  }

  func calendarChooserDidFinish(_ calendarChooser: EKCalendarChooser) {
    guard let calendar = calendarChooser.selectedCalendars.first ?? store.defaultCalendarForNewEvents,
          calendar.allowsContentModifications else {
      calendarChooser.dismiss(animated: true) {
        self.finish(FlutterError(code: "calendar_missing", message:
          "Kein beschreibbarer Kalender ausgewählt. Bitte richte einen Kalender in Apple Kalender ein.", details: nil))
      }
      return
    }
    calendarChooser.dismiss(animated: true) { self.save(to: calendar) }
  }

  private func save(to calendar: EKCalendar) {
    var ledger = UserDefaults.standard.dictionary(forKey: ledgerKey) as? [String: Double] ?? [:]
    var keys = Set<String>()
    var newlyAdded: [String] = []
    var skipped = 0
    do {
      for draft in drafts {
        let raw = try JSONSerialization.data(withJSONObject: [scope, calendar.calendarIdentifier, draft.id])
        let key = SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
        guard keys.insert(key).inserted else { skipped += 1; continue }
        if skipExisting && ledger[key] != nil { skipped += 1; continue }
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = draft.title
        event.location = draft.location
        event.notes = [draft.notes, "Aus Register exportiert. Keine automatische Synchronisierung."].filter { !$0.isEmpty }.joined(separator: "\n\n")
        event.isAllDay = draft.allDay
        event.timeZone = draft.allDay ? nil : TimeZone(identifier: "Europe/Rome")
        event.startDate = draft.start
        event.endDate = draft.end
        try store.save(event, span: .thisEvent, commit: false)
        newlyAdded.append(key)
      }
      if !newlyAdded.isEmpty { try store.commit() }
      let now = Date().timeIntervalSince1970
      for key in newlyAdded { ledger[key] = now }
      if ledger.count > 10000 {
        ledger = Dictionary(uniqueKeysWithValues: ledger.sorted { $0.value > $1.value }.prefix(10000).map { ($0.key, $0.value) })
      }
      UserDefaults.standard.set(ledger, forKey: ledgerKey)
      finish(["added": newlyAdded.count, "skipped": skipped, "cancelled": false])
    } catch {
      // Do not mark any item as exported if the atomic batch did not commit.
      store.reset()
      finish(FlutterError(code: "calendar_save", message:
        "Die Termine konnten nicht gespeichert werden. Bitte erneut versuchen.", details: nil))
    }
  }

  private func finish(_ response: Any) {
    let callback = pending
    pending = nil
    drafts = []
    scope = ""
    callback?(response)
  }

  struct Draft {
    let id: String, title: String, notes: String, location: String
    let start: Date, end: Date
    let allDay: Bool

    init(_ raw: [String: Any]) throws {
      guard let id = raw["id"] as? String, !id.isEmpty, id.count < 1000,
            let title = raw["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let allDay = raw["allDay"] as? Bool,
            let from = raw["start"] as? [Int], let to = raw["end"] as? [Int] else { throw ExportError.invalid }
      self.id = id
      self.title = String(title.prefix(1000))
      self.notes = String((raw["notes"] as? String ?? "").prefix(20000))
      self.location = String((raw["location"] as? String ?? "").prefix(1000))
      self.allDay = allDay
      self.start = try Self.date(from, allDay: allDay)
      self.end = try Self.date(to, allDay: allDay)
      guard end > start else { throw ExportError.invalid }
    }

    static func date(_ parts: [Int], allDay: Bool) throws -> Date {
      guard parts.count == 5, (1900...2200).contains(parts[0]), (1...12).contains(parts[1]),
            (1...31).contains(parts[2]), (0...23).contains(parts[3]), (0...59).contains(parts[4]) else {
        throw ExportError.invalid
      }
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = allDay ? .current : TimeZone(identifier: "Europe/Rome")!
      let c = DateComponents(year: parts[0], month: parts[1], day: parts[2],
                             hour: allDay ? 0 : parts[3], minute: allDay ? 0 : parts[4])
      guard let date = calendar.date(from: c) else { throw ExportError.invalid }
      let check = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
      guard check.year == c.year, check.month == c.month, check.day == c.day,
            check.hour == c.hour, check.minute == c.minute else { throw ExportError.invalid }
      return date
    }
  }
  enum ExportError: Error { case invalid }
}
