import Foundation

enum ChessColor: String, Codable, CaseIterable {
    case white
    case black

    var opposite: ChessColor { self == .white ? .black : .white }
    var displayName: String { rawValue.capitalized }
}

enum ChessPieceType: String, Codable, CaseIterable {
    case king, queen, rook, bishop, knight, pawn

    var symbol: String {
        switch self {
        case .king: "♚"
        case .queen: "♛"
        case .rook: "♜"
        case .bishop: "♝"
        case .knight: "♞"
        case .pawn: "♟"
        }
    }

    var whiteSymbol: String {
        switch self {
        case .king: "♔"
        case .queen: "♕"
        case .rook: "♖"
        case .bishop: "♗"
        case .knight: "♘"
        case .pawn: "♙"
        }
    }
}

struct ChessPiece: Codable, Equatable {
    let type: ChessPieceType
    let color: ChessColor

    var displaySymbol: String { color == .white ? type.whiteSymbol : type.symbol }
}

struct ChessMove: Codable, Equatable, Hashable {
    let from: Int
    let to: Int
    let promotion: ChessPieceType?
    let isCastle: Bool
    let isEnPassant: Bool

    init(from: Int, to: Int, promotion: ChessPieceType? = nil, isCastle: Bool = false, isEnPassant: Bool = false) {
        self.from = from
        self.to = to
        self.promotion = promotion
        self.isCastle = isCastle
        self.isEnPassant = isEnPassant
    }
}

struct ChessCastlingRights: Codable, Equatable {
    var whiteKingside = true
    var whiteQueenside = true
    var blackKingside = true
    var blackQueenside = true
}

enum ChessGameResult: Equatable {
    case checkmate(ChessColor)
    case stalemate
}

struct ChessPosition: Codable, Equatable {
    var board: [ChessPiece?]
    var turn: ChessColor = .white
    var castlingRights = ChessCastlingRights()
    var enPassantTarget: Int?
    var moveHistory: [ChessMove] = []

