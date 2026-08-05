import SwiftUI

struct ChessGameView: View {
    @ObservedObject private var session: LocalGameSession
    @StateObject private var game = ChessGameModel()
    @State private var selectedSquare: Int?
    @State private var promotionSquare: PromotionSquare?
    @State private var showResetConfirmation = false
    @State private var lastRemoteRevision = -1
    @State private var currentGameID: UUID?
    @AppStorage("chessBoardTheme") private var boardThemeRaw = ChessBoardTheme.classic.rawValue

    private let displaySquares = (0..<8).reversed().flatMap { rank in (0..<8).map { rank * 8 + $0 } }

    init(session: LocalGameSession) {
        _session = ObservedObject(wrappedValue: session)
    }

    private var legalTargets: Set<Int> {
        guard let selectedSquare else { return [] }
        return Set(game.position.legalMoves(from: selectedSquare).map { $0.to })
    }

    private var statusText: String {
        if let result = game.position.result {
            switch result {
            case .checkmate(let winner): return "Checkmate — \(winner.displayName) wins"
            case .stalemate: return "Stalemate — draw"
            }
        }
        let turnText = game.position.isInCheck ? "\(game.position.turn.displayName) is in check" : "\(game.position.turn.displayName) to move"
        guard !session.connectedPeers.isEmpty else { return turnText }
        return game.position.turn == localColor ? "Your turn — \(turnText)" : "Opponent’s turn — \(turnText)"
    }

    private var localColor: ChessColor { session.isHosting ? .white : .black }
    private var isMultiplayer: Bool { !session.connectedPeers.isEmpty }
    private var boardTheme: ChessBoardTheme {
        ChessBoardTheme(rawValue: boardThemeRaw) ?? .classic
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Label(statusText, systemImage: game.position.isInCheck ? "exclamationmark.triangle.fill" : "circle.fill")
                        .font(.headline)
                        .foregroundStyle(game.position.isInCheck ? .orange : .primary)
                    Spacer()
                    Text("\(game.position.moveHistory.count) moves")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                ChessBoardView(
                    position: game.position,
                    selectedSquare: selectedSquare,
                    legalTargets: legalTargets,
                    theme: boardTheme,
                    onTap: handleTap
                )

                HStack(spacing: 12) {
                    Button("Undo", systemImage: "arrow.uturn.backward") {
                        game.undo()
                        sendCurrentPosition()
                        selectedSquare = nil
                    }
                    .buttonStyle(.bordered)
                    .disabled(game.position.moveHistory.isEmpty)

                    Button("New game", systemImage: "arrow.clockwise") {
                        showResetConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text("Tap a piece, then tap a highlighted square. Castling, en passant, check, promotion, checkmate, and stalemate are supported.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Chess")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(ChessBoardTheme.allCases) { theme in
                        Button {
                            boardThemeRaw = theme.rawValue
                        } label: {
                            Label(theme.name, systemImage: theme == boardTheme ? "checkmark" : theme.icon)
                        }
                    }
                } label: {
                    Label("Board theme", systemImage: "paintpalette")
                }
                .accessibilityLabel("Choose board theme")
            }
        }
        .confirmationDialog("Start a new game?", isPresented: $showResetConfirmation) {
            Button("New game", role: .destructive) {
                game.reset()
                session.beginNewMatch()
                lastRemoteRevision = -1
                sendCurrentPosition()
                selectedSquare = nil
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $promotionSquare) { square in
            PromotionPicker(color: game.position.turn) { piece in
                if game.move(from: square.from, to: square.to, promotion: piece) {
                    sendCurrentPosition()
                }
                promotionSquare = nil
                selectedSquare = nil
            }
            .presentationDetents([.height(190)])
        }
        .onChange(of: session.lastReceivedMessage?.id) {
            guard let received = session.lastReceivedMessage,
                  received.message.kind == .roomState,
                  let position = try? JSONDecoder().decode(ChessPosition.self, from: received.message.payload) else { return }
            if let gameID = received.message.gameID, gameID != currentGameID {
                currentGameID = gameID
                session.adoptRoomID(gameID)
                lastRemoteRevision = -1
            }
            guard (received.message.revision ?? 0) >= lastRemoteRevision else { return }
            lastRemoteRevision = received.message.revision ?? position.moveHistory.count
            game.replace(with: position)
            selectedSquare = nil
        }
        .onAppear {
            if session.isHosting, !session.connectedPeers.isEmpty {
                sendCurrentPosition()
            }
        }
        .sensoryFeedback(.selection, trigger: selectedSquare)
    }

