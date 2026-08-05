import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Snapshot DTO (matches `VTOPGlanceSnapshot` JSON from the main app)

private struct GlanceSnapshotDTO: Codable {
    var updatedAt: Date
    var semesterName: String?
    var attendancePercent: Int?
    var nextClassTitle: String?
    var nextClassVenue: String?
    var nextClassStart: Date?
    var nextClassEnd: Date?
    var attendanceRiskLabel: String?
    var nextExamTitle: String?
    var nextExamDate: Date?
    var nextExamVenue: String?
    var todaySlotLines: [String]

    private static let appGroupId = "group.com.msnabiel.vit-connect"
    private static let fileName = "glance_snapshot.json"

    static func load() -> GlanceSnapshotDTO? {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }
        let url = base.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(GlanceSnapshotDTO.self, from: data)
    }
}

// MARK: - Timeline

private enum GlanceWidgetFocus: String, AppEnum, CaseIterable, Identifiable {
    case overview
    case timetable
    case attendance
    case exams

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "VIT Connect widget")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .overview: "Overview",
        .timetable: "Timetable",
        .attendance: "Attendance",
        .exams: "Exams"
    ]

    var id: Self { self }
}

private struct GlanceWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "VIT Connect widget"
    static let description = IntentDescription("Choose which academic highlight appears in the widget.")

    @Parameter(title: "Show", default: .overview)
    var focus: GlanceWidgetFocus
}

private struct GlanceEntry: TimelineEntry {
    let date: Date
    let snapshot: GlanceSnapshotDTO?
    let focus: GlanceWidgetFocus
}

private struct GlanceProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> GlanceEntry {
        GlanceEntry(date: Date(), snapshot: nil, focus: .overview)
    }

    func snapshot(for configuration: GlanceWidgetConfiguration, in context: Context) async -> GlanceEntry {
        GlanceEntry(date: Date(), snapshot: GlanceSnapshotDTO.load(), focus: configuration.focus)
    }

    func timeline(for configuration: GlanceWidgetConfiguration, in context: Context) async -> Timeline<GlanceEntry> {
        let entry = GlanceEntry(date: Date(), snapshot: GlanceSnapshotDTO.load(), focus: configuration.focus)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(next))
    }
}

// MARK: - Views

private struct GlanceWidgetView: View {
    var entry: GlanceProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VTOP")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            if let s = entry.snapshot {
                if entry.focus == .attendance, let p = s.attendancePercent {
                    Text("Attendance")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(p)%")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(s.attendanceRiskLabel ?? "Latest sync")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if entry.focus == .exams, let examTitle = s.nextExamTitle {
                    Label("Next exam", systemImage: "calendar.badge.exclamationmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(examTitle)
                        .font(.headline)
                        .lineLimit(3)
                    if let date = s.nextExamDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let t = s.nextClassTitle, !t.isEmpty {
                    Text(t)
                        .font(.headline)
                        .lineLimit(2)
                    if let v = s.nextClassVenue, !v.isEmpty {
                        Text(v)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else if let line = s.todaySlotLines.first, !line.isEmpty {
                    Text(line)
                        .font(.subheadline)
                        .lineLimit(2)
                } else {
                    Text("Sync in the app for schedule")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if entry.focus == .overview, let p = s.attendancePercent {
                    HStack(spacing: 4) {
                        Text("Attendance \(p)%")
                        if let risk = s.attendanceRiskLabel {
                            Text("· \(risk)")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                if entry.focus == .overview, let examTitle = s.nextExamTitle {
                    Label {
                        Text(examTitle)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "calendar.badge.exclamationmark")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                if (entry.focus == .overview || entry.focus == .timetable), family == .systemLarge, !s.todaySlotLines.isEmpty {
                    Divider()
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(s.todaySlotLines.prefix(4), id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            } else {
                Text("Open the app to sync data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Widget

struct VTOPGlanceWidget: Widget {
    let kind: String = "VTOPGlanceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: GlanceWidgetConfiguration.self, provider: GlanceProvider()) { entry in
            GlanceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("VTOP Glance")
        .description("Next class and highlights from your last sync.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct VTOPGlanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        VTOPGlanceWidget()
        VTOPClassLiveActivityWidget()
    }
}
