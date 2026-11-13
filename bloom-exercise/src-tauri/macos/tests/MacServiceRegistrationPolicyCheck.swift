import Foundation

@main struct MacServiceRegistrationPolicyCheck {
  static func main() {
    let old = MacServiceRegistrationPolicy.fingerprint(Data("old helper".utf8))
    let current = MacServiceRegistrationPolicy.fingerprint(Data("updated helper".utf8))

    precondition(old != current)
    precondition(!MacServiceRegistrationPolicy.shouldRefresh(
      isRegistered: false, registeredFingerprint: nil, currentFingerprint: current))
    precondition(MacServiceRegistrationPolicy.shouldRefresh(
      isRegistered: true, registeredFingerprint: nil, currentFingerprint: current))
    precondition(!MacServiceRegistrationPolicy.shouldRefresh(
      isRegistered: true, registeredFingerprint: current, currentFingerprint: current))
    precondition(MacServiceRegistrationPolicy.shouldRefresh(
      isRegistered: true, registeredFingerprint: old, currentFingerprint: current))
    print("macOS helper registration refresh checks passed")
  }
}
