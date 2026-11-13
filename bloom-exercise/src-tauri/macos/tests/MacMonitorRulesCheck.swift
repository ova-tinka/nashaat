import Foundation

@main struct MacMonitorRulesCheck {
  static func main() {
    precondition(!MacMonitorRules.shouldCountWebsiteUse(eligibleBlockedHost: nil))
    precondition(MacMonitorRules.shouldCountWebsiteUse(eligibleBlockedHost: "example.com"))
    precondition(!MacMonitorRules.didHideSuccessfully(callAccepted: false, isHidden: false, isTerminated: false))
    precondition(!MacMonitorRules.didHideSuccessfully(callAccepted: true, isHidden: false, isTerminated: false))
    precondition(MacMonitorRules.didHideSuccessfully(callAccepted: true, isHidden: true, isTerminated: false))
    precondition(MacMonitorRules.didHideSuccessfully(callAccepted: false, isHidden: false, isTerminated: true))
    print("macOS monitor policy checks passed")
  }
}
