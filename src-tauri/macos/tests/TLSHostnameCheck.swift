import Foundation

@main struct TLSHostnameCheck {
  static func main() {
    precondition(TLSHostname.shouldInspect(isStream: true, remotePort: nil))
    precondition(TLSHostname.shouldInspect(isStream: true, remotePort: "443"))
    precondition(!TLSHostname.shouldInspect(isStream: true, remotePort: "80"))
    precondition(!TLSHostname.shouldInspect(isStream: false, remotePort: nil))
    precondition(!TLSHostname.shouldInspect(isStream: false, remotePort: "443"))
    if CommandLine.arguments.contains("--stdin") {
      guard case let .host(hostname) = TLSHostname.parse(FileHandle.standardInput.readDataToEndOfFile()) else { preconditionFailure("TLS hostname was not parsed") }
      print(hostname)
      return
    }
    func word(_ n: Int) -> [UInt8] { [UInt8((n >> 8) & 255), UInt8(n & 255)] }
    let host = Array("example.com".utf8)
    let names = [UInt8(0)] + word(host.count) + host
    let serverName = word(names.count) + names
    let extensions = word(0) + word(serverName.count) + serverName
    var hello = [UInt8](repeating: 0, count: 34)
    hello += [0]; hello += word(2); hello += [0x13, 0x01]; hello += [1, 0]
    hello += word(extensions.count); hello += extensions
    let handshake = [UInt8(1), 0, 0, UInt8(hello.count)] + hello
    let record = [UInt8(22), 3, 3] + word(handshake.count) + handshake
    precondition(TLSHostname.parse(Data(record)) == .host("example.com"))
    for split in 1..<handshake.count {
      let first = Array(handshake[..<split])
      let second = Array(handshake[split...])
      let fragmented = [UInt8(22), 3, 3] + word(first.count) + first
        + [UInt8(22), 3, 3] + word(second.count) + second
      precondition(TLSHostname.parse(Data(fragmented)) == .host("example.com"))
      let partial = Array(fragmented.prefix(5 + first.count))
      precondition(TLSHostname.parse(Data(partial)) == .need(partial.count + 1))
    }
    if case let .host(parsed) = TLSHostname.parse(Data(record)) {
      let rules = WebsiteRules(configuration: ["blockedDomains": ["example.com"]])
      precondition(rules.blocks(parsed))
      precondition(!WebsiteRules(configuration: ["blockedDomains": ["another.com"]]).blocks(parsed))
    } else { preconditionFailure("TLS hostname was not parsed") }
    precondition(TLSHostname.parse(Data(record.prefix(3))) == .need(5))
    precondition(TLSHostname.parse(Data(record.prefix(5))) == .need(record.count))
    precondition(TLSHostname.parse(Data([0x47])) == .unknown)
    var malformed = record; malformed[3] = 255; malformed[4] = 255
    precondition(TLSHostname.parse(Data(malformed)) == .unknown)
    var wrongHandshake = record; wrongHandshake[5] = 2
    precondition(TLSHostname.parse(Data(wrongHandshake)) == .unknown)
    for count in 0..<record.count { _ = TLSHostname.parse(Data(record.prefix(count))) }
    var seed: UInt64 = 1
    for length in 0..<1024 {
      var bytes = [UInt8]()
      for _ in 0..<length {
        seed = seed &* 6364136223846793005 &+ 1
        bytes.append(UInt8(truncatingIfNeeded: seed >> 32))
      }
      _ = TLSHostname.parse(Data(bytes))
    }
    print("macOS TLS hostname checks passed")
  }
}
