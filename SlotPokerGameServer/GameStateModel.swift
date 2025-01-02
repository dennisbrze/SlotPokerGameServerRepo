import Foundation
import Combine

// Enum for player actions
enum PlayerAction {
    case fold, raise(Int), call(Int), check
}

// Model to represent a player
class Player: Identifiable {
    var id = UUID()
    var name: String
    var chips: Int
    var currentBet: Int
    var action: PlayerAction?
    var hasFolded: Bool = false

    init(name: String, chips: Int) {
        self.name = name
        self.chips = chips
        self.currentBet = 0
        self.action = nil
    }
}

// Model to represent the game state
class PokerGame: ObservableObject {
    @Published var players: [Player] = []
    @Published var pot: Int = 0
    @Published var currentRound: Int = 1
    @Published var activePlayerIndex: Int = 0
    @Published var gameStatus: String = "Waiting to Start"

    // This function will broadcast the updated state to all connected clients
    var broadcast: ((PokerGame) -> Void)?
    
    // Start a new round
    func startRound() {
        guard !players.isEmpty else {
            gameStatus = "No players available."
            return
        }

        gameStatus = "Round \(currentRound)"
        pot = 0
        
        for player in players {
            player.currentBet = 0
            player.action = nil
            player.hasFolded = false
        }

        currentRound += 1
        activePlayerIndex = 0
        
        // Broadcast the new game state
        broadcast?(self)
    }

    // Perform a player action
    func playerAction(player: Player, action: PlayerAction) {
        guard let playerIndex = players.firstIndex(where: { $0.id == player.id }), !players[playerIndex].hasFolded else {
            return
        }

        switch action {
        case .fold:
            players[playerIndex].hasFolded = true
            players[playerIndex].action = .fold
        case .raise(let amount):
            guard players[playerIndex].chips >= amount else {
                return // Prevent raising if player has insufficient chips
            }
            players[playerIndex].chips -= amount
            pot += amount
            players[playerIndex].currentBet += amount
            players[playerIndex].action = .raise(amount)
        case .call(let amount):
            guard players[playerIndex].chips >= amount else {
                return // Prevent calling if player has insufficient chips
            }
            players[playerIndex].chips -= amount
            pot += amount
            players[playerIndex].currentBet += amount
            players[playerIndex].action = .call(amount)
        case .check:
            players[playerIndex].action = .check
        }

        // Broadcast the updated game state
        broadcast?(self)
        
        // Move to the next player after action
        nextPlayer()
    }

    // Get the current player
    func getCurrentPlayer() -> Player? {
        return players.isEmpty ? nil : players[activePlayerIndex]
    }

    // Move to the next player
    func nextPlayer() {
        var nextIndex = activePlayerIndex
        repeat {
            nextIndex = (nextIndex + 1) % players.count
        } while players[nextIndex].hasFolded && nextIndex != activePlayerIndex

        // If all players but one have folded, declare winner
        if players.filter({ !$0.hasFolded }).count == 1 {
            declareWinner()
            return
        }

        activePlayerIndex = nextIndex
    }

    // Declare the winner manually
    func declareWinner() {
        guard let winner = players.first(where: { !$0.hasFolded }) else {
            gameStatus = "Error: No winner available."
            return
        }

        winner.chips += pot
        pot = 0
        gameStatus = "Player \(winner.name) wins Round \(currentRound - 1)"
        
        // Broadcast the final game state after declaring the winner
        broadcast?(self)
    }

    // Check if the betting phase is over
    func isBettingPhaseOver() -> Bool {
        let activeBets = players.filter { !$0.hasFolded }.map { $0.currentBet }
        return Set(activeBets).count <= 1
    }
}
