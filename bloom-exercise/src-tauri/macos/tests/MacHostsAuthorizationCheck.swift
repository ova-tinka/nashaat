import Foundation
import Security

@main struct MacHostsAuthorizationCheck {
  static func main() {
    precondition(!MacHostsAdminGrant.validate(Data()))
    precondition(!MacHostsAdminGrant.validate(Data(repeating: 0, count: Int(kAuthorizationExternalFormLength))))
    precondition(!MacHostsAdminGrant.validate(Data(repeating: 0, count: Int(kAuthorizationExternalFormLength) + 1)))
    print("macOS hosts authorization rejection checks passed")
  }
}
