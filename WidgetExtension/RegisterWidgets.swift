import SwiftUI
import WidgetKit

private let violet = Color(red: 0.49, green: 0.36, blue: 1)
private let cyan = Color(red: 0.13, green: 0.83, blue: 0.93)
private let widgetBackground = Color(red: 0.04, green: 0.06, blue: 0.11)

struct RegisterEntry: TimelineEntry {
  let date: Date
  let snapshot: RegisterWidgetSnapshot?
  var strings: RegisterWidgetStrings {
    RegisterWidgetStrings(language: snapshot?.language ?? Locale.current.languageCode ?? "en")
  }
}

struct RegisterTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> RegisterEntry {
    RegisterEntry(date: .now, snapshot: Self.sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (RegisterEntry) -> Void) {
    completion(RegisterEntry(date: .now, snapshot: context.isPreview ? Self.sample : RegisterWidgetStore.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<RegisterEntry>) -> Void) {
    let now = Date()
    let snapshot = RegisterWidgetStore.load()
    // All known starts, ends, and day boundaries are precomputed. WidgetKit
    // advances the timeline while the app is closed, within its refresh budget.
    let entries = (snapshot?.timelineDates(at: now) ?? [now])
      .map { RegisterEntry(date: $0, snapshot: snapshot) }
    completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(60 * 60))))
  }

  static var sample: RegisterWidgetSnapshot {
    let start = Date().addingTimeInterval(20 * 60)
    let end = start.addingTimeInterval(45 * 60)
    let format = RegisterSchoolClock.formatter("yyyy-MM-dd'T'HH:mm")
    return RegisterWidgetSnapshot(version: 1, language: Locale.current.languageCode ?? "en",
      lastUpdated: format.string(from: Date()),
      days: [RegisterWidgetDay(date: RegisterSchoolClock.dayKey(Date()), loaded: true,
        lessons: [RegisterWidgetLesson(title: "Mathematics", room: "204",
          periods: [RegisterWidgetTime(start: format.string(from: start), end: format.string(from: end))])])],
      tasks: [RegisterWidgetTask(id: "preview", title: "Chapter 3", subject: "Mathematics",
        date: RegisterSchoolClock.dayKey(Date()), isTest: false)], tasksLoaded: true)
  }
}

private struct RegisterWidgetBackground: ViewModifier {
  @ViewBuilder func body(content: Content) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      content.containerBackground(for: .widget) { widgetBackground }
    } else {
      content.padding(16).background(widgetBackground)
    }
  }
}

struct RegisterLessonView: View {
  let entry: RegisterEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    let strings = entry.strings
    let periods = entry.snapshot?.periods(after: entry.date) ?? []
    let period = periods.first
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Label("Register", systemImage: "graduationcap.fill")
          .font(.caption.weight(.semibold)).foregroundStyle(cyan).lineLimit(1)
        Spacer(minLength: 2)
        if let period {
          Text(period.isCurrent(at: entry.date) ? strings.now :
               family == .systemSmall ? strings.shortNext : strings.next)
            .font(.caption2.weight(.bold)).foregroundStyle(cyan).lineLimit(1).minimumScaleFactor(0.8)
        }
      }
      if entry.snapshot == nil {
        Spacer(minLength: 0)
        Text(strings.open).font(.subheadline.weight(.medium))
        Spacer(minLength: 0)
      } else if let period {
        Text(period.title).font(family == .systemSmall ? .headline : .title3.bold())
          .lineLimit(1).minimumScaleFactor(0.8).privacySensitive()
        HStack(spacing: 6) {
          Image(systemName: "clock")
          if family == .systemMedium && RegisterSchoolClock.dayKey(period.start) != RegisterSchoolClock.dayKey(entry.date) {
            Text(RegisterSchoolClock.dayLabel(period.start, language: strings.language))
          }
          Text("\(RegisterSchoolClock.time(period.start))–\(RegisterSchoolClock.time(period.end))")
            .monospacedDigit()
        }.font(.caption.weight(.medium)).lineLimit(1)
        if !period.room.isEmpty {
          Label(strings.room(period.room), systemImage: "mappin.and.ellipse")
            .font(.caption).foregroundStyle(cyan).lineLimit(1).privacySensitive()
        }
        if family == .systemSmall && RegisterSchoolClock.dayKey(period.start) != RegisterSchoolClock.dayKey(entry.date) {
          Text(RegisterSchoolClock.dayLabel(period.start, language: strings.language))
            .font(.caption2).foregroundStyle(.secondary)
        }
        if family == .systemMedium, periods.count > 1 {
          Spacer(minLength: 0)
          Text("\(strings.next): \(periods[1].title) · \(RegisterSchoolClock.time(periods[1].start))")
            .font(.caption).foregroundStyle(.secondary).lineLimit(1).privacySensitive()
        }
      } else {
        Spacer(minLength: 0)
        let today = entry.snapshot?.days.first(where: { $0.date == RegisterSchoolClock.dayKey(entry.date) })
        Text(today?.loaded != true ? strings.open :
             today?.lessons.contains(where: { $0.periods.isEmpty }) == true ? strings.viewTimetable : strings.noLessons)
          .font(.headline)
        Spacer(minLength: 0)
      }
      if entry.snapshot?.isStale(at: entry.date) == true {
        Text(strings.saved).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
      }
    }
    .foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .modifier(RegisterWidgetBackground())
    .widgetURL(URL(string: "register9457://today"))
  }
}

