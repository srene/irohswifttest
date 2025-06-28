//
//  main.swift
//  irohtest
//
//  Created by Sergi Rene on 24/6/25.
//

import Foundation
import IrohLib

class MyGossipCallback: GossipMessageCallback {
    // This method is invoked by the Rust core whenever a new message is received.
    func onMessage(msg: Message) {
        // Attempt to decode the message content as a UTF-8 string.
        let content = msg.asReceived()
        
        // Print the received message to the console.
        print("\n[Gossip Received]: \(content)")
        print("> ", terminator: "")
        fflush(stdout) // Ensure the ">" prompt is displayed immediately.
    }
}


enum GossipError: Error {
    case invalidNodePath
    case irohEndpointCreationFailed
    case gossipProtocolSetupFailed
    case failedToJoinTopic
    case messageEncodingFailed
    case messageDecodingFailed
}

public func endpoint() async throws -> IrohLib.Iroh {

    let nodePath = FileManager().urls(for:.applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("iroh-node")

    //IrohLib..ProtocolCreatorImpl
    //let creator = IrohLib.ProtocolCreator
    let nodeOptions = IrohLib.NodeOptions(
        gcIntervalMillis: 1000*10,
        blobEvents: nil,
        enableDocs: true,
        ipv4Addr: nil,
        ipv6Addr: nil,
        nodeDiscovery: nil,
        secretKey: nil,
        protocols: nil)
    
    
    

    let irohEndpoint = try await IrohLib.Iroh.persistentWithOptions(
        path: nodePath!.path(percentEncoded: false),
        options: nodeOptions)

    print("created iroh endpoint: \(irohEndpoint) options: \(nodeOptions) path: \(nodePath!)")

    let nodeAddr = try await irohEndpoint.net().nodeAddr()

   // print("node id : \(nodeAddr.nodeId().description)")
    print("node addr : \(nodeAddr.directAddresses().description)")

    return irohEndpoint
}

IrohLib.setLogLevel(level: .debug)

let irohEndpoint = try await endpoint()


let nodeId = try! await irohEndpoint.net().nodeId()

print("node id \(nodeId.data(using: .utf8)!)")
//print("node id \(nodeId.description)")

//let chatTopic = Data(base64Encoded: "D6UgMOITFIvVUYAelB65nrDQ38WjkyrUDWvdOxmaQ8I=")!

let nodeAddr = "af1657d1b3d9ddeef844f8c5bddb9ee29e83bc07f72f8ee991de18ca3675329e"

let nodeKey = try IrohLib.PublicKey.fromString(s:nodeAddr)
let irohAddr = IrohLib.NodeAddr(nodeId: nodeKey, derpUrl: nil, addresses: ["192.168.1.35:56648"])
let alpn = "n0/iroh/examples/magic/0"
//let gossipalpn = "/iroh-gossip/0"
let alpndata = alpn.data(using: .utf8)!
let connection = try await irohEndpoint.node().endpoint().connect(nodeAddr: irohAddr, alpn:alpndata)

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
