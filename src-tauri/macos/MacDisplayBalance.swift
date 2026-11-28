import Foundation

/// Strictly informational display-only snapshot of earned screen-time balance.
/// Never read by enforcement or credit-spending code (`BloomFilterDataProvider`,
/// `FilterCreditClock`, or `MacUsageStore`).
enum MacDisplayBalance {
  static let enabledKey = "displayCreditEnabled"
  static let minutesKey = "displayCreditBalanceMinutes"
  static let syncedAtKey = "displayCreditSyncedAtMillis"
  static let maxAgeMillis: Double = 86_400_000

  struct Snapshot: Equatable {
    let creditsEnabled: Bool
    let balanceMinutes: Double?
  }

  static func read(from defaults: UserDefaults, nowMillis: Double = Date().timeIntervalSince1970 * 1000) -> Snapshot {
    guard defaults.bool(forKey: enabledKey) else {
      return Snapshot(creditsEnabled: false, balanceMinutes: nil)
    }
    guard let syncedAt = (defaults.object(forKey: syncedAtKey) as? NSNumber)?.doubleValue,
          let minutes = (defaults.object(forKey: minutesKey) as? NSNumber)?.doubleValue,
          syncedAt.isFinite, nowMillis.isFinite,
          nowMillis >= syncedAt, (nowMillis - syncedAt) <= maxAgeMillis,
          minutes.isFinite, minutes >= 0 else {
      return Snapshot(creditsEnabled: true, balanceMinutes: nil)
    }
    return Snapshot(creditsEnabled: true, balanceMinutes: minutes)
  }

  static func formatHint(_ snapshot: Snapshot) -> String? {
    guard snapshot.creditsEnabled, let minutes = snapshot.balanceMinutes else {
      return nil
    }
    if minutes >= 1 {
      return "You have \(Int(floor(minutes))) min of earned screen time ready in Bloom."
    }
    if minutes > 0 {
      return "You have less than 1 min of earned screen time. Complete an activity in Bloom to earn more."
    }
    return "0 min earned right now. Complete Exercise, Study, Reading, or Tasks in Bloom to earn screen time."
  }
}
