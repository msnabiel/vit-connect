import SwiftUI
import UIKit

struct StaffInformationView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab: StaffType = .proctor

    var body: some View {
        Group {
            if dataManager.staff.isEmpty {
                EmptyStateView(
                    icon: "person.3.fill",
                    message: "No staff information available"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    Picker("Role", selection: $selectedTab) {
                        Text("Proctor").tag(StaffType.proctor)
                        Text("Dean").tag(StaffType.dean)
                        Text("HoD").tag(StaffType.hod)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    ScrollView {
                        VStack(spacing: 12) {
                            leadershipPortrait

                            let staffEntries = dataManager.staff.filter { $0.type == selectedTab }

                            if dataManager.isLoading && staffEntries.isEmpty {
                                LazyVStack(spacing: 10) {
                                    ForEach(0..<4, id: \.self) { _ in
                                        SkeletonListRow()
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            } else if staffEntries.isEmpty {
                                EmptyStateView(
                                    icon: "person.fill.questionmark",
                                    message: "No \(selectedTab.rawValue.lowercased()) information available"
                                )
                                .padding(.top, 32)
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(staffEntries) { staff in
                                        StaffInfoRow(staff: staff)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                    }
                    .refreshable {
                        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                            dataManager.refreshStaffInformation { cont.resume() }
                        }
                    }
                }
            }
        }
        .navigationTitle("Staff Information")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var leadershipPortrait: some View {
        if selectedTab == .dean, let data = dataManager.deanPortraitData, let ui = UIImage(data: data) {
            portraitView(image: ui, label: "Dean")
        } else if selectedTab == .hod, let data = dataManager.hodPortraitData, let ui = UIImage(data: data) {
            portraitView(image: ui, label: "HoD")
        }
    }

    private func portraitView(image: UIImage, label: String) -> some View {
        VStack(spacing: 8) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 140, height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

struct StaffInfoRow: View {
    let staff: Staff

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForKey(staff.key))
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(staff.key)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Text(staff.value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(4)
            }

            Spacer()

            if staff.key.lowercased().contains("email") {
                if let url = URL(string: "mailto:\(staff.value)") {
                    Link(destination: url) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.accentColor.opacity(0.1))
                            )
                    }
                }
            } else if staff.key.lowercased().contains("phone") || staff.key.lowercased().contains("mobile") {
                if let url = URL(string: "tel:\(staff.value.filter { $0.isNumber })") {
                    Link(destination: url) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.accentColor.opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func iconForKey(_ key: String) -> String {
        let lowercasedKey = key.lowercased()

        if lowercasedKey.contains("name") {
            return "person.fill"
        } else if lowercasedKey.contains("email") {
            return "envelope.fill"
        } else if lowercasedKey.contains("phone") || lowercasedKey.contains("mobile") {
            return "phone.fill"
        } else if lowercasedKey.contains("cabin") || lowercasedKey.contains("office") || lowercasedKey.contains("room") {
            return "building.2.fill"
        } else if lowercasedKey.contains("department") {
            return "building.columns.fill"
        } else if lowercasedKey.contains("designation") {
            return "briefcase.fill"
        } else {
            return "info.circle.fill"
        }
    }
}

#Preview {
    NavigationStack {
        StaffInformationView()
            .environmentObject(DataManager())
    }
}
