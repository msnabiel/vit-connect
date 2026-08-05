# Academic UI Upgrade Plan

## Goal

Make Attendance and Marks useful at a glance while keeping the existing semester switching, refresh, and detailed drill-down behavior.

## Attendance

- Add an at-a-glance summary with overall percentage, attended/total classes, target threshold, and status.
- Show the attendance target from Personalization settings instead of hard-coding 75% in the UI.
- Add filters for All, At risk, and Critical courses.
- Sort filtered courses by lowest attendance first so action items appear at the top.
- Preserve course-level skip guidance and detailed attendance cards.
- Keep privacy masking available for the overall summary.

## Marks

- Add a summary with average assessment percentage, strongest course, and weakest course.
- Add a Swift Charts course comparison for quick visual scanning.
- Preserve the semester picker and expandable assessment rows below the overview.
- Keep class-average editing and weightage calculations unchanged.
- Use stable chart identity and VoiceOver summaries.

## UX constraints

- Keep Exam Schedule and Event hub as separate Profile destinations.
- Use native SwiftUI controls and Dynamic Type-friendly layouts.
- Avoid adding a second network request solely for presentation.
- Do not expose sensitive profile or portal values in the academic dashboards.

## Verification

- Swift parse check
- `git diff --check`
- Device-SDK build when the local Xcode plugin/CoreSimulator services are available
