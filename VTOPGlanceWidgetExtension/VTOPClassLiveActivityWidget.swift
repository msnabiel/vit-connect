import ActivityKit
import SwiftUI
import WidgetKit

struct VTOPClassLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VTOPClassActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Next class").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(context.state.courseTitle).font(.headline).lineLimit(1)
                    Text(context.state.venue.isEmpty ? "Starting soon" : context.state.venue)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(context.state.startsInMinutes == 0 ? "Now" : "\(context.state.startsInMinutes)m")
                    .font(.title3.monospacedDigit().weight(.bold))
            }
            .padding(16)
            .activityBackgroundTint(.blue.opacity(0.12))
            .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Image(systemName: "calendar.badge.clock") }
                DynamicIslandExpandedRegion(.center) { Text(context.state.courseTitle).lineLimit(1) }
                DynamicIslandExpandedRegion(.trailing) { Text("\(context.state.startsInMinutes)m").monospacedDigit() }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.venue.isEmpty ? "Class starting soon" : context.state.venue)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "calendar")
            } compactTrailing: {
                Text("\(context.state.startsInMinutes)m").monospacedDigit()
            } minimal: {
                Image(systemName: "calendar.badge.clock")
            }
        }
    }
}