    init() {
        board = Array(repeating: nil, count: 64)
        let backRank: [ChessPieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for file in 0..<8 {
            board[file] = ChessPiece(type: backRank[file], color: .white)
            board[8 + file] = ChessPiece(type: .pawn, color: .white)
            board[48 + file] = ChessPiece(type: .pawn, color: .black)
            board[56 + file] = ChessPiece(type: backRank[file], color: .black)
        }
    }

    var isInCheck: Bool { isKingInCheck(for: turn) }

    var result: ChessGameResult? {
        guard legalMoves().isEmpty else { return nil }
        return isInCheck ? .checkmate(turn.opposite) : .stalemate
    }

    func legalMoves(from square: Int) -> [ChessMove] {
        guard board.indices.contains(square), let piece = board[square], piece.color == turn else { return [] }
        return pseudoMoves(from: square).filter { move in
            var next = self
            next.applyUnchecked(move)
            return !next.isKingInCheck(for: piece.color)
        }
    }

    func legalMoves() -> [ChessMove] {
        board.indices.flatMap { legalMoves(from: $0) }
    }

    mutating func move(from: Int, to: Int, promotion: ChessPieceType? = nil) -> Bool {
        let choices = legalMoves(from: from).filter { $0.to == to }
        guard !choices.isEmpty else { return false }
        let selected = choices.first(where: { $0.promotion == promotion })
            ?? choices.first(where: { $0.promotion == nil })
            ?? choices.first(where: { $0.promotion == .queen })
        guard let selected else { return false }
        applyUnchecked(selected)
        moveHistory.append(selected)
        return true
    }

    private func pseudoMoves(from square: Int) -> [ChessMove] {
        guard let piece = board[square] else { return [] }
        let file = square % 8
        let rank = square / 8
        var moves: [ChessMove] = []

        func add(_ file: Int, _ rank: Int, castle: Bool = false, enPassant: Bool = false) {
            guard (0..<8).contains(file), (0..<8).contains(rank) else { return }
            let target = rank * 8 + file
            if board[target]?.color == piece.color { return }
            moves.append(ChessMove(from: square, to: target, isCastle: castle, isEnPassant: enPassant))
        }

        switch piece.type {
        case .pawn:
            let direction = piece.color == .white ? 1 : -1
            let startRank = piece.color == .white ? 1 : 6
            let promotionRank = piece.color == .white ? 7 : 0
            let oneRank = rank + direction
            if (0..<8).contains(oneRank), board[oneRank * 8 + file] == nil {
                addPawnMove(toFile: file, toRank: oneRank, promotionRank: promotionRank, from: square, into: &moves)
                let twoRank = rank + direction * 2
                if rank == startRank, board[twoRank * 8 + file] == nil {
                    moves.append(ChessMove(from: square, to: twoRank * 8 + file))
                }
            }
            for captureFile in [file - 1, file + 1] where (0..<8).contains(captureFile) && (0..<8).contains(oneRank) {
                let target = oneRank * 8 + captureFile
                if board[target]?.color == piece.color.opposite {
                    addPawnMove(toFile: captureFile, toRank: oneRank, promotionRank: promotionRank, from: square, into: &moves)
                } else if target == enPassantTarget {
                    moves.append(ChessMove(from: square, to: target, isEnPassant: true))
                }
            }

        case .knight:
            for (df, dr) in [(1, 2), (2, 1), (-1, 2), (-2, 1), (1, -2), (2, -1), (-1, -2), (-2, -1)] {
                add(file + df, rank + dr)
            }

        case .bishop:
            addSlidingMoves(from: square, piece: piece, directions: [(1, 1), (-1, 1), (1, -1), (-1, -1)], into: &moves)

        case .rook:
            addSlidingMoves(from: square, piece: piece, directions: [(1, 0), (-1, 0), (0, 1), (0, -1)], into: &moves)

        case .queen:
            addSlidingMoves(from: square, piece: piece, directions: [(1, 1), (-1, 1), (1, -1), (-1, -1), (1, 0), (-1, 0), (0, 1), (0, -1)], into: &moves)

        case .king:
            for df in -1...1 {
                for dr in -1...1 where df != 0 || dr != 0 {
                    add(file + df, rank + dr)
                }
            }
            let homeRank = piece.color == .white ? 0 : 7
            if square == homeRank * 8 + 4 && !isKingInCheck(for: piece.color) {
                let kingside = piece.color == .white ? castlingRights.whiteKingside : castlingRights.blackKingside
                let queenside = piece.color == .white ? castlingRights.whiteQueenside : castlingRights.blackQueenside
                if kingside && board[homeRank * 8 + 5] == nil && board[homeRank * 8 + 6] == nil,
                   !isSquareAttacked(homeRank * 8 + 5, by: piece.color.opposite),
                   !isSquareAttacked(homeRank * 8 + 6, by: piece.color.opposite) {
                    moves.append(ChessMove(from: square, to: homeRank * 8 + 6, isCastle: true))
                }
                if queenside && board[homeRank * 8 + 1] == nil && board[homeRank * 8 + 2] == nil && board[homeRank * 8 + 3] == nil,
                   !isSquareAttacked(homeRank * 8 + 3, by: piece.color.opposite),
                   !isSquareAttacked(homeRank * 8 + 2, by: piece.color.opposite) {
                    moves.append(ChessMove(from: square, to: homeRank * 8 + 2, isCastle: true))
                }
            }
        }
        return moves
    }

    private func addPawnMove(toFile: Int, toRank: Int, promotionRank: Int, from: Int, into moves: inout [ChessMove]) {
        let target = toRank * 8 + toFile
        if toRank == promotionRank {
            for type in [ChessPieceType.queen, .rook, .bishop, .knight] {
                moves.append(ChessMove(from: from, to: target, promotion: type))
            }
        } else {
            moves.append(ChessMove(from: from, to: target))
        }
    }

    private func addSlidingMoves(from square: Int, piece: ChessPiece, directions: [(Int, Int)], into moves: inout [ChessMove]) {
        let startFile = square % 8
        let startRank = square / 8
        for (df, dr) in directions {
            var file = startFile + df
            var rank = startRank + dr
            while (0..<8).contains(file), (0..<8).contains(rank) {
                let target = rank * 8 + file
                if let occupant = board[target] {
                    if occupant.color != piece.color { moves.append(ChessMove(from: square, to: target)) }
                    break
                }
                moves.append(ChessMove(from: square, to: target))
                file += df
                rank += dr
            }
        }
    }

    private func isKingInCheck(for color: ChessColor) -> Bool {
        guard let king = board.firstIndex(where: { $0 == ChessPiece(type: .king, color: color) }) else { return true }
        return isSquareAttacked(king, by: color.opposite)
    }

    private func isSquareAttacked(_ square: Int, by attacker: ChessColor) -> Bool {
        let file = square % 8
        let rank = square / 8
        let pawnRank = rank + (attacker == .white ? -1 : 1)
        for pawnFile in [file - 1, file + 1] where (0..<8).contains(pawnFile) && (0..<8).contains(pawnRank) {
            if board[pawnRank * 8 + pawnFile] == ChessPiece(type: .pawn, color: attacker) { return true }
        }
        for (df, dr) in [(1, 2), (2, 1), (-1, 2), (-2, 1), (1, -2), (2, -1), (-1, -2), (-2, -1)] {
            let f = file + df, r = rank + dr
            if (0..<8).contains(f), (0..<8).contains(r), board[r * 8 + f] == ChessPiece(type: .knight, color: attacker) { return true }
        }
        for (df, dr, types) in [(1, 0, [ChessPieceType.rook, .queen]), (-1, 0, [.rook, .queen]), (0, 1, [.rook, .queen]), (0, -1, [.rook, .queen]), (1, 1, [.bishop, .queen]), (-1, 1, [.bishop, .queen]), (1, -1, [.bishop, .queen]), (-1, -1, [.bishop, .queen])] {
            var f = file + df, r = rank + dr
            while (0..<8).contains(f), (0..<8).contains(r) {
                if let piece = board[r * 8 + f] {
                    if piece.color == attacker && types.contains(piece.type) { return true }
                    break
                }
                f += df; r += dr
            }
        }
        for df in -1...1 {
            for dr in -1...1 where df != 0 || dr != 0 {
                let f = file + df, r = rank + dr
                if (0..<8).contains(f), (0..<8).contains(r), board[r * 8 + f] == ChessPiece(type: .king, color: attacker) { return true }
            }
        }
        return false
    }

    private mutating func applyUnchecked(_ move: ChessMove) {
        guard let movingPiece = board[move.from] else { return }
        let oldTarget = board[move.to]
        board[move.from] = nil
        board[move.to] = ChessPiece(type: move.promotion ?? movingPiece.type, color: movingPiece.color)

        if move.isEnPassant {
            let direction = movingPiece.color == .white ? -1 : 1
            board[move.to + direction * 8] = nil
        }
        if move.isCastle {
            let rank = movingPiece.color == .white ? 0 : 7
            if move.to > move.from {
                board[rank * 8 + 5] = board[rank * 8 + 7]
                board[rank * 8 + 7] = nil
            } else {
                board[rank * 8 + 3] = board[rank * 8]
                board[rank * 8] = nil
            }
        }

        updateCastlingRights(movingPiece: movingPiece, from: move.from, captured: oldTarget, to: move.to)
        enPassantTarget = movingPiece.type == .pawn && abs(move.to - move.from) == 16 ? (move.from + move.to) / 2 : nil
        turn = turn.opposite
    }

    private mutating func updateCastlingRights(movingPiece: ChessPiece, from: Int, captured: ChessPiece?, to: Int) {
        if movingPiece.type == .king {
            if movingPiece.color == .white { castlingRights.whiteKingside = false; castlingRights.whiteQueenside = false }
            else { castlingRights.blackKingside = false; castlingRights.blackQueenside = false }
        }
        if movingPiece.type == .rook || captured?.type == .rook {
            for square in [from, to] {
                switch square {
                case 0: castlingRights.whiteQueenside = false
                case 7: castlingRights.whiteKingside = false
                case 56: castlingRights.blackQueenside = false
                case 63: castlingRights.blackKingside = false
                default: break
                }
            }
        }
    }
}

@MainActor
final class ChessGameModel: ObservableObject {
    @Published private(set) var position = ChessPosition()
    private var undoStack: [ChessPosition] = []

    func move(from: Int, to: Int, promotion: ChessPieceType? = nil) -> Bool {
        var next = position
        guard next.move(from: from, to: to, promotion: promotion) else { return false }
        undoStack.append(position)
        position = next
        return true
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        position = previous
    }

    func reset() {
        position = ChessPosition()
        undoStack.removeAll()
    }

    func replace(with position: ChessPosition) {
        self.position = position
        undoStack.removeAll()
    }
}
