import Foundation

@main
struct CalendarModelChecks {
  static func main() throws {
    func raw(_ from: [Int], _ to: [Int], allDay: Bool = false) -> [String: Any] {
      ["id": "lesson:1", "title": "Mathematik", "allDay": allDay,
       "start": from, "end": to]
    }
    let lesson = try RegisterCalendarExporter.Draft(raw([2026, 11, 16, 8, 30], [2026, 11, 16, 9, 15]))
    var rome = Calendar(identifier: .gregorian)
    rome.timeZone = TimeZone(identifier: "Europe/Rome")!
    precondition(rome.component(.hour, from: lesson.start) == 8)
    precondition(lesson.end.timeIntervalSince(lesson.start) == 45 * 60)
    let task = try RegisterCalendarExporter.Draft(raw([2026, 11, 16, 0, 0], [2026, 11, 17, 0, 0], allDay: true))
    precondition(Calendar.current.startOfDay(for: task.start) == task.start)
    for invalid in [
      raw([2026, 2, 30, 8, 30], [2026, 3, 1, 9, 15]),
      raw([2026, 11, 16, 9, 30], [2026, 11, 16, 9, 15]),
      raw([2026, 11, 16, 25, 0], [2026, 11, 17, 9, 15]),
      raw([2026, 3, 29, 2, 30], [2026, 3, 29, 4, 0])
    ] {
      do {
        _ = try RegisterCalendarExporter.Draft(invalid)
        fatalError("Invalid calendar event was accepted")
      } catch RegisterCalendarExporter.ExportError.invalid {}
    }
    print("Mac Calendar model checks passed")
  }
}
