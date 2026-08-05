import SwiftUI

struct GamesView: View {
    @State private var selectedGame: GameChoice?
    @StateObject private var chessSession = LocalGameSession()
    @StateObject private var ticTacToeSession = LocalGameSession()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quick games to play with friends nearby — no account or backend required.")
                            .foregroundStyle(.secondary)
                    }

                    NearbyGameCard()

                    Text("Choose a game")
                        .font(.title3.weight(.bold))

                    ForEach(GameChoice.allCases) { game in
                        Button { selectedGame = game } label: {
                            HStack(spacing: 14) {
                                Image(systemName: game.symbol)
                                    .font(.title2)
                                    .foregroundStyle(game.color)
                                    .frame(width: 46, height: 46)
                                    .background(game.color.opacity(0.12), in: .rect(cornerRadius: 13))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(game.title).font(.headline)
                                    Text(game.subtitle).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .background(.background, in: .rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Games")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedGame) { game in
                switch game {
                case .ticTacToe: TicTacToeView(session: ticTacToeSession)
                case .quiz: QuizDuelView()
                case .chess: ChessGameView(session: chessSession)
                }
            }
        }
    }
}

private struct NearbyGameCard: View {
    @State private var showRoom = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Nearby play", systemImage: "dot.radiowaves.left.and.right")
                .font(.headline)
            Text("Create or join a room using nearby Wi‑Fi or Bluetooth. The host keeps a local snapshot so a short suspension does not erase the match.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label("No global matchmaking or persistent rooms yet", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("Create or join nearby room", systemImage: "person.2.wave.2.fill") {
                showRoom = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.10), in: .rect(cornerRadius: 18))
        .sheet(isPresented: $showRoom) {
            NearbyRoomView()
        }
    }
}

private struct NearbyRoomView: View {
    @StateObject private var session = LocalGameSession()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Host a room", systemImage: "antenna.radiowaves.left.and.right") {
                        session.startHosting()
                    }
                    Button("Find nearby rooms", systemImage: "magnifyingglass") {
                        session.startBrowsing()
                    }
                } footer: {
                    Text("Nearby discovery uses Bluetooth and Wi‑Fi. Keep this screen open while inviting friends.")
                }

                Section("Room status") {
                    Label(
                        session.isConnecting ? "Connecting…" : (session.isHosting ? "Hosting this device" : (session.isBrowsing ? "Looking for nearby rooms" : "Not discovering")),
                        systemImage: session.isConnecting ? "arrow.triangle.2.circlepath" : (session.isHosting ? "antenna.radiowaves.left.and.right" : "magnifyingglass")
                    )
                    Text("Room \(session.roomID.uuidString.prefix(8))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                if !session.nearbyPeers.isEmpty {
                    Section("Nearby rooms") {
                        ForEach(session.nearbyPeers, id: \.self) { peer in
                            Button {
                                session.invite(peer)
                            } label: {
                                Label(peer.displayName, systemImage: "person.crop.circle.badge.plus")
                            }
                        }
                    }
                }

                if !session.connectedPeers.isEmpty {
                    Section("Ready to play") {
                        NavigationLink {
                            ChessGameView(session: session)
                        } label: {
                            Label("Start Chess match", systemImage: "checkerboard.rectangle")
                        }
                        NavigationLink {
                            TicTacToeView(session: session)
                        } label: {
                            Label("Start Tic-Tac-Toe match", systemImage: "square.grid.3x3.fill")
                        }
                    }
                }

                Section("Connected") {
                    if session.connectedPeers.isEmpty {
                        Text("No players connected yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(session.connectedPeers, id: \.self) { peer in
                            Label(peer.displayName, systemImage: "checkmark.circle.fill")
                        }
                    }
                }
            }
            .navigationTitle("Nearby Room")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        session.stop()
                        dismiss()
                    }
                }
            }
            .alert("Nearby games", isPresented: Binding(
                get: { session.errorMessage != nil },
                set: { if !$0 { session.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { session.errorMessage = nil }
            } message: {
                Text(session.errorMessage ?? "")
            }
        }
    }
}

