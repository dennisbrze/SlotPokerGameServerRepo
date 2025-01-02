import Foundation
import NIO
import NIOWebSocket

final class WebSocketServer: ObservableObject {
    private var serverGroup: MultiThreadedEventLoopGroup?
    private var channel: Channel?
    private var connectedClients: [ObjectIdentifier: WebSocket] = [:]
    private var gameState: PokerGame

    init(gameState: PokerGame) {
        self.gameState = gameState
    }

    func start(host: String, port: Int) throws {
        serverGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let bootstrap = ServerBootstrap(group: serverGroup!)
            .childChannelInitializer { channel in
                let webSocketHandler = WebSocketHandler(
                    connectedClients: self.$connectedClients,
                    gameState: self.gameState
                )
                return channel.pipeline.addHandler(webSocketHandler)
            }
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)

        channel = try bootstrap.bind(host: host, port: port).wait()
        print("WebSocket server started on \(host):\(port)")
    }

    func stop() throws {
        try channel?.close().wait()
        try serverGroup?.syncShutdownGracefully()
        print("WebSocket server stopped.")
    }
}

private final class WebSocketHandler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame

    @Binding private var connectedClients: [ObjectIdentifier: WebSocket]
    private var gameState: PokerGame

    init(connectedClients: Binding<[ObjectIdentifier: WebSocket]>, gameState: PokerGame) {
        self._connectedClients = connectedClients
        self.gameState = gameState
    }

    func channelActive(context: ChannelHandlerContext) {
        let clientID = ObjectIdentifier(context.channel)
        connectedClients[clientID] = WebSocket(channel: context.channel)
        print("Client connected: \(clientID)")
    }

    func channelInactive(context: ChannelHandlerContext) {
        let clientID = ObjectIdentifier(context.channel)
        connectedClients.removeValue(forKey: clientID)
        print("Client disconnected: \(clientID)")
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)

        guard case .text(let text) = frame.dataType, let payload = frame.getString() else {
            print("Invalid WebSocket frame received.")
            return
        }

        handleIncomingMessage(payload, from: context.channel)
    }

    private func handleIncomingMessage(_ message: String, from channel: Channel) {
        print("Received message from client: \(message)")

        // Parse and handle the message
        if let action = decodeAction(message) {
            handleGameAction(action, from: channel)
        } else {
            print("Failed to decode client message.")
        }
    }

    private func handleGameAction(_ action: GameAction, from channel: Channel) {
        // Perform game state updates here
        print("Handling game action: \(action)")

        // Broadcast updated game state to all connected clients
        let updatedState = encodeGameState()
        broadcastMessage(updatedState)
    }

    private func broadcastMessage(_ message: String) {
        for (_, client) in connectedClients {
            client.write(message)
        }
    }

    private func decodeAction(_ message: String) -> GameAction? {
        // Parse incoming JSON messages into GameAction structs
        let decoder = JSONDecoder()
        return try? decoder.decode(GameAction.self, from: Data(message.utf8))
    }

    private func encodeGameState() -> String {
        // Convert the current game state to JSON
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(gameState) {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return "{}"
    }
}
