import Foundation

@main struct OutboundFlowInspectorCheck {
  static func word(_ n: Int) -> [UInt8] { [UInt8((n >> 8) & 255), UInt8(n & 255)] }

  static func makeClientHello(host: String, extraPaddingBytes: Int = 0) -> Data {
    let hostBytes = Array(host.utf8)
    let names = [UInt8(0)] + word(hostBytes.count) + hostBytes
    let serverName = word(names.count) + names
    var extensions = word(0) + word(serverName.count) + serverName
    if extraPaddingBytes > 0 {
      extensions += word(21) + word(extraPaddingBytes) + [UInt8](repeating: 0, count: extraPaddingBytes)
    }
    var hello = [UInt8](repeating: 0, count: 34)
    hello += [0]; hello += word(2); hello += [0x13, 0x01]; hello += [1, 0]
    hello += word(extensions.count); hello += extensions
    let handshake = [UInt8(1), UInt8((hello.count >> 16) & 255), UInt8((hello.count >> 8) & 255), UInt8(hello.count & 255)] + hello
    let record = [UInt8(22), 3, 1] + word(handshake.count) + handshake
    return Data(record)
  }

  static func main() {
    let inspector = OutboundFlowInspector()

    // 1. Single-chunk TLS ClientHello
    let f1 = UUID()
    precondition(inspector.begin(flowID: f1, kind: .tls) == TLSHostname.maximum)
    let ch = makeClientHello(host: "youtube.com")
    precondition(inspector.feed(flowID: f1, kind: .tls, offset: 0, chunk: ch) == .host("youtube.com", bufferedBytes: ch.count))
    precondition(inspector.trackedFlowCount == 0)

    // 2. Exact 1-byte -> 4-byte -> rest incremental delivery (the 1.1.22 bug reproduction)
    let f2 = UUID()
    _ = inspector.begin(flowID: f2, kind: .tls)
    let r2a = inspector.feed(flowID: f2, kind: .tls, offset: 0, chunk: ch.subdata(in: 0..<1))
    precondition(r2a == .need(peekBytes: 5))
    let r2b = inspector.feed(flowID: f2, kind: .tls, offset: 1, chunk: ch.subdata(in: 1..<5))
    precondition(r2b == .need(peekBytes: ch.count))
    let r2c = inspector.feed(flowID: f2, kind: .tls, offset: 5, chunk: ch.subdata(in: 5..<ch.count))
    precondition(r2c == .host("youtube.com", bufferedBytes: ch.count))
    precondition(inspector.trackedFlowCount == 0)

    // 3. Large post-quantum ClientHello (~1,800 bytes) split across two TCP segments
    let f3 = UUID()
    let pq = makeClientHello(host: "youtube.com", extraPaddingBytes: 1_750)
    precondition(pq.count > 1_800 && pq.count < TLSHostname.maximum)
    _ = inspector.begin(flowID: f3, kind: .tls)
    let r3a = inspector.feed(flowID: f3, kind: .tls, offset: 0, chunk: pq.subdata(in: 0..<1_448))
    precondition(r3a == .need(peekBytes: pq.count))
    let r3b = inspector.feed(flowID: f3, kind: .tls, offset: 1_448, chunk: pq.subdata(in: 1_448..<pq.count))
    precondition(r3b == .host("youtube.com", bufferedBytes: pq.count))
    precondition(inspector.trackedFlowCount == 0)

    // 4. Overlapping re-delivery
    let f4 = UUID()
    _ = inspector.begin(flowID: f4, kind: .tls)
    _ = inspector.feed(flowID: f4, kind: .tls, offset: 0, chunk: ch.subdata(in: 0..<5))
    precondition(inspector.feed(flowID: f4, kind: .tls, offset: 3, chunk: ch.subdata(in: 3..<ch.count)) == .host("youtube.com", bufferedBytes: ch.count))
    precondition(inspector.trackedFlowCount == 0)

    // 5. Unexpected offset gap fails closed to .unknown and cleans up
    let f5 = UUID()
    _ = inspector.begin(flowID: f5, kind: .tls)
    _ = inspector.feed(flowID: f5, kind: .tls, offset: 0, chunk: ch.subdata(in: 0..<5))
    precondition(inspector.feed(flowID: f5, kind: .tls, offset: 10, chunk: ch.subdata(in: 10..<ch.count)) == .unknown)
    precondition(inspector.trackedFlowCount == 0)

    // 6. Non-TLS data cleans up immediately
    let f6 = UUID()
    _ = inspector.begin(flowID: f6, kind: .tls)
    precondition(inspector.feed(flowID: f6, kind: .tls, offset: 0, chunk: Data("GET / HTTP/1.1\r\n".utf8)) == .unknown)
    precondition(inspector.trackedFlowCount == 0)

    // 7. Fragmented HTTP Host header across multiple chunks
    let f7 = UUID()
    let http = Data("GET /watch HTTP/1.1\r\nUser-Agent: test\r\nHost: example.com\r\n\r\n".utf8)
    precondition(inspector.begin(flowID: f7, kind: .http) == HTTPHostname.maximum)
    if case .need = inspector.feed(flowID: f7, kind: .http, offset: 0, chunk: http.subdata(in: 0..<10)) {} else { preconditionFailure("Expected .need") }
    if case .need = inspector.feed(flowID: f7, kind: .http, offset: 10, chunk: http.subdata(in: 10..<25)) {} else { preconditionFailure("Expected .need") }
    precondition(inspector.feed(flowID: f7, kind: .http, offset: 25, chunk: http.subdata(in: 25..<http.count)) == .host("example.com", bufferedBytes: http.count))
    precondition(inspector.trackedFlowCount == 0)

    // 8. Oversized HTTP payload exceeding cap cleans up
    let f8 = UUID()
    let oversized = Data(("GET / HTTP/1.1\r\nX-Pad: " + String(repeating: "a", count: 4_200) + "\r\n").utf8)
    _ = inspector.begin(flowID: f8, kind: .http)
    precondition(inspector.feed(flowID: f8, kind: .http, offset: 0, chunk: oversized) == .unknown)
    precondition(inspector.trackedFlowCount == 0)

    // 9. Capacity bound prevents unbounded growth
    for _ in 0..<(OutboundFlowInspector.maxTrackedFlows + 50) {
      _ = inspector.begin(flowID: UUID(), kind: .tls)
    }
    precondition(inspector.trackedFlowCount == OutboundFlowInspector.maxTrackedFlows)

    print("macOS outbound flow inspector checks passed")
  }
}
