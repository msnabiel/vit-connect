# Home UX Feature TODO

## Implemented in this pass

- Replace the greeting-only hero with a Today card showing the next class, next exam, attendance status, and sync freshness.
- Add native SwiftUI skeleton placeholders for Home while initial academic data is unavailable.
- Add a global academic search sheet for courses, marks, exams, and events.
- Add grade-target tracking with a saved CGPA goal and remaining-credit calculation.

## Follow-up ideas

- Add an interactive Lock Screen widget for the next class.
- Add a shareable academic summary card.
- Add Focus-mode notification presets for exam weeks.
- Add server-backed assignment/event reminders once VTOP exposes stable due-date data.

## Constraints

- Prefer native SwiftUI, Charts, WidgetKit, App Intents, and TipKit before adding third-party packages.
- Use package dependencies only for a concrete gap, not for decorative UI.
- Keep sensitive portal and profile values out of search results and widgets.
