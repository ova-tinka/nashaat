import CryptoKit
import Foundation

enum MacServiceRegistrationPolicy {
  static func fingerprint(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  static func fingerprint(at url: URL) throws -> String {
    fingerprint(try Data(contentsOf: url, options: .mappedIfSafe))
  }

  static func shouldRefresh(isRegistered: Bool, registeredFingerprint: String?, currentFingerprint: String) -> Bool {
    isRegistered && registeredFingerprint != currentFingerprint
  }
}
