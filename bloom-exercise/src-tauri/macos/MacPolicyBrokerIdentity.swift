import Foundation
import Security

enum MacPolicyBrokerIdentity {
  // TeamIdentifier is signing information, so Security.framework omits it
  // unless kSecCSSigningInformation is requested.
  static let signingInformationFlags = SecCSFlags(rawValue: kSecCSSigningInformation)

  private static func signingInformation(for code: SecCode) -> [String: Any]? {
    var staticCode: SecStaticCode?
    guard SecCodeCopyStaticCode(code, SecCSFlags(rawValue: 0), &staticCode) == errSecSuccess,
          let staticCode else { return nil }
    var information: CFDictionary?
    guard SecCodeCopySigningInformation(staticCode, signingInformationFlags, &information) == errSecSuccess else { return nil }
    return information as? [String: Any]
  }

  static func signingTeamForCurrentProcess() -> String? {
    var code: SecCode?
    guard SecCodeCopySelf(SecCSFlags(rawValue: 0), &code) == errSecSuccess,
          let code, let values = signingInformation(for: code) else { return nil }
    return values[kSecCodeInfoTeamIdentifier as String] as? String
  }

  static func signingIdentifier(for pid: pid_t) -> (identifier: String, team: String?)? {
    let attributes = [kSecGuestAttributePid as String: NSNumber(value: pid)] as CFDictionary
    var code: SecCode?
    guard SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(rawValue: 0), &code) == errSecSuccess,
          let code, let values = signingInformation(for: code),
          let identifier = values[kSecCodeInfoIdentifier as String] as? String else { return nil }
    return (identifier, values[kSecCodeInfoTeamIdentifier as String] as? String)
  }
}
