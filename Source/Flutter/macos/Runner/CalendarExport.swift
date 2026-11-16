import CryptoKit
import EventKit
import FlutterMacOS
import Cocoa

/// Explicit, one-way export. macOS 14+ needs write-only access; no calendar events
/// are read. A local ledger avoids re-exporting the same source item.
final class RegisterCalendarExporter: NSObject {
  private weak var window: NSWindow?
  private let channel: FlutterMethodChannel
  private let store = EKEventStore()
  private var pending: FlutterResult?
  private var drafts: [Draft] = []
  private var scope = ""
  private var skipExisting = true
  private var language = Locale.current.language.languageCode?.identifier ?? "en"
  private func text(_ en: String, _ it: String, _ de: String) -> String {
    switch language { case "it": return it; case "de": return de; default: return en }
  }
  private let ledgerKey = "register.calendar.exports.v1"

  init(messenger: FlutterBinaryMessenger, window: NSWindow) {
    self.window = window
    channel = FlutterMethodChannel(name: "register/apple_calendar", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "calendar_unavailable", message: "Calendar export is unavailable.", details: nil))
        return
      }
      self.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "openSettings" {
      let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
      result(NSWorkspace.shared.open(url))
      return
    }
    guard call.method == "export" else { result(FlutterMethodNotImplemented); return }
    guard pending == nil else {
      result(FlutterError(code: "calendar_busy", message: text("A calendar export is already open.", "È già aperta un’esportazione del calendario.", "Ein Kalenderexport ist bereits geöffnet."), details: nil)); return
    }
    if let code = (call.arguments as? [String: Any])?["language"] as? String,
       ["en", "it", "de"].contains(code) { language = code }
    guard let args = call.arguments as? [String: Any],
          let raw = args["events"] as? [[String: Any]], !raw.isEmpty, raw.count <= 1000,
          let accountScope = args["scope"] as? String, !accountScope.isEmpty,
          let decoded = try? raw.map({ try Draft($0) }) else {
      result(FlutterError(code: "calendar_invalid", message: text("The events contain invalid data.", "Gli eventi contengono dati non validi.", "Die Termine enthalten ungültige Daten."), details: nil)); return
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
            self.text("Allow Register to add calendar events in System Settings.", "Consenti a Register di aggiungere eventi al calendario nelle Impostazioni di Sistema.", "Bitte erlaube Register in den Systemeinstellungen, Termine zum Kalender hinzuzufügen."), details: nil))
          return
        }
        self.presentCalendarChooser()
      }
    }
    if #available(macOS 14.0, *) {
      store.requestWriteOnlyAccessToEvents(completion: completion)
    } else {
      store.requestAccess(to: .event, completion: completion)
    }
  }

  private func presentCalendarChooser() {
    guard let window, window.attachedSheet == nil else {
      finish(FlutterError(code: "calendar_busy", message: text("Close the open dialog and try again.", "Chiudi la finestra aperta e riprova.", "Bitte schließe den offenen Dialog und versuche es erneut."), details: nil)); return
    }
    guard let calendar = store.defaultCalendarForNewEvents, calendar.allowsContentModifications else {
      finish(FlutterError(code: "calendar_missing", message: text("Set up a writable default calendar in Apple Calendar first.", "Configura prima un calendario predefinito modificabile in Calendario Apple.", "Bitte richte zuerst einen beschreibbaren Standardkalender in Apple Kalender ein."), details: nil)); return
    }
    let alert = NSAlert()
    alert.messageText = text("Export to Apple Calendar", "Esporta in Calendario Apple", "In Apple Kalender exportieren")
    alert.informativeText = text("Add these events to your default calendar. Change the default in Apple Calendar → Settings → General.", "Aggiungi gli eventi al calendario predefinito. Puoi cambiarlo in Calendario Apple → Impostazioni → Generali.", "Füge diese Termine zu deinem Standardkalender hinzu. Du kannst ihn in Apple Kalender → Einstellungen → Allgemein ändern.")
    alert.addButton(withTitle: text("Export", "Esporta", "Exportieren"))
    alert.addButton(withTitle: text("Cancel", "Annulla", "Abbrechen"))
    alert.beginSheetModal(for: window) { [weak self] response in
      guard let self else { return }
      if response == .alertFirstButtonReturn {
        self.save(to: calendar)
      } else { self.finish(["cancelled": true]) }
    }
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
        event.notes = [draft.notes, text("Exported from Register. No automatic synchronization.", "Esportato da Register. Nessuna sincronizzazione automatica.", "Aus Register exportiert. Keine automatische Synchronisierung.")].filter { !$0.isEmpty }.joined(separator: "\n\n")
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
        text("Could not save the events. Please try again.", "Impossibile salvare gli eventi. Riprova.", "Die Termine konnten nicht gespeichert werden. Bitte erneut versuchen."), details: nil))
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
