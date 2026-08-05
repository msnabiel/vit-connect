import Foundation
import ActivityKit

enum VTOPLiveActivityManager {
    private static var currentActivity: Activity<VTOPClassActivityAttributes>?

    @MainActor
    static func updateOrStart(upcoming: VTOPUpcomingSlot?) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            endIfNeeded()
            return
        }

        guard let u = upcoming else {
            endIfNeeded()
            return
        }

        let minutes = max(0, Int(u.startDate.timeIntervalSince(Date()) / 60))
        guard minutes <= 90 else {
            endIfNeeded()
            return
        }

        let state = VTOPClassActivityAttributes.ContentState(
            startsInMinutes: minutes,
            venue: u.course.venue,
            courseTitle: u.course.title
        )
        let content = ActivityContent(state: state, staleDate: u.endDate)

        if let activity = currentActivity {
            Task { await activity.update(content) }
            return
        }

        endIfNeeded()
        let attr = VTOPClassActivityAttributes(slotStart: u.startDate)
        do {
            currentActivity = try Activity.request(attributes: attr, content: content, pushType: nil)
        } catch {
            currentActivity = nil
        }
    }

    @MainActor
    static func endIfNeeded() {
        guard #available(iOS 16.2, *) else { return }
        if let a = currentActivity {
            Task {
                await a.end(nil, dismissalPolicy: .immediate)
            }
            currentActivity = nil
        }
    }
}
