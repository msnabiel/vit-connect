import SwiftUI

struct DebugConsoleView: View {
    @State private var logs: [VTOPLogger.LogEntry] = []
    @State private var autoScroll = true
    @State private var filterLevel: VTOPLogger.LogLevel? = nil

    var filteredLogs: [VTOPLogger.LogEntry] {
        if let filter = filterLevel {
            return logs.filter { $0.level == filter }
        }
        return logs
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(title: "All", isSelected: filterLevel == nil) {
                            filterLevel = nil
                        }

                        FilterChip(title: "🔍 Debug", isSelected: filterLevel == .debug) {
                            filterLevel = .debug
                        }

                        FilterChip(title: "ℹ️ Info", isSelected: filterLevel == .info) {
                            filterLevel = .info
                        }

                        FilterChip(title: "⚠️ Warning", isSelected: filterLevel == .warning) {
                            filterLevel = .warning
                        }

                        FilterChip(title: "❌ Error", isSelected: filterLevel == .error) {
                            filterLevel = .error
                        }

                        FilterChip(title: "✅ Success", isSelected: filterLevel == .success) {
                            filterLevel = .success
                        }
                    }
                    .padding()
                }
                .background(Color(uiColor: .secondarySystemBackground))

                Divider()

                // Logs List
                ScrollViewReader { proxy in
                    List {
                        ForEach(filteredLogs) { log in
                            LogEntryRow(log: log)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .id(log.id)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: logs.count) {
                        if autoScroll, let lastLog = filteredLogs.last {
                            withAnimation {
                                proxy.scrollTo(lastLog.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Info Bar
                HStack {
                    Text("\(filteredLogs.count) logs")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Toggle(isOn: $autoScroll) {
                        Text("Auto-scroll")
                            .font(.caption)
                    }
                    .toggleStyle(.switch)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
            }
            .navigationTitle("Debug Console")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: refreshLogs) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }

                        Button(action: clearLogs) {
                            Label("Clear", systemImage: "trash")
                        }

                        Button(action: exportLogs) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Debug console actions")
                }
            }
        }
        .onAppear {
            refreshLogs()
        }
        .task {
            while !Task.isCancelled {
                refreshLogs()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func refreshLogs() {
        logs = VTOPLogger.shared.getAllLogs()
    }

    private func clearLogs() {
        VTOPLogger.shared.clearLogs()
        logs = []
    }

    private func exportLogs() {
        let logText = logs.map { log in
            let codeString = log.errorCode.map { " [Code: \($0)]" } ?? ""
            let contextString = log.context.isEmpty ? "" : " [\(log.context)]"
            return "\(log.formattedTimestamp) \(log.level.rawValue)\(contextString)\(codeString): \(log.message)"
        }.joined(separator: "\n")

        let activityVC = UIActivityViewController(activityItems: [logText], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - Log Entry Row
struct LogEntryRow: View {
    let log: VTOPLogger.LogEntry

    var levelColor: Color {
        switch log.level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Text(log.formattedTimestamp)
                    .vtopFont(size: 11, weight: .medium, design: .monospaced)
.foregroundStyle(.secondary)

                Text(log.emoji)
                    .vtopFont(size: 12)
                Text(log.level.rawValue)
                    .vtopFont(size: 11, weight: .bold)
.foregroundStyle(levelColor)

                if !log.context.isEmpty {
                    Text("[\(log.context)]")
                        .vtopFont(size: 11, weight: .medium)
.foregroundStyle(.secondary)
                }

                if let code = log.errorCode {
                    Text("[Code: \(code)]")
                        .vtopFont(size: 11, weight: .medium)
.foregroundStyle(.red)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 4))
                }

                Spacer()
            }

            // Message
            Text(log.message)
                .vtopFont(size: 13, design: .monospaced)
.foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .vtopFont(size: 14, weight: isSelected ? .semibold : .regular)
.foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(uiColor: .tertiarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DebugConsoleView()
}
