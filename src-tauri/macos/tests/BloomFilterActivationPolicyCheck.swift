@main struct BloomFilterActivationPolicyCheck {
  static func main() {
    precondition(BloomFilterActivationPolicy.shouldSubmitRequest(alreadyActive: false))
    precondition(!BloomFilterActivationPolicy.shouldSubmitRequest(alreadyActive: true))
    print("macOS extension activation request policy checks passed")
  }
}
