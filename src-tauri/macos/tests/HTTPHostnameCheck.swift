import Foundation

@main struct HTTPHostnameCheck {
  static func main() {
    precondition(HTTPHostname.shouldInspect(isStream: true, remotePort: "80"))
    precondition(!HTTPHostname.shouldInspect(isStream: true, remotePort: "443"))
    precondition(!HTTPHostname.shouldInspect(isStream: true, remotePort: nil))
    precondition(!HTTPHostname.shouldInspect(isStream: false, remotePort: "80"))

    let standard = Data("GET /path HTTP/1.1\r\nHost: example.com\r\n\r\n".utf8)
    precondition(HTTPHostname.parse(standard) == .host("example.com"))

    let withPort = Data("POST /api HTTP/1.1\r\nhost: \tSub.Example.COM:80 \r\nUser-Agent: test\r\n\r\n".utf8)
    precondition(HTTPHostname.parse(withPort) == .host("sub.example.com"))

    let fragmented = Data("GET / HTTP/1.1\r\nUser-Agent: test\r\nHost: example.com\r\n\r\n".utf8)
    let hostLineEnd = fragmented.range(of: Data("Host: example.com\r\n".utf8))!.upperBound
    for count in 0..<hostLineEnd {
      let result = HTTPHostname.parse(fragmented.prefix(count))
      if case .need = result { continue }
      preconditionFailure("Expected .need at prefix \(count), got \(result)")
    }
    precondition(HTTPHostname.parse(fragmented.prefix(hostLineEnd)) == .host("example.com"))

    let missingHost = Data("GET / HTTP/1.1\r\nUser-Agent: test\r\n\r\n".utf8)
    precondition(HTTPHostname.parse(missingHost) == .unknown)

    precondition(HTTPHostname.parse(Data([22, 3, 1, 0, 5])) == .unknown)
    precondition(HTTPHostname.parse(Data("get / HTTP/1.1\r\nHost: example.com\r\n\r\n".utf8)) == .unknown)

    let oversized = Data(("GET / HTTP/1.1\r\nX-Pad: " + String(repeating: "a", count: 4200) + "\r\nHost: example.com\r\n\r\n").utf8)
    precondition(HTTPHostname.parse(oversized) == .unknown)

    precondition(HTTPHostname.parse(Data("GET / HTTP/1.1\r\nHost: bad host\r\n\r\n".utf8)) == .unknown)
    precondition(HTTPHostname.parse(Data("GET / HTTP/1.1\r\nHost: example.com:notaport\r\n\r\n".utf8)) == .unknown)
    precondition(HTTPHostname.parse(Data("GET / HTTP/1.1\r\nHost: example.com:99999\r\n\r\n".utf8)) == .unknown)

    print("macOS HTTP hostname checks passed")
  }
}
