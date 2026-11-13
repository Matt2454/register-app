// Run: swiftc Shared/WidgetSnapshot.swift UITests/WidgetModelChecks.swift -o /tmp/register-widget-checks
// These deterministic checks do not read or write a user's calendars or account.
import Foundation

@main
enum WidgetModelChecks {
  static func main() throws {
    let payload: [String: Any] = [
      "version": 1, "language": "it", "lastUpdated": "2026-11-09T07:00", "tasksLoaded": true,
      "days": [["date": "2026-11-09", "loaded": true,
        "lessons": [["title": "Mathematik", "room": "204", "periods": [
          ["start": "2026-11-09T08:30", "end": "2026-11-09T09:15"],
          ["start": "2026-11-09T09:30", "end": "2026-11-09T10:15"],
        ]]]]],
      "tasks": [
        ["id": "past", "title": "Past", "subject": "", "date": "2026-11-08", "isTest": false],
        ["id": "today", "title": "Read", "subject": "Italiano", "date": "2026-11-09", "isTest": false],
        ["id": "tomorrow", "title": "Test", "subject": "Mathematik", "date": "2026-11-10", "isTest": true],
      ],
    ]
    let data = try JSONSerialization.data(withJSONObject: payload)
    let snapshot = try RegisterWidgetSnapshot.decode(data)
    let now = RegisterSchoolClock.parse("2026-11-09T09:20")!
    let periods = snapshot.periods(after: now)
    precondition(periods.count == 1 && !periods[0].isCurrent(at: now), "Breaks must not appear as lessons")
    precondition(RegisterSchoolClock.time(periods[0].start) == "09:30")
    let timeline = snapshot.timelineDates(at: now)
    precondition(timeline.contains(periods[0].start) && timeline.contains(periods[0].end))
    precondition(timeline.contains(RegisterSchoolClock.parse("2026-11-10T00:00")!))
    precondition(snapshot.deadlines(at: now).map(\.id) == ["today", "tomorrow"])
    precondition(snapshot.deadlines(at: RegisterSchoolClock.parse("2026-11-10T00:00")!).map(\.id) == ["tomorrow"])
    precondition(!snapshot.isStale(at: now))
    precondition(snapshot.isStale(at: RegisterSchoolClock.parse("2026-11-11T09:20")!))
    let summer = RegisterSchoolClock.parse("2027-04-05T07:45")!
    precondition(ISO8601DateFormatter().string(from: summer) == "2027-04-05T05:45:00Z")
    precondition(RegisterWidgetStrings(language: "it").room("204") == "Aula 204")
    precondition(RegisterWidgetStrings(language: "de").now == "Jetzt")
    precondition(RegisterWidgetStrings(language: "en").next == "Next lesson")

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("register-widgets-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try RegisterWidgetStore.save(data, in: directory)
    precondition(RegisterWidgetStore.load(from: directory)?.tasks.count == 3)
    var invalid = payload
    invalid["version"] = 2
    do {
      try RegisterWidgetStore.save(JSONSerialization.data(withJSONObject: invalid), in: directory)
      preconditionFailure("Invalid data must be rejected before replacing a valid cache")
    } catch {}
    precondition(RegisterWidgetStore.load(from: directory)?.version == 1)
    try RegisterWidgetStore.clear(in: directory)
    try RegisterWidgetStore.clear(in: directory)
    precondition(RegisterWidgetStore.load(from: directory) == nil, "Signing out must remove widget data")
    print("Widget model checks passed: periods, breaks, deadlines, midnight, time zone, languages, cache validation, and clearing.")
  }
}
