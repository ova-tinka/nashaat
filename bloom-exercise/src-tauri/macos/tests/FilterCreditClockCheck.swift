import Foundation

@main struct FilterCreditClockCheck {
  static func main() {
    let config: [String: Any] = ["creditBoot": NSNumber(value: 7), "creditDeadlineMillis": NSNumber(value: 11000.0)]
    precondition(FilterCreditClock.isAllowed(configuration: config, now: 10999, boot: 7))
    precondition(!FilterCreditClock.isAllowed(configuration: config, now: 11000, boot: 7))
    precondition(!FilterCreditClock.isAllowed(configuration: config, now: 100, boot: 8))
    precondition(!FilterCreditClock.isAllowed(configuration: nil, now: 100, boot: 7))
    precondition(FilterCreditClock.deadline(duration: 10000, requestElapsed: 1000, now: 1500, requestBoot: 7, boot: 7) == 11000)
    precondition(FilterCreditClock.deadline(duration: 10000, requestElapsed: 1000, now: 12000, requestBoot: 7, boot: 7) == nil)
    precondition(FilterCreditClock.deadline(duration: 10000, requestElapsed: 1000, now: 1500, requestBoot: 7, boot: 8) == nil)
    print("macOS credit clock checks passed")
  }
}
