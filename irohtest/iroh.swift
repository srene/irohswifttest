import Foundation
import IrohLib

// only to convert hex format topic id from string to Data. created by AI. maybe not really ncessary.
extension String {
    /// Converts a hexadecimal string (e.g., "01af", "0x01af", "01 AF") to Data.
    ///
    /// - Important:
    ///   - Removes "0x" prefix if present.
    ///   - Removes any whitespace or newlines.
    ///   - Requires an even number of hexadecimal characters.
    ///   - All characters must be valid hexadecimal digits (0-9, a-f, A-F).
    ///
    /// - Returns: A `Data` object if successful, otherwise `nil` if the string
    ///   is not valid hex or has an odd number of hex characters or contains invalid digits.
    func hexToData() -> Data? {
        // 1. Clean the string: remove "0x" prefix, spaces, and newlines
        let cleanedHex = self.replacingOccurrences(of: "0x", with: "")
                               .filter { !$0.isWhitespace && !$0.isNewline }
        
        // 2. Ensure an even number of characters
        guard cleanedHex.count % 2 == 0 else {
            // print("Error: Hex string must have an even number of characters. Count: \(cleanedHex.count)")
            return nil
        }
        
        // 3. Convert pairs of hex characters to UInt8 bytes
        // Iterate through the string, taking two characters at a time.
        // Convert each two-char substring to a UInt8 using radix 16.
        // `compactMap` handles potential nil results (invalid hex pairs).
        let bytes = stride(from: 0, to: cleanedHex.count, by: 2).compactMap { index -> UInt8? in
            let startIndex = cleanedHex.index(cleanedHex.startIndex, offsetBy: index)
            let endIndex = cleanedHex.index(startIndex, offsetBy: 2)
            let byteString = String(cleanedHex[startIndex..<endIndex])
            return UInt8(byteString, radix: 16)
        }
        
        // 4. If all pairs successfully converted, return as Data
        guard bytes.count == cleanedHex.count / 2 else {
            // This condition checks if `compactMap` filtered out any invalid pairs.
            // If it did, `bytes.count` would be less than expected.
            // print("Error: Invalid hex character(s) found.")
            return nil
        }
        
        return Data(bytes)
    }
}

// callback used to receive gossip events once joined
class MyGossipCallback: GossipMessageCallback {
    // This method is invoked by the Rust core whenever a new message is received.
    func onMessage(msg: Message) {
        
        //do some actions depending on message type received
        if msg.type() == MessageType.received {
            let content = msg.asReceived()
            // Print the received message to the console.
            if let textString = String(data: content.content, encoding: .utf8) {
                print("\n[Received]: \(textString)")
                print("> ", terminator: "")
                fflush(stdout) // Ensure the ">" prompt is displayed immediately.
            } else {
                print("Could not convert data to string.")
            }
        // confirm node joined the group
        } else if msg.type() == MessageType.joined {
            print("\nSuccessfully joined topic")
        }
    }
}

class IrohGossipApp {
    private var node: Iroh
    private var gossip: Gossip
    private var gossipSender: Sender?
    private var nodeID: String

    /// Initializes and starts the Iroh node.
    init() async throws {
        // Initialize the node with the specified path
        let nodeOptions = IrohLib.NodeOptions(
            gcIntervalMillis: 1000*100,
            blobEvents: nil,
            enableDocs: false,
            ipv4Addr: nil,
            ipv6Addr: nil,
            nodeDiscovery: nil,
            secretKey: nil,
            protocols: nil)
        self.node = try await IrohLib.Iroh.memoryWithOptions(
            options: nodeOptions)
        print("[App] Iroh node initialized.")

        self.gossip = node.gossip()

        // Get and store the node's ID
        let id = try await node.net().nodeId()
        let addr = try await node.net().nodeAddr().directAddresses()
        self.nodeID = id
        print("[App] Iroh Node ID: \(id)")
        print("[App] Iroh Node Addr: \(addr)")

    }
    
    /// Joins a specified gossip topic without bootsrap node (useful for first node)
    /// - Parameter topicID: The ID of the topic to join.
    func joinGossipTopic(topicID: String) async throws {

        print("[App] Attempting to join gossip topic: \(topicID)")
        self.gossipSender = try await self.gossip.subscribe(
            topic: topicID.hexToData()!,
            bootstrap: [],
            cb: MyGossipCallback()
        )

    }
    
    /// Joins a specified gossip topic using as bootstrap node the node idenfitfied by
    /// - Parameter topicID: The ID of the topic to join.
    /// - Parameter nodeId: The iroh id used as node identifier for the bootstrap node.
    /// - Parameter ipPort: ip:port string to connect to bootstrap node.
    func joinGossipTopicWithNodeAddr(topicID: String, nodeId: String, ipPort: String) async throws {

        // create nodeKey from string id
        let nodeKey = try IrohLib.PublicKey.fromString(s:nodeId)
        // create NodeAddr from info
        let irohAddr = IrohLib.NodeAddr(nodeId: nodeKey, derpUrl: nil, addresses: [ipPort])
        // add bootstrap node addr to local Iroh instance
        try await node.net().addNodeAddr(addr: irohAddr)
        print("[App] Attempting to join gossip topic: \(topicID)")
        
        // join gossip topic using bootstrap node info
        self.gossipSender = try await gossip.subscribe(
            topic: topicID.hexToData()!,
            bootstrap: [nodeId],
            cb: MyGossipCallback()
        )
        print("[App] Successfully joined gossip topic: \(topicID)")

    }
    
    /// Broadcasts a text message to the gossip broup
    /// - Parameter message: String message to send
    func sendMessage(message: String) async throws {

        print("[App] Sending message: \"\(message)\"")

        // create message
        guard let data = message.data(using: .utf8) else {
            print("[App] Failed to encode message to Data.")
            return
        }

        // broadcast message to gossip topic
        try await self.gossipSender?.broadcast(msg: data)

        print("[App] Message sent.")
    }

}

@main
struct IrohGossipMain {
    static func main() async {

        do {
            let app = try await IrohGossipApp()

            let chatTopic = "fbfdf8a045484d2f57bb678ffb792e0db647aa1c996e559937d6529aefdbf5bf"

            // if args are set use them to connect to bootstrap node, otherwise be the bootstrap.
            if CommandLine.arguments.count != 3 {
                //join topic
                try await app.joinGossipTopic(topicID: chatTopic)
            } else {
                let nodeId = CommandLine.arguments[1]
                let destIpPort = CommandLine.arguments[2]
                //join topic using bootstrap
                try await app.joinGossipTopicWithNodeAddr(topicID: chatTopic, nodeId: nodeId, ipPort: destIpPort)
            }

            // Loop to send messages
            while true {
                print("Enter message: ", terminator: "")
                if let input = readLine() {
                    if input.lowercased() == "exit" {
                        break
                    }
                    try await app.sendMessage(message: input)
                }
            }

        } catch {
            print("[App] An error occurred: \(error)")
        }

        print("[App] Application finished.")
    }
}
