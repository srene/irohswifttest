//
//  main.swift
//  irohtest
//
//  Created by Sergi Rene on 24/6/25.
//

import Foundation
import IrohLib

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

class MyGossipCallback: GossipMessageCallback {
    // This method is invoked by the Rust core whenever a new message is received.
    func onMessage(msg: Message) {
        // Attempt to decode the message content as a UTF-8 string.
        let type = msg.type()
        print("type :\(type)")
        
        if type == MessageType.received {
            let content = msg.asReceived()
            // Print the received message to the console.
            let data =  String(data: content.content, encoding: .utf8)
           
            if let textString = String(data: content.content, encoding: .utf8) {
                print("\n[Received]: \(textString)")
                print("> ", terminator: "")
                fflush(stdout) // Ensure the ">" prompt is displayed immediately.
            } else {
                print("Could not convert data to string.")
            }
            

        }
    }
}

public func endpoint() async throws -> IrohLib.Iroh {

    let nodeOptions = IrohLib.NodeOptions(
        gcIntervalMillis: 1000*100,
        blobEvents: nil,
        enableDocs: false,
        ipv4Addr: nil,
        ipv6Addr: nil,
        nodeDiscovery: nil,
        secretKey: nil,
        protocols: nil)
    

    let irohEndpoint = try await IrohLib.Iroh.memoryWithOptions(
        options: nodeOptions)

    print("created iroh endpoint: \(irohEndpoint) options: \(nodeOptions)")

    let nodeAddr = try await irohEndpoint.net().nodeAddr()

    let nodeId = try! await irohEndpoint.net().nodeId()

    print("node id : \(nodeId)")
    
   // print("node id : \(nodeAddr.nodeId().description)")
    print("node addr : \(nodeAddr.directAddresses().description)")
    
    return irohEndpoint
}

IrohLib.setLogLevel(level: .info)

let irohEndpoint = try await endpoint()


let nodeAddr = "2c8a576f402ac452f823ed06134866cfede1329d74a94c79523d1c66b20e52f7"
let chatTopic = "fbfdf8a045484d2f57bb678ffb792e0db647aa1c996e559937d6529aefdbf5bf"
let destIpAddr = "10.4.12.225:56648"

let nodeKey = try IrohLib.PublicKey.fromString(s:nodeAddr)
let irohAddr = IrohLib.NodeAddr(nodeId: nodeKey, derpUrl: nil, addresses: [destIpAddr])
let gossipalpn = "/iroh-gossip/0"
let alpndata = gossipalpn.data(using: .utf8)!
let chattopicdata = chatTopic.hexToData()!

try await irohEndpoint.net().addNodeAddr(addr: irohAddr)

let irohGossip = irohEndpoint.gossip()

// Subscribe
let gossipSender = try await irohGossip.subscribe(
    topic: chattopicdata,
    bootstrap: [nodeAddr],
    cb: MyGossipCallback()
)

try? await Task.sleep(for: Duration.seconds(5))

print("sending")
let msg = "hola"
let msgdata = msg.data(using: .utf8)!
try await gossipSender.broadcast(msg: msgdata)

try? await Task.sleep(for: Duration.seconds(100))

/*let connection = try await irohEndpoint.node().endpoint().connect(nodeAddr: irohAddr, alpn:alpndata)
let remoteNodeId = try connection.getRemoteNodeId()
print("Remote node address: \(remoteNodeId)")

let message = "Hello Iroh Peer from Swift!"
let biStream = try await connection.openBi()
let messageData = message.data(using: .utf8)!

try await biStream.send().writeAll(buf: messageData)
try await biStream.send().finish()
print("Sent message to \(try connection.getRemoteNodeId()): \(message)")

let reason = "finished"
let reasondata = reason.data(using: .utf8)!
try connection.close(errorCode: UInt64(1), reason: reasondata)

IrohLib.ProtocolCreatorImpl.create(<#T##self: ProtocolCreatorImpl##ProtocolCreatorImpl#>)
// Optionally, wait for a response if this is a request-response pattern
// let responseData = try await biStream.recv().readToEnd(timeout: nil)
// if let response = String(data: responseData, encoding: .utf8) {
//     print("Received response from \(try await connection.getRemoteNodeId().toString()): \(response)")
// }*/

//try await biStream.
/*let socket  = try await connection.openBi()

let sender = socket.send()

try await sender.writeAll(buf: alpndata)

let msg = try await socket.recv().read(sizeLimit: 1024)
do {
    try await irohEndpoint.net().addNodeAddr(addr: irohAddr)
    //print("Added node address: \(irohAddr.nodeId().description)")
} catch {
    // Log error but potentially continue subscription attempt
   // print("Failed to add node address \(irohAddr.nodeId().description): \(error)")
}
let irohGossip = irohEndpoint.gossip()

// Subscribe
let gossipSender = try await irohGossip.subscribe(
    topic: chatTopic,
    bootstrap: [nodeAddr],
    cb: MyGossipCallback()
)

let msg = "hola"
let msgdata = msg.data(using: .utf8)!
try await gossipSender.broadcast(msg: msgdata)

//let _ = try await irohGossip.subscribe(topic: Data, bootstrap: <#T##[String]#>, cb: T##any GossipMessageCallback)(topic: topic, bootstrapPeers: [], cb: MyGossipCallback())*/
