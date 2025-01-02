/* import NIO
import NIOWebSocket

class PokerWebSocketServer {
    private var group: EventLoopGroup!
    private var channel: Channel!
    private var pokerGame: PokerGame
    
    init(pokerGame: PokerGame) {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.pokerGame = pokerGame
    }
    
    func start() throws {
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.addHandlers([WebSocketFrameHandler(pokerGame: self.pokerGame)])
            }

        self.channel = try bootstrap.bind(host: "localhost", port: 8080).wait()
        print("Server started on \(channel.localAddress!)")
    }
    
    func stop() throws {
        try group.syncShutdownGracefully()
    }
}

struct WebSocketFrameHandler: ChannelInboundHandler {
    typealias InboundIn = WebSocketFrame
    var pokerGame: PokerGame

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)
        guard let message = frame.unmaskedPayload.decode(as: String.self) else {
            return
        }
        
        // Handle different types of messages (e.g., player actions)
        if message == "START" {
            pokerGame.startRound() // Start the round when a "START" message is received
        } else if message.starts(with: "ACTION") {
            // Handle player action (fold, raise, call, etc.)
            let components = message.split(separator: " ")
            if components.count > 1, let action = components[1] {
                // Process the action (this should trigger game logic updates)
                pokerGame.playerAction(player: pokerGame.getCurrentPlayer()!, action: action)
            }
        }
        
        // Broadcast updated game state
        sendUpdatedGameState(context: context)
    }
    
    private func sendUpdatedGameState(context: ChannelHandlerContext) {
        // Convert the game state to a string or JSON and send to all clients
        let gameStateMessage = "Game state: \(pokerGame.gameStatus)"
        let frame = WebSocketFrame(fin: true, opcode: .text, data: ByteBuffer(string: gameStateMessage))
        context.writeAndFlush(self.wrapOutboundOut(frame), promise: nil)
    }
}

*/