private enum GameChoice: String, CaseIterable, Identifiable {
    case ticTacToe, quiz, chess
    var id: String { rawValue }
    var title: String { switch self { case .ticTacToe: "Tic-Tac-Toe"; case .quiz: "VIT Quiz Duel"; case .chess: "Chess" } }
    var subtitle: String { switch self { case .ticTacToe: "A quick two-player classic"; case .quiz: "Challenge a friend with course questions"; case .chess: "Turn-based campus chess" } }
    var symbol: String { switch self { case .ticTacToe: "square.grid.3x3.fill"; case .quiz: "questionmark.bubble.fill"; case .chess: "checkerboard.rectangle" } }
    var color: Color { switch self { case .ticTacToe: .blue; case .quiz: .orange; case .chess: .purple } }
}

private struct ComingSoonGameView: View {
    let game: GameChoice
    var body: some View {
        ContentUnavailableView(game.title, systemImage: game.symbol, description: Text("The nearby multiplayer room protocol is ready. This game is coming next."))
            .navigationTitle(game.title)
    }
}

private struct QuizDuelView: View {
    private let questions = Array(nptelCourses.flatMap { $0.questionsByWeek.values }.joined()).prefix(20)
    @State private var index = 0
    @State private var score = 0
    @State private var selectedAnswer: String?
    @State private var finished = false

    private var question: NPTELQuestion? { questions.indices.contains(index) ? questions[index] : nil }

