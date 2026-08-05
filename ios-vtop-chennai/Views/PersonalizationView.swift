import SwiftUI

struct PersonalizationView: View {
    @EnvironmentObject private var dataManager: DataManager
    @AppStorage(VTOPPersonalizationPreferences.appearanceKey) private var appearanceRaw = VTOPPersonalizationPreferences.Appearance.system.rawValue
    @AppStorage(VTOPPersonalizationPreferences.accentKey) private var accentRaw = VTOPPersonalizationPreferences.Accent.blue.rawValue
    @AppStorage(VTOPPersonalizationPreferences.dashboardLayoutKey) private var layoutRaw = VTOPPersonalizationPreferences.DashboardLayout.standard.rawValue
    @AppStorage(VTOPPersonalizationPreferences.attendanceThresholdKey) private var attendanceThreshold = 75
    @AppStorage(VTOPPersonalizationPreferences.showPercentagesKey) private var showPercentages = true
    @AppStorage(VTOPPersonalizationPreferences.quietHoursEnabledKey) private var quietHoursEnabled = false
    @AppStorage(VTOPPersonalizationPreferences.quietHoursStartKey) private var quietHoursStart = 22
    @AppStorage(VTOPPersonalizationPreferences.quietHoursEndKey) private var quietHoursEnd = 7
    @AppStorage(VTOPPersonalizationPreferences.classLeadMinutesKey) private var classLeadMinutes = 15
    @AppStorage(VTOPPersonalizationPreferences.appLockEnabledKey) private var appLockEnabled = false
    @AppStorage(VTOPPersonalizationPreferences.visibleCardsKey) private var visibleCardsRaw = VTOPPersonalizationPreferences.DashboardCard.allCases.map(\.rawValue).joined(separator: ",")

    private var appearance: Binding<VTOPPersonalizationPreferences.Appearance> {
        Binding(get: { .init(rawValue: appearanceRaw) ?? .system }, set: { appearanceRaw = $0.rawValue })
    }
    private var accent: Binding<VTOPPersonalizationPreferences.Accent> {
        Binding(get: { .init(rawValue: accentRaw) ?? .blue }, set: { accentRaw = $0.rawValue })
    }
    private var layout: Binding<VTOPPersonalizationPreferences.DashboardLayout> {
        Binding(get: { .init(rawValue: layoutRaw) ?? .standard }, set: { layoutRaw = $0.rawValue })
    }
    private var visibleCards: Binding<Set<VTOPPersonalizationPreferences.DashboardCard>> {
        Binding(
            get: { Set(visibleCardsRaw.split(separator: ",").compactMap { VTOPPersonalizationPreferences.DashboardCard(rawValue: String($0)) }) },
            set: { visibleCardsRaw = $0.map(\.rawValue).joined(separator: ",") }
        )
    }

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: appearance) {
                    ForEach(VTOPPersonalizationPreferences.Appearance.allCases) { Text($0.title).tag($0) }
                }
                Picker("Accent color", selection: accent) {
                    ForEach(VTOPPersonalizationPreferences.Accent.allCases) { value in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(value.color)
                                .frame(width: 18, height: 18)
                            Text(value.title)
                        }
                        .tag(value)
                    }
                }
            }

            Section {
                Picker("Dashboard layout", selection: layout) {
                    ForEach(VTOPPersonalizationPreferences.DashboardLayout.allCases) { Text($0.title).tag($0) }
                }
                ForEach(VTOPPersonalizationPreferences.DashboardCard.allCases) { card in
                    Toggle(isOn: Binding(
                        get: { visibleCards.wrappedValue.contains(card) },
                        set: { isVisible in
                            var cards = visibleCards.wrappedValue
                            if isVisible { cards.insert(card) } else { cards.remove(card) }
                            visibleCards.wrappedValue = cards
                        }
                    )) {
                        Label(card.title, systemImage: card.symbol)
                    }
                }
            } header: {
                Text("Home dashboard")
            } footer: {
                Text("Hide cards you do not use. Your choices apply immediately.")
            }

            Section("Academic display") {
                Stepper("Attendance warning at (attendanceThreshold)%", value: $attendanceThreshold, in: 50...100, step: 5)
                Toggle("Show percentages", isOn: $showPercentages)
                Text("Attendance below this threshold is marked at risk on the dashboard and in notifications.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Notification timing") {
                Picker("Class reminder", selection: $classLeadMinutes) {
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                }
                Toggle("Quiet hours", isOn: $quietHoursEnabled)
                if quietHoursEnabled {
                    DatePicker("Quiet hours start", selection: hourBinding($quietHoursStart), displayedComponents: .hourAndMinute)
                    DatePicker("Quiet hours end", selection: hourBinding($quietHoursEnd), displayedComponents: .hourAndMinute)
                }
                Text("Quiet hours prevent local alerts from being scheduled during the selected window.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Toggle(isOn: $appLockEnabled) {
                    Label("Require Face ID / passcode", systemImage: "faceid")
                }
                .disabled(!VTOPBiometricLock.isAvailable())
                Text(VTOPBiometricLock.isAvailable()
                     ? "Lock VIT Connect whenever it returns from the background."
                     : "A device passcode or biometric method is required to use app lock.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Personalization")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: quietHoursEnabled) { _, _ in deferNotificationRefresh() }
        .onChange(of: quietHoursStart) { _, _ in deferNotificationRefresh() }
        .onChange(of: quietHoursEnd) { _, _ in deferNotificationRefresh() }
        .onChange(of: classLeadMinutes) { _, _ in deferNotificationRefresh() }
        .onChange(of: attendanceThreshold) { _, _ in deferNotificationRefresh() }
    }

    private func hourBinding(_ hour: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: hour.wrappedValue, minute: 0)) ?? .now },
            set: { hour.wrappedValue = Calendar.current.component(.hour, from: $0) }
        )
    }

    private func deferNotificationRefresh() {
        Task { @MainActor in
            await Task.yield()
            dataManager.refreshNotificationSchedule()
        }
    }
}

#Preview {
    NavigationStack { PersonalizationView().environmentObject(DataManager()) }
}
