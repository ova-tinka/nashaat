enum BloomFilterActivationPolicy {
  static func shouldSubmitRequest(alreadyActive: Bool) -> Bool {
    !alreadyActive
  }
}
