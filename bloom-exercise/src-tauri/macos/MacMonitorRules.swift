import Foundation

enum MacMonitorRules {
  static func shouldCountWebsiteUse(eligibleBlockedHost: String?) -> Bool {
    eligibleBlockedHost != nil
  }

  static func didHideSuccessfully(callAccepted: Bool, isHidden: Bool, isTerminated: Bool) -> Bool {
    isTerminated || (callAccepted && isHidden)
  }
}
