import Foundation
import Network
import SystemConfiguration.CaptiveNetwork

class WebServer: ObservableObject {
    @Published var availableIPs: [String] = []  // Holds the list of available IP addresses
    @Published var serverState: String = "Stopped"
    @Published var hostIPAddress: String = "0.0.0.0"
    @Published var logMessages: [String] = []
    @Published var clients: [ClientInfo] = []

    private var listener: NWListener?    

    struct ClientInfo: Identifiable {
        let id: String // Unique identifier for the client
        let ipAddress: String
    }
    
    private func getClientIP(from connection: NWConnection) -> String {
        if case let .hostPort(host, _) = connection.endpoint {
            return host.debugDescription
        }
        return "Unknown IP"
    }
    
    // Fetch the local IP addresses of the device (both IPv4 and IPv6)
    func fetchAvailableIP() {
        availableIPs = getWiFiIPAddress()
        if availableIPs.isEmpty {
            logMessages.append("No IP addresses found.")
        } else {
            logMessages.append("IP addresses found: \(availableIPs)")
        }
    }

    // Get Wi-Fi IP Address (IPv4/IPv6)
    func getWiFiIPAddress() -> [String] {
        var ipAddresses: [String] = []
        
        // Use getifaddrs to fetch interfaces
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddrs) == 0 {
            var currentAddress = ifaddrs
            while currentAddress != nil {
                let interface = currentAddress?.pointee
                //let name = String(cString: (interface?.ifa_name)!)
                
                // Check if the interface is a valid IPv4 address (AF_INET)
                if interface?.ifa_addr.pointee.sa_family == UInt8(AF_INET) { // IPv4
                    if let sockaddrIn = interface?.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1, { $0 }) {
                        let address = sockaddrIn.pointee.sin_addr
                        let ip = String(cString: inet_ntoa(address))
                        
                        if ip.starts(with: "192.168") {
                            print(ip)
                            ipAddresses.append(ip)
                        }
                        //ipAddresses.append(ip)
                    }
                } else if interface?.ifa_addr.pointee.sa_family == UInt8(AF_INET6) { // IPv6
                    // For IPv6, use withMemoryRebound to access the memory
                    if let sockaddrIn6 = interface?.ifa_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1, { $0 }) {
                        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                        
                        // Make the address mutable by declaring it as a variable
                        var address = sockaddrIn6.pointee.sin6_addr
                        inet_ntop(AF_INET6, &address, &buffer, socklen_t(INET6_ADDRSTRLEN))
                        if String(cString: buffer).starts(with: "fe80") && !ipAddresses.contains(String(cString: buffer)){
                            //print(String(cString: buffer))
                            //ipAddresses.append(String(cString: buffer))
                        }
                        
                    }
                }
                currentAddress = interface?.ifa_next
            }
            freeifaddrs(ifaddrs)
        }
        
        return ipAddresses
    }
    
    private func handleClientConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            guard let self = self, let data = data, error == nil else {
                self?.logMessages.append("Error receiving data from connection: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            // Parse the request
            if let request = String(data: data, encoding: .utf8) {
                self.logMessages.append("Request received: \(request)")

                // Check if it's a GET request
                if request.starts(with: "GET") {
                    // Directly assign client IP (getClientIP(from:) should return a non-optional value)
                    let clientIP = self.getClientIP(from: connection)
                    let randomID = String(Int.random(in: 100...999)) // Assign a random ID
                    let clientInfo = ClientInfo(id: randomID, ipAddress: clientIP)

                    // Update the clients list on the main thread
                    DispatchQueue.main.async {
                        self.clients.append(clientInfo)
                    }

                    // Send response to client
                    self.sendResponse(to: connection, clientIP: clientIP, clientID: randomID)
                }

                // Handle POST request (e.g., JOIN_GAME)
                else if request.starts(with: "POST") {
                    // Directly get client IP (getClientIP(from:) returns non-optional)
                    let clientIP = self.getClientIP(from: connection)
                    
                    // Parse the POST body for JOIN_GAME
                    if let body = request.split(separator: "\r\n\r\n").last,
                       let message = body.split(separator: " ").first,
                       message == "JOIN_GAME" {
                        let randomID = String(Int.random(in: 100...999)) // Assign a random ID
                        let clientInfo = ClientInfo(id: randomID, ipAddress: clientIP)

                        // Update the clients list on the main thread
                        DispatchQueue.main.async {
                            self.clients.append(clientInfo)
                        }

                        // Send response to client
                        self.sendResponse(to: connection, clientIP: clientIP, clientID: randomID)
                    }
                }
            }
        }
    }





    // Start the server
    func start() {
        guard !availableIPs.isEmpty else {
            logMessages.append("No available IP addresses.")
            serverState = "Error"
            return
        }

        // Use the selected IP address from the Picker
        //hostIPAddress = availableIPs.first ?? "Unavailable"
        serverState = "Starting"

        // Set up and start the NWListener
        do {
            let parameters = NWParameters(tls: nil, tcp: NWProtocolTCP.Options())
            parameters.requiredInterfaceType = .wifi  // Restrict to Wi-Fi
            guard let port = NWEndpoint.Port(rawValue: 8080) else {
                logMessages.append("Invalid port.")
                serverState = "Error"
                return
            }

            // Ensure that the hostIPAddress is not empty or invalid
            guard !hostIPAddress.isEmpty else {
                logMessages.append("Invalid IP address.")
                serverState = "Error"
                return
            }

            // Create a NWEndpoint.Host with the hostIPAddress (as a string)
            //let ip = NWEndpoint.Host(hostIPAddress)

            // Create a listener using the selected hostIPAddress
            listener = try NWListener(using: parameters, on: port)

            // Bind the listener to the specific IP address (hostIPAddress)
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.serverState = "Running"
                        self?.logMessages.append("Server started on \(self?.hostIPAddress ?? "Unavailable"):8080")
                    case .failed(let error):
                        self?.serverState = "Failed"
                        self?.logMessages.append("Error: \(error.localizedDescription)")
                    default:
                        break
                    }
                }
            }

            listener?.start(queue: .main)

        } catch {
            logMessages.append("Error starting server: \(error.localizedDescription)")
            serverState = "Error"
        }
    }


    // Stop the server
    func stop() {
        
        // Remove all clients
        while !clients.isEmpty {
            if let client = clients.first {
                removeClient(client) // Remove each client
            }
        }
        
        listener?.cancel()
        listener = nil
        serverState = "Stopped"
        hostIPAddress = "0.0.0.0"
        logMessages.append("Server stopped.")
        fetchAvailableIP()
    }
    
    

    // Handle incoming client connections
    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: .main)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }  // Proper unwrapping of self
            
            if let data = data, !data.isEmpty, let request = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.logMessages.append("Request received: \(request)")
                }

                // Generate client ID and get the IP address
                let clientIP = self.getClientIP(from: connection)
                let randomID = String(Int.random(in: 100...999)) // Assign a random ID // Assign a random ID for the new connection
                
                let clientInfo = ClientInfo(id: randomID, ipAddress: clientIP)

                // Ensure you're adding to the main thread
                DispatchQueue.main.async {
                    // Add to the list of clients
                    self.clients.append(clientInfo)

                    // You may want to log the addition
                    self.logMessages.append("Client connected: \(clientInfo.id) (\(clientInfo.ipAddress))")
                }

                // Respond to the client
                self.sendResponse(to: connection, clientIP: clientIP, clientID: randomID)
            }

            // If the connection is complete or an error occurs, cancel the connection
            if isComplete || error != nil {
                connection.cancel()
                DispatchQueue.main.async {
                    self.logMessages.append("Connection closed.")
                }
            }
        }
    }


    // Send HTTP Response to the client
    private func sendResponse(to connection: NWConnection, clientIP: String, clientID: String) {
        let response = """
        HTTP/1.1 200 OK
        Content-Type: text/html; charset=utf-8
        Cache-Control: no-cache, no-store, must-revalidate
        Pragma: no-cache
        Expires: 0

        <html>
        <head><title>Welcome to the Game Server!</title></head>
        <body>
        <h1>Welcome to the Game Server!</h1>
        <p>Your connection was successful.</p>
        </body>
        </html>
        """
        guard let responseData = response.data(using: .utf8) else { return }

        // Send the response data over the connection
        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.logMessages.append("Error sending response: \(error.localizedDescription)")
                }
            } else {
                DispatchQueue.main.async {
                    self.logMessages.append("Response sent successfully.")
                }
                connection.cancel() // Close the connection after sending the response
            }
        })
    }


    func removeClient(_ client: ClientInfo) {
        // Remove the client from the list of connected clients
        if let index = clients.firstIndex(where: { $0.id == client.id }) {
            clients.remove(at: index)

            // Optionally, perform additional actions, such as closing the connection
            // For example:
            // connection.cancel()  // Close the connection for this client
            logMessages.append("Removed client: \(client.id) (\(client.ipAddress))")
        }
    }

    
}