    private func handleTap(_ square: Int) {
        guard game.position.result == nil else { return }
        if isMultiplayer, game.position.turn != localColor { return }
        if let selectedSquare {
            if legalTargets.contains(square) {
                let moves = game.position.legalMoves(from: selectedSquare).filter { $0.to == square }
                if moves.contains(where: { $0.promotion != nil }) {
                    promotionSquare = PromotionSquare(from: selectedSquare, to: square)
                } else {
                    if game.move(from: selectedSquare, to: square) {
                        sendCurrentPosition()
                    }
                    self.selectedSquare = nil
                }
                return
            }
            if game.position.board[square]?.color == game.position.turn {
                self.selectedSquare = square
                return
            }
            self.selectedSquare = nil
        } else if game.position.board[square]?.color == game.position.turn {
            selectedSquare = square
        }
    }

    private func sendCurrentPosition() {
        guard !session.connectedPeers.isEmpty else { return }
        session.send(game.position, kind: .roomState, revision: game.position.moveHistory.count)
    }
}

private struct ChessBoardView: View {
    let position: ChessPosition
    let selectedSquare: Int?
    let legalTargets: Set<Int>
    let theme: ChessBoardTheme
    let onTap: (Int) -> Void

    private let displaySquares = (0..<8).reversed().flatMap { rank in (0..<8).map { rank * 8 + $0 } }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 8), spacing: 0) {
            ForEach(displaySquares, id: \.self) { square in
                Button { onTap(square) } label: {
                    ZStack {
                        Rectangle()
                            .fill(theme.squareColor(isLight: isLight(square)))
                        if selectedSquare == square {
                            Rectangle().fill(Color.yellow.opacity(0.38))
                        }
                        if legalTargets.contains(square) {
                            Circle()
                                .fill(position.board[square] == nil ? Color.black.opacity(0.18) : Color.red.opacity(0.58))
                                .frame(width: position.board[square] == nil ? 14 : 40, height: position.board[square] == nil ? 14 : 40)
                        }
                        if let piece = position.board[square] {
                            Text(piece.displaySymbol)
                                .font(.system(size: 34, weight: .regular, design: .serif))
                                .foregroundStyle(theme.pieceColor(for: piece.color))
                                .shadow(color: theme.pieceShadow(for: piece.color), radius: 1.5, y: 1)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: square))
                .accessibilityHint("Double tap to select or move")
            }
        }
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

    private func isLight(_ square: Int) -> Bool {
        let file = square % 8
        let rank = square / 8
        return (file + rank).isMultiple(of: 2)
    }

    private func accessibilityLabel(for square: Int) -> String {
        let file = String(UnicodeScalar(97 + square % 8)!)
        let rank = "\(square / 8 + 1)"
        if let piece = position.board[square] { return "\(piece.color.displayName) \(piece.type.rawValue) at \(file)\(rank)" }
        return "Empty square at \(file)\(rank)"
    }
}

private enum ChessBoardTheme: String, CaseIterable, Identifiable {
    case classic
    case midnight
    case forest
    case rose

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .classic: "square.grid.3x3"
        case .midnight: "moon.stars.fill"
        case .forest: "leaf.fill"
        case .rose: "wand.and.stars"
        }
    }

    func squareColor(isLight: Bool) -> Color {
        switch self {
        case .classic:
            return isLight ? Color(red: 0.92, green: 0.86, blue: 0.74) : Color(red: 0.42, green: 0.28, blue: 0.18)
        case .midnight:
            return isLight ? Color(red: 0.34, green: 0.39, blue: 0.50) : Color(red: 0.12, green: 0.15, blue: 0.23)
        case .forest:
            return isLight ? Color(red: 0.77, green: 0.84, blue: 0.70) : Color(red: 0.20, green: 0.36, blue: 0.27)
        case .rose:
            return isLight ? Color(red: 0.94, green: 0.79, blue: 0.80) : Color(red: 0.48, green: 0.24, blue: 0.30)
        }
    }

    func pieceColor(for color: ChessColor) -> Color {
        color == .white ? .white : .black
    }

    func pieceShadow(for color: ChessColor) -> Color {
        color == .white ? .black.opacity(0.72) : .white.opacity(0.32)
    }
}

private struct PromotionSquare: Identifiable {
    let from: Int
    let to: Int
    var id: String { "\(from)-\(to)" }
}

private struct PromotionPicker: View {
    let color: ChessColor
    let onPick: (ChessPieceType) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Promote pawn")
                .font(.headline)
            HStack(spacing: 14) {
                ForEach([ChessPieceType.queen, .rook, .bishop, .knight], id: \.self) { piece in
                    Button {
                        onPick(piece)
                    } label: {
                        Text(color == .white ? piece.whiteSymbol : piece.symbol)
                            .font(.system(size: 38))
                            .foregroundStyle(color == .white ? .black : .white)
                            .frame(width: 54, height: 54)
                            .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(piece.rawValue.capitalized)
                }
            }
        }
        .padding(20)
    }
}
