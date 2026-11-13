import Foundation

/// Reads only the unencrypted server name in the first TLS ClientHello.
enum TLSHostname {
  enum Result: Equatable { case need(Int), host(String), unknown }
  static let maximum = 16_384

  // An unavailable endpoint is not evidence of a non-HTTPS connection.
  // Inspect its first bytes, but only a matching TLS hostname can block it.
  static func shouldInspect(isStream: Bool, remotePort: String?) -> Bool {
    isStream && (remotePort == nil || remotePort == "443")
  }

  static func parse(_ data: Data) -> Result {
    let input = [UInt8](data)
    guard !input.isEmpty else { return .need(1) }
    var bytes: [UInt8] = []
    var offset = 0
    var handshakeEnd: Int?
    while handshakeEnd == nil || bytes.count < handshakeEnd! {
      guard offset + 5 <= maximum else { return .unknown }
      guard input.count >= offset + 1 else { return .need(offset + 1) }
      guard input[offset] == 22 else { return .unknown }
      guard input.count >= offset + 5 else { return .need(offset + 5) }
      guard input[offset + 1] == 3 else { return .unknown }
      let length = Int(input[offset + 3]) * 256 + Int(input[offset + 4])
      let end = offset + 5 + length
      guard length > 0, end <= maximum else { return .unknown }
      guard input.count >= end else { return .need(end) }
      bytes.append(contentsOf: input[(offset + 5)..<end])
      offset = end
      if handshakeEnd == nil && bytes.count >= 4 {
        guard bytes[0] == 1 else { return .unknown }
        let end = 4 + Int(bytes[1]) * 65536 + Int(bytes[2]) * 256 + Int(bytes[3])
        guard end <= maximum else { return .unknown }
        handshakeEnd = end
      }
    }
    guard let handshakeEnd else { return .unknown }
    var i = 4
    func take(_ n: Int) -> Bool { guard n >= 0, i <= handshakeEnd - n else { return false }; i += n; return true }
    func byte() -> Int? { guard take(1) else { return nil }; return Int(bytes[i - 1]) }
    func word() -> Int? { guard take(2) else { return nil }; return Int(bytes[i - 2]) * 256 + Int(bytes[i - 1]) }
    guard take(34), let session = byte(), take(session), let suites = word(), take(suites),
          let compression = byte(), take(compression), let extensionLength = word(),
          extensionLength <= handshakeEnd - i else { return .unknown }
    let extensionsEnd = i + extensionLength
    while i < extensionsEnd {
      guard let type = word(), let length = word(), length <= extensionsEnd - i else { return .unknown }
      let end = i + length
      if type == 0 {
        guard let namesLength = word(), namesLength <= end - i else { return .unknown }
        let namesEnd = i + namesLength
        while i < namesEnd {
          guard let kind = byte(), let size = word(), size <= namesEnd - i else { return .unknown }
          if kind == 0 {
            let name = String(bytes: bytes[i..<(i + size)], encoding: .utf8)
            guard let name, let host = WebsiteRules.host(name) else { return .unknown }
            return .host(host)
          }
          guard take(size) else { return .unknown }
        }
      }
      i = end
    }
    return .unknown
  }
}