struct RegisterDeadlinesView: View {
  let entry: RegisterEntry
  @Environment(\.widgetFamily) private var family
  var body: some View {
    let strings = entry.strings
    let tasks = entry.snapshot?.deadlines(at: entry.date) ?? []
    VStack(alignment: .leading, spacing: 8) {
      Label(strings.deadlines, systemImage: "checklist")
        .font(.caption.weight(.semibold)).foregroundStyle(cyan)
      if entry.snapshot == nil || entry.snapshot?.tasksLoaded != true {
        Spacer(minLength: 0)
        Text(strings.open).font(.subheadline)
        Spacer(minLength: 0)
      } else if tasks.isEmpty {
        Spacer(minLength: 0)
        Text(strings.noTasks).font(.headline)
        Spacer(minLength: 0)
      } else {
        ForEach(Array(tasks.prefix(family == .systemSmall ? 2 : 3)), id: \.id) { task in
          HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(task.isTest ? Color.orange : violet)
              .frame(width: 3)
            VStack(alignment: .leading, spacing: 2) {
              Text(task.title).font(.caption.weight(.semibold)).lineLimit(1).privacySensitive()
              HStack(spacing: 4) {
                if !task.subject.isEmpty { Text(task.subject).lineLimit(1).privacySensitive() }
                Spacer(minLength: 0)
                Text(task.date == RegisterSchoolClock.dayKey(entry.date) ? strings.today :
                  RegisterSchoolClock.parse(task.date).map { RegisterSchoolClock.dayLabel($0, language: strings.language) } ?? task.date)
                  .lineLimit(1)
              }.font(.system(size: 10)).foregroundStyle(.secondary)
            }
          }
        }
        Spacer(minLength: 0)
      }
      if entry.snapshot?.isStale(at: entry.date) == true {
        Text(strings.saved).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
      }
    }
    .foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .modifier(RegisterWidgetBackground())
    .widgetURL(URL(string: "register9457://tasks"))
  }
}

struct RegisterNextLessonWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "RegisterNextLesson", provider: RegisterTimelineProvider()) { RegisterLessonView(entry: $0) }
      .configurationDisplayName("Next lesson")
      .description("Your current or next lesson, time, and room.")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct RegisterTasksWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "RegisterDeadlines", provider: RegisterTimelineProvider()) { RegisterDeadlinesView(entry: $0) }
      .configurationDisplayName("Deadlines")
      .description("Upcoming tasks and tests from Register.")
      .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct RegisterWidgetBundle: WidgetBundle {
  var body: some Widget {
    RegisterNextLessonWidget()
    RegisterTasksWidget()
  }
}
