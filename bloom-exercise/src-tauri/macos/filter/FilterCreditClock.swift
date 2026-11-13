import Darwin
import Foundation

/// Credit deadlines use a boot-bound monotonic clock shared by the host and
/// system extension. A missing or changed boot marker always denies access.
struct FilterCreditClock {
  static func nowMillis() -> Double {
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    return Double(mach_continuous_time()) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000
  }

  static func boot() -> Int64? {
    var value = timeval()
    var length = MemoryLayout<timeval>.size
    var name = [CTL_KERN, KERN_BOOTTIME]
    guard sysctl(&name, u_int(name.count), &value, &length, nil, 0) == 0, value.tv_sec > 0 else { return nil }
    return Int64(value.tv_sec)
  }

  static func isAllowed(configuration: [String: Any]?, now: Double, boot: Int64?) -> Bool {
    guard let configuration, let boot, boot > 0,
          let savedBoot = configuration["creditBoot"] as? NSNumber, savedBoot.int64Value == boot,
          let deadline = configuration["creditDeadlineMillis"] as? NSNumber,
          deadline.doubleValue.isFinite, now.isFinite, now >= 0 else { return false }
    return now < deadline.doubleValue
  }

  static func isAllowed(configuration: [String: Any]?) -> Bool {
    isAllowed(configuration: configuration, now: nowMillis(), boot: boot())
  }

  static func deadline(duration: Double, requestElapsed: Double, now: Double, requestBoot: Int64, boot: Int64?) -> Double? {
    guard duration.isFinite, requestElapsed.isFinite, now.isFinite, duration >= 1000, duration <= 86400000,
          requestElapsed >= 0, now >= requestElapsed, let boot, boot > 0, requestBoot == boot else { return nil }
    let remaining = duration - (now - requestElapsed)
    return remaining >= 1000 ? now + remaining : nil
  }
}
