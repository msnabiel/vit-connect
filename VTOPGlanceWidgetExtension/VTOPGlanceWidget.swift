import WidgetKit
import SwiftUI

// MARK: - Snapshot DTO (matches `VTOPGlanceSnapshot` JSON from the main app)

private struct GlanceSnapshotDTO: Codable {
    var updatedAt: Date
    var semesterName: String?
    var attendancePercent: Int?
    var nextClassTitle: String?
    var nextClassVenue: String?
    var nextClassStart: Date?
    var nextClassEnd: Date?
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

private struct GlanceEntry: TimelineEntry {
    let date: Date
    let snapshot: GlanceSnapshotDTO?
}

private struct GlanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlanceEntry {
        GlanceEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (GlanceEntry) -> Void) {
        completion(GlanceEntry(date: Date(), snapshot: GlanceSnapshotDTO.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GlanceEntry>) -> Void) {
        let entry = GlanceEntry(date: Date(), snapshot: GlanceSnapshotDTO.load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

private struct GlanceWidgetView: View {
    var entry: GlanceProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VTOP")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            if let s = entry.snapshot {
                if let t = s.nextClassTitle, !t.isEmpty {
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
                if let p = s.attendancePercent {
                    Text("Attendance \(p)%")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
        StaticConfiguration(kind: kind, provider: GlanceProvider()) { entry in
            GlanceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("VTOP Glance")
        .description("Next class and highlights from your last sync.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct VTOPGlanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        VTOPGlanceWidget()
    }
}
