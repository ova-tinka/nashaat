import Foundation

@main struct MacHostsRecoveryCheck {
  static func main() {
    precondition(MacHostsRecovery.status({}) == "clear")
    precondition(MacHostsRecovery.status({ throw MacHostsTransaction.Failure.recoveryRequired }) == "review")
    precondition(MacHostsRecovery.status({ throw MacHostsTransaction.Failure.busy }) == "busy")
    precondition(MacHostsRecovery.status({ throw MacHostsTransaction.Failure.unsafeFile }) == "unsafe")
    precondition(MacHostsRecovery.status({ throw MacHostsTransaction.Failure.unsafeDirectory }) == "unsafe")
    precondition(MacHostsRecovery.status({ throw MacHostsTransaction.Failure.io }) == "unavailable")
    print("macOS hosts recovery status checks passed")
  }
}
