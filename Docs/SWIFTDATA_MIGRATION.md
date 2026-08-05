# SwiftData migration plan

## Current state

VIT Connect currently persists VTOP data as JSON files in Application Support. Courses, timetable, marks, and cumulative marks have semester-keyed dictionaries; attendance, exams, and marks reports are still single latest-value snapshots.

The app now adds `VTOPSwiftDataStore` as a durable, queryable layer. Existing JSON remains the fallback while the migration is validated.

## First migration phase

- Create one `VTOPSemesterSnapshotRecord` per semester ID.
- Encode existing value-type arrays into model `Data` fields to avoid a risky rewrite of every VTOP model.
- Import existing semester-keyed JSON records once.
- Upsert the selected semester after each successful cache persistence.
- Keep credentials in Keychain and settings in UserDefaults/AppStorage.

## Next phases

1. Add a `dataVersion` and freshness metadata to each snapshot.
2. Read semester data from SwiftData first, then fall back to JSON.
3. Split frequently queried entities into SwiftData models with stable identities.
4. Add predicates for course search, attendance filters, grade history, and reminders.
5. Remove the legacy JSON cache after migration and recovery tests pass.

## Important behavior

The app must only create records for semesters actually fetched. The semester picklist is not proof that a student attended every listed term. A full sync still fetches the selected semester only; an explicit all-semesters sync should be added later with rate-limit protection.
