import Foundation

/// Reads only the unencrypted HTTP Host header from the first request headers.
enum HTTPHostname {
  enum Result: Equatable { case need(Int), host(String), unknown }
  static let maximum = 4_096

  static func shouldInspect(isStream: Bool, remotePort: String?) -> Bool {
    isStream && remotePort == "80"
  }

  static func parse(_ data: Data) -> Result {
    guard !data.isEmpty else { return .need(1) }
    let input = [UInt8](data.prefix(maximum))
    var spaceIndex: Int?
    let methodLimit = min(input.count, 16)
    for index in 0..<methodLimit {
      let byte = input[index]
      if byte == 0x20 {
        spaceIndex = index
        break
      }
      guard byte >= 65 && byte <= 90 else { return .unknown }
    }
    if spaceIndex == nil {
      if input.count < 16 && data.count < maximum {
        return .need(input.count + 1)
      }
      return .unknown
    }
    guard let spaceIndex, spaceIndex > 0 else { return .unknown }

    guard let firstNewline = input.firstIndex(of: 0x0A) else {
      return data.count >= maximum ? .unknown : .need(data.count + 1)
    }

    var lineStart = firstNewline + 1
    while lineStart < input.count {
      guard let newline = input[lineStart...].firstIndex(of: 0x0A) else {
        return data.count >= maximum ? .unknown : .need(data.count + 1)
      }
      var lineEnd = newline
      if lineEnd > lineStart && input[lineEnd - 1] == 0x0D {
        lineEnd -= 1
      }
      if lineEnd == lineStart {
        return .unknown
      }
      if let line = String(bytes: input[lineStart..<lineEnd], encoding: .ascii) {
        if line.count >= 5 && line.prefix(5).lowercased() == "host:" {
          let rawValue = String(line.dropFirst(5)).trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
          guard !rawValue.isEmpty,
                rawValue.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
                rawValue.rangeOfCharacter(from: CharacterSet(charactersIn: "/@?#[]")) == nil else {
            return .unknown
          }
          let hostPart: String
          if let colon = rawValue.firstIndex(of: ":") {
            let portPart = rawValue[rawValue.index(after: colon)...]
            guard !portPart.isEmpty,
                  portPart.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let portNumber = Int(portPart), (1...65535).contains(portNumber) else {
              return .unknown
            }
            hostPart = String(rawValue[..<colon])
          } else {
            hostPart = rawValue
          }
          guard let host = WebsiteRules.host(hostPart) else { return .unknown }
          return .host(host)
        }
      }
      lineStart = newline + 1
    }
    return data.count >= maximum ? .unknown : .need(data.count + 1)
  }
}
