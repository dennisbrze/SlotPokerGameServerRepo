import SwiftUI

struct ContentView: View {
    @StateObject private var webServer = WebServer() // Observing the WebServer instance
    @State private var selectedClientID: String? // Tracks the selected client
    
    @StateObject private var pokerGame = PokerGame()
    private var webSocketServer = WebSocketServer(gameState: <#PokerGame#>)

    // Function to fetch available IPs and handle errors
    private func fetchAvailableIP() {
        webServer.fetchAvailableIP() // Fetch available IPs
    }
    
    func isValidIPAddress(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".")
        return parts.count == 4 && parts.allSatisfy { part in
            if let number = Int(part), (0...255).contains(number) {
                return true
            }
            return false
        }
    }

    var body: some View {
        VStack {
            // Display the server's current state
            Text("Server State: \(webServer.serverState)")
                .font(.headline)
                .padding()

            // Display the host IP when the server is running
            if webServer.serverState == "Running" {
                Text("Host IP: \(webServer.hostIPAddress):8080")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding()
            }

            // Picker for selecting an IP address
            Picker("Select IP", selection: $webServer.hostIPAddress) {
                ForEach(webServer.availableIPs, id: \.self) { ip in
                    Text(ip).tag(ip) // Properly tag each item
                }
            }
            .onAppear {
                fetchAvailableIP() // Fetch available IPs when the view appears

                // Set default hostIPAddress once IPs are available
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if webServer.hostIPAddress == "0.0.0.0", let firstIP = webServer.availableIPs.first {
                        webServer.hostIPAddress = firstIP
                    }
                }
            }
            .padding()

            // Start server button
            Button(action: {
                guard isValidIPAddress(webServer.hostIPAddress) else {
                        print("Invalid IP address")
                        return
                    }
                    do {
                        try webSocketServer.start(host: webServer.hostIPAddress, port: 8080)
                    } catch {
                        print("Error starting server: \(error)")
                    }
            }) {
                Text("Start Server")
                    .padding()
                    .frame(maxWidth: .infinity) // Make the button fill the width
                    .background(webServer.hostIPAddress == "0.0.0.0" || webServer.hostIPAddress.isEmpty || webServer.hostIPAddress == "Unknown IP" || webServer.serverState == "Running" ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .disabled(webServer.serverState == "Running" || webServer.hostIPAddress == "0.0.0.0" || webServer.hostIPAddress.isEmpty || webServer.hostIPAddress == "Unknown IP")

            // Stop server button
            Button(action: {
                webServer.stop() // Stop the server
                if webServer.hostIPAddress == "0.0.0.0", let firstIP = webServer.availableIPs.first {
                    webServer.hostIPAddress = firstIP
                }
            }) {
                Text("Stop Server")
                    .padding()
                    .frame(maxWidth: .infinity) // Make the button fill the width
                    .background(webServer.serverState == "Stopped" ? Color.gray : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
            }
            .padding()
            .disabled(webServer.serverState == "Stopped")


            // Connected clients section
            VStack {
                Text("Connected Clients:")
                    .font(.headline)
                    .padding(.top)

                if webServer.clients.isEmpty {
                    Text("No clients connected")
                        .foregroundColor(.gray)
                } else {
                List {
                        ForEach(webServer.clients, id: \.id) { client in
                            HStack {
                                Text("ID: \(client.id), IP: \(client.ipAddress)")
                                    .frame(maxWidth: .infinity, alignment: .leading) // ID on the left

                                    //.padding()

                                //Spacer()

                                // Remove Button
                                Button(action: {
                                    self.webServer.removeClient(client)  // Call function to remove client
                                }) {
                                    Text(" X ")
                                        .foregroundColor(.red)
                                        .padding(5)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(5)
                                }
                            }
                        }
                    }
                .frame(maxWidth: .infinity,alignment: .leading)
                }
            }
            .padding()

            VStack {
                Text("Game Status: \(pokerGame.gameStatus)")
                    .padding()

                // Display the list of players
                List(pokerGame.players) { player in
                    Text("\(player.name): \(player.chips) chips")
                }

                // Actions for players to interact with the game
                if let currentPlayer = pokerGame.getCurrentPlayer() {
                    VStack {
                        Text("It's \(currentPlayer.name)'s turn")
                        
                        HStack {
                            Button("Fold") {
                                pokerGame.playerAction(player: currentPlayer, action: .fold)
                            }
                            Button("Check") {
                                pokerGame.playerAction(player: currentPlayer, action: .check)
                            }
                            Button("Raise 10") {
                                pokerGame.playerAction(player: currentPlayer, action: .raise(10))
                            }
                            Button("Call 10") {
                                pokerGame.playerAction(player: currentPlayer, action: .call(10))
                            }
                        }
                    }
                }

                // Start a new round button
                Button("Start Round") {
                    pokerGame.startRound()
                }
            }
            .padding()
            
            if pokerGame.isBettingPhaseOver() {
                Text("Betting Phase Over!")
                
                Button("Declare Winner") {
                    pokerGame.declareWinner()
                }
            }
            
            // Display server logs in a scrollable list
            List(webServer.logMessages, id: \.self) { message in
                Text(message)
                    .font(.body)
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
    }

}

#Preview {
    ContentView()
}
