import Foundation

struct RegisterWidgetSnapshot: Codable {
  let version: Int
  let language: String
  let lastUpdated: String?
  let days: [RegisterWidgetDay]
  let tasks: [RegisterWidgetTask]
  let tasksLoaded: Bool

  static func decode(_ data: Data) throws -> Self {
    let snapshot = try JSONDecoder().decode(Self.self, from: data)
    guard snapshot.version == 1, snapshot.days.count <= 31,
          snapshot.tasks.count <= 500 else { throw SnapshotError.invalid }
    return snapshot
  }

  func periods(after date: Date) -> [RegisterWidgetPeriod] {
    days.flatMap { day in
      day.lessons.flatMap { lesson in
        lesson.periods.compactMap { period -> RegisterWidgetPeriod? in
          guard let start = RegisterSchoolClock.parse(period.start),
                let end = RegisterSchoolClock.parse(period.end), end > start,
                end > date else { return nil }
          return RegisterWidgetPeriod(title: lesson.title, room: lesson.room,
                                      start: start, end: end)
        }
      }
    }.sorted { $0.start < $1.start }
  }

  func deadlines(at date: Date) -> [RegisterWidgetTask] {
    let today = RegisterSchoolClock.dayKey(date)
    return tasks.filter { $0.date >= today }.sorted { $0.date < $1.date }
  }

  func isStale(at date: Date) -> Bool {
    guard let updated = lastUpdated.flatMap(RegisterSchoolClock.parse) else { return true }
    return date.timeIntervalSince(updated) > 24 * 60 * 60
  }

  func timelineDates(at now: Date) -> [Date] {
    let horizon = now.addingTimeInterval(48 * 60 * 60)
    var dates: Set<Date> = [now]
    for period in periods(after: now) {
      for date in [period.start, period.end] where date > now && date < horizon { dates.insert(date) }
    }
    let midnight = RegisterSchoolClock.calendar.startOfDay(for: now)
    for offset in 1...2 {
      if let date = RegisterSchoolClock.calendar.date(byAdding: .day, value: offset, to: midnight) { dates.insert(date) }
    }
    return dates.sorted()
  }

  enum SnapshotError: Error { case invalid }
}

struct RegisterWidgetDay: Codable {
  let date: String
  let loaded: Bool
  let lessons: [RegisterWidgetLesson]
}

struct RegisterWidgetLesson: Codable {
  let title: String
  let room: String
  let periods: [RegisterWidgetTime]
}

struct RegisterWidgetTime: Codable {
  let start: String
  let end: String
}

struct RegisterWidgetTask: Codable {
  let id: String
  let title: String
  let subject: String
  let date: String
  let isTest: Bool
}

struct RegisterWidgetPeriod {
  let title: String
  let room: String
  let start: Date
  let end: Date
  func isCurrent(at date: Date) -> Bool { start <= date && date < end }
}

enum RegisterSchoolClock {
  static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
    return calendar
  }

  static func formatter(_ format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = format
    formatter.isLenient = false
    return formatter
  }

  static func parse(_ value: String) -> Date? {
    formatter(value.count == 10 ? "yyyy-MM-dd" : "yyyy-MM-dd'T'HH:mm").date(from: value)
  }

  static func dayKey(_ date: Date) -> String { formatter("yyyy-MM-dd").string(from: date) }
  static func time(_ date: Date) -> String { formatter("HH:mm").string(from: date) }

  static func dayLabel(_ date: Date, language: String) -> String {
    let formatter = formatter("EEE d MMM")
    formatter.locale = Locale(identifier: language)
    return formatter.string(from: date)
  }
}

enum RegisterWidgetStore {
  static var directory: URL? {
    guard let group = Bundle.main.object(forInfoDictionaryKey: "RegisterAppGroup") as? String else { return nil }
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
  }

  static func load(from directory: URL? = directory) -> RegisterWidgetSnapshot? {
    guard let directory,
          let data = try? Data(contentsOf: directory.appendingPathComponent("agenda-v1.json")) else { return nil }
    return try? RegisterWidgetSnapshot.decode(data)
  }

  static func save(_ data: Data, in directory: URL) throws {
    _ = try RegisterWidgetSnapshot.decode(data)
    let url = directory.appendingPathComponent("agenda-v1.json")
    #if os(iOS)
    try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    #else
    try data.write(to: url, options: .atomic)
    #endif
  }

  static func clear(in directory: URL) throws {
    let file = directory.appendingPathComponent("agenda-v1.json")
    if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
  }
}

struct RegisterWidgetStrings {
  let language: String
  func text(_ english: String, _ italian: String, _ german: String) -> String {
    switch language { case "it": return italian; case "de": return german; default: return english }
  }
  var now: String { text("Now", "Ora", "Jetzt") }
  var next: String { text("Next lesson", "Prossima lezione", "Nächste Stunde") }
  var shortNext: String { text("Next", "Prossima", "Nächste") }
  var today: String { text("Today", "Oggi", "Heute") }
  var tomorrow: String { text("Tomorrow", "Domani", "Morgen") }
  var deadlines: String { text("Deadlines", "Scadenze", "Fälligkeiten") }
  var noLessons: String { text("No more lessons today", "Lezioni terminate per oggi", "Heute keine weiteren Stunden") }
  var noTasks: String { text("No upcoming tasks", "Nessun compito in scadenza", "Keine anstehenden Aufgaben") }
  var viewTimetable: String { text("View your timetable in Register", "Vedi l’orario in Register", "Stundenplan in Register ansehen") }
  var open: String { text("Open Register to load your schedule", "Apri Register per caricare l’orario", "Register öffnen, um den Stundenplan zu laden") }
  var saved: String { text("Saved data · open to refresh", "Dati salvati · apri per aggiornare", "Gespeichert · zum Aktualisieren öffnen") }
  var test: String { text("Test", "Verifica", "Test") }
  func room(_ value: String) -> String { text("Room \(value)", "Aula \(value)", "Raum \(value)") }
}