    var body: some View {
        Group {
            if finished {
                ContentUnavailableView("Duel complete", systemImage: "trophy.fill", description: Text("You scored \(score) out of \(questions.count)."))
            } else if let question {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Question \(index + 1) of \(questions.count)").font(.subheadline.weight(.semibold))
                            Spacer()
                            Label("\(score)", systemImage: "star.fill").foregroundStyle(.orange)
                        }
                        ProgressView(value: Double(index), total: Double(max(questions.count, 1)))
                        Text(question.question).font(.title3.weight(.bold))
                        ForEach(question.options, id: \.self) { option in
                            Button {
                                answer(option, for: question)
                            } label: {
                                HStack {
                                    Text(option).multilineTextAlignment(.leading)
                                    Spacer()
                                    if selectedAnswer == option {
                                        Image(systemName: option == question.answer ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background((selectedAnswer == option ? (option == question.answer ? Color.green : Color.red) : Color.primary).opacity(0.10), in: .rect(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedAnswer != nil)
                        }
                        if selectedAnswer != nil {
                            Button(index + 1 == questions.count ? "Finish" : "Next question", systemImage: "arrow.right") {
                                index += 1
                                selectedAnswer = nil
                                if index >= questions.count { finished = true }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("VIT Quiz Duel")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func answer(_ option: String, for question: NPTELQuestion) {
        selectedAnswer = option
        if option == question.answer { score += 1 }
    }
}

private struct TicTacToeState: Codable, Equatable {
    var board: [String]
    var isXTurn: Bool
    var round: Int
}

private struct TicTacToeView: View {
    @ObservedObject var session: LocalGameSession
    @State private var board = Array(repeating: "", count: 9)
    @State private var isXTurn = true
    @State private var xScore = 0
    @State private var oScore = 0
    @State private var moveCount = 0
    @State private var round = 0

    private let cellIDs = Array(0..<9)

    private var winner: String? {
        let lines = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],
            [0, 3, 6], [1, 4, 7], [2, 5, 8],
            [0, 4, 8], [2, 4, 6]
        ]
        return lines.lazy.compactMap { line in
            let values = line.map { board[$0] }
            guard !values[0].isEmpty, values.allSatisfy({ $0 == values[0] }) else { return nil }
            return values[0]
        }.first
    }

    private var isDraw: Bool { winner == nil && !board.contains(where: { $0.isEmpty }) }

    private var statusText: String {
        if let winner { return "Player \(winner) wins" }
        if isDraw { return "It’s a draw" }
        if !session.connectedPeers.isEmpty {
            let localMark = session.isHosting ? "X" : "O"
            let currentMark = isXTurn ? "X" : "O"
            return currentMark == localMark ? "Your turn — \(currentMark)" : "Opponent’s turn — \(currentMark)"
        }
        return "Player \(isXTurn ? "X" : "O")’s turn"
    }

    private func makeMove(at index: Int) {
        guard board[index].isEmpty, winner == nil, !isDraw else { return }
        if !session.connectedPeers.isEmpty {
            let localMark = session.isHosting ? "X" : "O"
            guard (isXTurn ? "X" : "O") == localMark else { return }
        }
        board[index] = isXTurn ? "X" : "O"
        moveCount += 1

        if let winner {
            if winner == "X" { xScore += 1 } else { oScore += 1 }
        } else {
            isXTurn.toggle()
        }
        sendState()
    }

    private func newRound(resetScore: Bool = false) {
        board = Array(repeating: "", count: 9)
        isXTurn = true
        if !session.connectedPeers.isEmpty { session.beginNewMatch() }
        moveCount += 1
        round += 1
        if resetScore {
            xScore = 0
            oScore = 0
        }
        sendState()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack(spacing: 10) {
                    ScorePill(player: "X", score: xScore, color: .blue)
                    Text("vs")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    ScorePill(player: "O", score: oScore, color: .orange)
                }

                Text(statusText)
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(cellIDs, id: \.self) { index in
                        Button {
                            makeMove(at: index)
                        } label: {
                            Text(board[index])
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(board[index] == "X" ? Color.blue : Color.orange)
                                .frame(maxWidth: .infinity, minHeight: 72)
                                .background(.background, in: .rect(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.08))
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(board[index].isEmpty ? "Empty square \(index + 1)" : "Square \(index + 1), \(board[index])")
                        .accessibilityHint(board[index].isEmpty ? "Double tap to place your mark" : "Occupied square")
                    }
                }

                HStack(spacing: 12) {
                    Button("New round", systemImage: "arrow.clockwise") { newRound() }
                        .buttonStyle(.borderedProminent)
                    Button("Reset score", role: .destructive) { newRound(resetScore: true) }
                        .buttonStyle(.bordered)
                }
            }
            .padding(20)
        }
        .navigationTitle("Tic-Tac-Toe")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear {
            if let savedBoard = LocalGameSnapshotStore.loadTicTacToe(), savedBoard.count == 9 {
                board = savedBoard
                isXTurn = savedBoard.filter { !$0.isEmpty }.count.isMultiple(of: 2)
            }
            if session.isHosting, !session.connectedPeers.isEmpty { sendState() }
        }
        .onChange(of: board) {
            LocalGameSnapshotStore.saveTicTacToe(board)
        }
        .onChange(of: session.lastReceivedMessage?.id) {
            guard let received = session.lastReceivedMessage,
                  received.message.kind == .roomState,
                  let state = try? JSONDecoder().decode(TicTacToeState.self, from: received.message.payload),
                  state.board.count == 9 else { return }
            board = state.board
            isXTurn = state.isXTurn
            round = state.round
            if let gameID = received.message.gameID { session.adoptRoomID(gameID) }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: moveCount)
    }

    private func sendState() {
        guard !session.connectedPeers.isEmpty else { return }
        session.send(TicTacToeState(board: board, isXTurn: isXTurn, round: round), kind: .roomState, revision: round)
    }
}

private struct ScorePill: View {
    let player: String
    let score: Int
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Text(player)
                .font(.headline.weight(.bold))
                .foregroundStyle(color)
            Text("\(score)")
                .font(.headline.monospacedDigit())
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(color.opacity(0.11), in: Capsule())
    }
}
