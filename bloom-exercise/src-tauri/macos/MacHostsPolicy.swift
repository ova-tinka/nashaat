import Foundation

/// Pure transformation only. The privileged file transaction and authorization
/// must be supplied separately; this type never opens or writes a file.
enum MacHostsPolicy {
  enum Failure: Error { case invalidFile, invalidDomain, conflict, damagedBlock, tooLarge }
  private static let begin = "# BEGIN BLOOM MANAGED v1\n"
  private static let end = "# END BLOOM MANAGED v1\n"
  private static let beginToken = "# BEGIN BLOOM MANAGED"
  private static let endToken = "# END BLOOM MANAGED"
  private static let limit = 1_048_576

  static func transform(_ data: Data, domains: [String]) throws -> Data {
    guard data.count <= limit else { throw Failure.tooLarge }
    let input = String(decoding: data, as: UTF8.self)
    guard Data(input.utf8) == data, !input.contains("\0") else { throw Failure.invalidFile }
    guard domains.count <= 500 else { throw Failure.invalidDomain }
    let requested = try Set(domains.map(normalize)).sorted()
    let beginCount = count(beginToken, in: input)
    let endCount = count(endToken, in: input)
    let before: String
    let after: String
    if beginCount == 0 && endCount == 0 {
      if input.hasPrefix("\u{feff}"), let bom = input.range(of: "\u{feff}") {
        before = String(input[..<bom.upperBound]); after = String(input[bom.upperBound...])
      } else {
        before = ""; after = input
      }
    } else {
      guard beginCount == 1, endCount == 1,
            let start = input.range(of: begin), let finish = input.range(of: end),
            start.lowerBound == input.startIndex || input[..<start.lowerBound] == "\u{feff}" || input[input.index(before: start.lowerBound)] == "\n",
            start.upperBound <= finish.lowerBound else { throw Failure.damagedBlock }
      let body = String(input[start.upperBound..<finish.lowerBound])
      guard let existing = parseBody(body), renderBody(existing) == body else { throw Failure.damagedBlock }
      before = String(input[..<start.lowerBound])
      after = String(input[finish.upperBound...])
    }
    let unmanaged = before + after
    let requestedSet = Set(requested)
    var examinedNames = 0
    for line in unmanaged.split(whereSeparator: \.isNewline) {
      let content = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
      let fields = content.split(whereSeparator: \.isWhitespace)
      if fields.count > 1 {
        for field in fields.dropFirst() {
          examinedNames += 1
          if examinedNames > 20_000 { throw Failure.tooLarge }
          if let host = try? normalize(String(field)), requestedSet.contains(host) { throw Failure.conflict }
        }
      }
    }
    let block = requested.isEmpty ? "" : begin + renderBody(requested) + end
    let output = Data((before + block + after).utf8)
    guard output.count <= limit else { throw Failure.tooLarge }
    return output
  }

  private static func count(_ token: String, in text: String) -> Int {
    var total = 0
    var start = text.startIndex
    while let range = text.range(of: token, options: .caseInsensitive, range: start..<text.endIndex) {
      total += 1; start = range.upperBound
    }
    return total
  }

  private static func normalize(_ raw: String) throws -> String {
    let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !input.isEmpty, input.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
          input.rangeOfCharacter(from: CharacterSet(charactersIn: ":/@?#*\\")) == nil,
          let host = WebsiteRules.host(input) else { throw Failure.invalidDomain }
    let labels = host.split(separator: ".", omittingEmptySubsequences: false)
    guard labels.count > 1, !labels.allSatisfy({ $0.allSatisfy(\.isNumber) }),
          labels.allSatisfy({ $0.range(of: "^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$", options: .regularExpression) != nil }) else {
      throw Failure.invalidDomain
    }
    return host
  }

  private static func renderBody(_ domains: [String]) -> String {
    domains.map { "127.0.0.1 \($0) # bloom\n::1 \($0) # bloom\n" }.joined()
  }

  private static func parseBody(_ body: String) -> [String]? {
    var domains = Set<String>()
    for line in body.split(separator: "\n") {
      let value = String(line)
      let prefix: String
      if value.hasPrefix("127.0.0.1 ") { prefix = "127.0.0.1 " }
      else if value.hasPrefix("::1 ") { prefix = "::1 " }
      else { return nil }
      guard value.hasSuffix(" # bloom") else { return nil }
      let raw = String(value.dropFirst(prefix.count).dropLast(" # bloom".count))
      guard let normalized = try? normalize(raw), normalized == raw else { return nil }
      domains.insert(normalized)
    }
    return domains.sorted()
  }
}
