//
//  ios_vtop_chennaiTests.swift
//  ios-vtop-chennaiTests
//
//  Created by Syed Nabiel Hasaan M on 17/04/26.
//

import Foundation
import Testing
@testable import VIT_Connect

struct ios_vtop_chennaiTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func cockpitAttendanceRiskUsesPublishedThresholds() {
        #expect(VTOPCockpitMetrics.attendanceRiskLabel(for: nil) == nil)
        #expect(VTOPCockpitMetrics.attendanceRiskLabel(for: 75) == "On track")
        #expect(VTOPCockpitMetrics.attendanceRiskLabel(for: 65) == "At risk")
        #expect(VTOPCockpitMetrics.attendanceRiskLabel(for: 64) == "Critical")
    }

    @Test func deepLinksRoundTripToTheirRoutes() throws {
        for route in VTOPDeepLinkRoute.allCases {
            #expect(VTOPDeepLinkRoute(url: route.url) == route)
        }
        #expect(VTOPDeepLinkRoute(url: URL(string: "https://example.com/home")!) == nil)
    }

    @Test func sharedSnapshotRoundTripsNewCockpitFields() throws {
        let snapshot = VTOPGlanceSnapshot(
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            semesterName: "Winter Semester",
            attendancePercent: 72,
            nextClassTitle: "Data Structures",
            nextClassVenue: "AB1-201",
            nextClassStart: Date(timeIntervalSince1970: 1_700_000_600),
            nextClassEnd: Date(timeIntervalSince1970: 1_700_003_600),
            attendanceRiskLabel: "At risk",
            nextExamTitle: "Data Structures FAT",
            nextExamDate: Date(timeIntervalSince1970: 1_700_100_000),
            nextExamVenue: "Main Building",
            todaySlotLines: ["09:00 · Data Structures · AB1-201"]
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(VTOPGlanceSnapshot.self, from: encoder.encode(snapshot))
        #expect(decoded.attendanceRiskLabel == "At risk")
        #expect(decoded.nextExamTitle == "Data Structures FAT")
        #expect(decoded.nextExamVenue == "Main Building")
    }

    @Test func chessStartsWithTwentyLegalMoves() {
        let position = ChessPosition()
        #expect(position.legalMoves().count == 20)
        #expect(position.legalMoves(from: 12).contains { $0.to == 28 }) // e2-e4
    }

    @Test func chessDetectsFoolsMate() {
        var position = ChessPosition()
        let first = position.move(from: square("f2"), to: square("f3"))
        let second = position.move(from: square("e7"), to: square("e5"))
        let third = position.move(from: square("g2"), to: square("g4"))
        let fourth = position.move(from: square("d8"), to: square("h4"))
        #expect(first)
        #expect(second)
        #expect(third)
        #expect(fourth)
        #expect(position.result == .checkmate(.black))
    }

    @Test func chessSupportsCastlingAndEnPassant() {
        var position = ChessPosition()
        let castleMoves = [
            position.move(from: square("e2"), to: square("e4")),
            position.move(from: square("e7"), to: square("e5")),
            position.move(from: square("g1"), to: square("f3")),
            position.move(from: square("b8"), to: square("c6")),
            position.move(from: square("f1"), to: square("e2")),
            position.move(from: square("g8"), to: square("f6")),
            position.move(from: square("e1"), to: square("g1"))
        ]
        #expect(castleMoves.allSatisfy { $0 })
        #expect(position.board[square("g1")]?.type == .king)
        #expect(position.board[square("f1")]?.type == .rook)

        position = ChessPosition()
        let enPassantMoves = [
            position.move(from: square("e2"), to: square("e4")),
            position.move(from: square("a7"), to: square("a6")),
            position.move(from: square("e4"), to: square("e5")),
            position.move(from: square("d7"), to: square("d5")),
            position.move(from: square("e5"), to: square("d6"))
        ]
        #expect(enPassantMoves.allSatisfy { $0 })
        #expect(position.board[square("d6")]?.type == .pawn)
        #expect(position.board[square("d5")] == nil)
    }

    @Test func chessSupportsPromotion() {
        var position = ChessPosition()
        position.board = Array(repeating: nil, count: 64)
        position.board[square("e1")] = ChessPiece(type: .king, color: .white)
        position.board[square("e8")] = ChessPiece(type: .king, color: .black)
        position.board[square("a7")] = ChessPiece(type: .pawn, color: .white)
        let promoted = position.move(from: square("a7"), to: square("a8"), promotion: .queen)
        #expect(promoted)
        #expect(position.board[square("a8")] == ChessPiece(type: .queen, color: .white))
    }

    private func square(_ notation: String) -> Int {
        let scalars = Array(notation.unicodeScalars)
        let file = Int(scalars[0].value - 97)
        let rank = Int(scalars[1].value - 49)
        return rank * 8 + file
    }

}
