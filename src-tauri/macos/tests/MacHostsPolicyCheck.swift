import Foundation

@main struct MacHostsPolicyCheck {
  static func main() throws {
    let original = Data("# local config\r\n127.0.0.1 localhost\n# keep without newline".utf8)
    let blocked = try MacHostsPolicy.transform(original, domains: ["Example.com", "bücher.example"])
    precondition(blocked != original)
    let retried = try MacHostsPolicy.transform(blocked, domains: ["example.com", "xn--bcher-kva.example"])
    let removed = try MacHostsPolicy.transform(blocked, domains: [])
    precondition(retried == blocked)
    precondition(removed == original)
    let changed = try MacHostsPolicy.transform(blocked, domains: ["other.example"])
    let removedChanged = try MacHostsPolicy.transform(changed, domains: [])
    precondition(removedChanged == original)
    let unicodeOriginal = Data("\u{feff}# cafe\u{301}\r\n127.0.0.1 localhost\r\n# untouched".utf8)
    let unicodeBlocked = try MacHostsPolicy.transform(unicodeOriginal, domains: ["example.com"])
    precondition(unicodeBlocked.starts(with: [0xef, 0xbb, 0xbf]))
    let unicodeRemoved = try MacHostsPolicy.transform(unicodeBlocked, domains: [])
    precondition(unicodeRemoved == unicodeOriginal)
    let externalEdit = Data("# added before\n".utf8) + blocked + Data("\n# added after\n".utf8)
    let preservedEdit = try MacHostsPolicy.transform(externalEdit, domains: [])
    precondition(preservedEdit == Data("# added before\n".utf8) + original + Data("\n# added after\n".utf8))
    for sample in ["", "\n", "# comment", "127.0.0.1 localhost\r\n", "# one\n\n# two\n", "# سلام\n# emoji 🌱"] {
      let input = Data(sample.utf8)
      let applied = try MacHostsPolicy.transform(input, domains: ["example.com"])
      let restored = try MacHostsPolicy.transform(applied, domains: [])
      precondition(restored == input)
    }
    let conflict = Data("127.0.0.1 localhost\n192.0.2.1 example.com # managed elsewhere\n".utf8)
    do { _ = try MacHostsPolicy.transform(conflict, domains: ["example.com"]); preconditionFailure("unmanaged conflict accepted") } catch {}
    let aliasConflict = Data("127.0.0.1 localhost EXAMPLE.COM. # leave untouched\r\n".utf8)
    do { _ = try MacHostsPolicy.transform(aliasConflict, domains: ["example.com"]); preconditionFailure("unmanaged alias accepted") } catch {}
    let truncated = Data("# BEGIN BLOOM MANAGED v1\n127.0.0.1 example.com # bloom\n".utf8)
    do { _ = try MacHostsPolicy.transform(truncated, domains: []); preconditionFailure("partial block accepted") } catch {}
    let altered = Data("# BEGIN BLOOM MANAGED v1\n127.0.0.1 example.com # bloom\n# somebody else's line\n# END BLOOM MANAGED v1\n".utf8)
    do { _ = try MacHostsPolicy.transform(altered, domains: []); preconditionFailure("altered block accepted") } catch {}
    let twice = blocked + blocked
    do { _ = try MacHostsPolicy.transform(twice, domains: []); preconditionFailure("duplicate block accepted") } catch {}
    let unknownMarker = Data("# BEGIN BLOOM MANAGED v2\n".utf8)
    do { _ = try MacHostsPolicy.transform(unknownMarker, domains: ["example.com"]); preconditionFailure("unknown marker accepted") } catch {}
    for domain in ["localhost", "127.0.0.1", "https://example.com/path", "bad host", "*.example.com", "-bad.example", "example.com\nother.test"] {
      do { _ = try MacHostsPolicy.transform(original, domains: [domain]); preconditionFailure("invalid domain accepted") } catch {}
    }
    do { _ = try MacHostsPolicy.transform(Data([0xff]), domains: ["example.com"]); preconditionFailure("invalid encoding accepted") } catch {}
    do { _ = try MacHostsPolicy.transform(Data([0]), domains: ["example.com"]); preconditionFailure("NUL accepted") } catch {}
    do { _ = try MacHostsPolicy.transform(Data(repeating: 0x61, count: 1_048_577), domains: []); preconditionFailure("oversized file accepted") } catch {}
    print("macOS hosts policy checks passed")
  }
}
