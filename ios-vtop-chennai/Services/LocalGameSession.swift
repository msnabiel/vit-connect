import Foundation
import MultipeerConnectivity

enum LocalGameSnapshotStore {
    private static let ticTacToeKey = "games.ticTacToe.board"

    static func saveTicTacToe(_ board: [String]) {
        UserDefaults.standard.set(board, forKey: ticTacToeKey)
    }

    static func loadTicTacToe() -> [String]? {
        UserDefaults.standard.array(forKey: ticTacToeKey) as? [String]
    }
}

struct LocalGameMessage: Codable {
    enum Kind: String, Codable {
        case roomState
        case move
        case ping
    }

    let kind: Kind
    let payload: Data
    /// Identifies the match so stale messages from a previous rematch cannot overwrite it.
    let gameID: UUID?
    /// Monotonically increasing revision used to ignore out-of-order snapshots.
    let revision: Int?

    init(kind: Kind, payload: Data, gameID: UUID? = nil, revision: Int? = nil) {
        self.kind = kind
        self.payload = payload
        self.gameID = gameID
        self.revision = revision
    }
}

struct LocalGameReceivedMessage: Identifiable {
    let id = UUID()
    let peerName: String
    let message: LocalGameMessage
}

@MainActor
final class LocalGameSession: NSObject, ObservableObject {
    static let serviceType = "vit-game"

    @Published private(set) var nearbyPeers: [MCPeerID] = []
    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var isHosting = false
    @Published private(set) var isBrowsing = false
    @Published private(set) var isConnecting = false
    @Published private(set) var roomID = UUID()
    @Published private(set) var lastReceivedMessage: LocalGameReceivedMessage?
    @Published var errorMessage: String?

    let peerID: MCPeerID
    nonisolated(unsafe) private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    init(displayName: String = "VIT Connect Player") {
        peerID = MCPeerID(displayName: String(displayName.prefix(32)))
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    func startHosting() {
        stopDiscovery()
        roomID = UUID()
        let advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: ["game": "vit-connect"], serviceType: Self.serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
        isHosting = true
    }

    func startBrowsing() {
        stopDiscovery()
        isConnecting = true
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
        isBrowsing = true
    }

    func invite(_ peer: MCPeerID) {
        isConnecting = true
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }

    func send<T: Codable>(_ value: T, kind: LocalGameMessage.Kind, revision: Int? = nil) {
        guard !session.connectedPeers.isEmpty else { return }
        do {
            let message = LocalGameMessage(
                kind: kind,
                payload: try JSONEncoder().encode(value),
                gameID: roomID,
                revision: revision
            )
            try session.send(try JSONEncoder().encode(message), toPeers: session.connectedPeers, with: .reliable)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func beginNewMatch() {
        roomID = UUID()
    }

    func adoptRoomID(_ id: UUID) {
        roomID = id
    }

    func stop() {
        stopDiscovery()
        session.disconnect()
        connectedPeers = []
        isConnecting = false
    }

    private func stopDiscovery() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        isHosting = false
        isBrowsing = false
    }
}

extension LocalGameSession: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor [weak self] in
        self?.connectedPeers = session.connectedPeers
            self?.isConnecting = false
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(LocalGameMessage.self, from: data) else { return }
        Task { @MainActor [weak self] in
            self?.lastReceivedMessage = LocalGameReceivedMessage(peerName: peerID.displayName, message: message)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension LocalGameSession: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor [weak self] in self?.isConnecting = true }
        invitationHandler(true, self.session)
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor [weak self] in self?.errorMessage = error.localizedDescription }
    }
}

extension LocalGameSession: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor [weak self] in
            guard let self, !nearbyPeers.contains(peerID) else { return }
            nearbyPeers.append(peerID)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor [weak self] in self?.nearbyPeers.removeAll { $0 == peerID } }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor [weak self] in self?.errorMessage = error.localizedDescription }
    }
}
