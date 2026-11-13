import Darwin
import Foundation

@main struct MacHostsCrashCheck {
  static func main() throws {
    if CommandLine.arguments.count == 4 && CommandLine.arguments[1] == "child" {
      let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
      let point = CommandLine.arguments[3]
      let crash = { _ = kill(getpid(), SIGKILL) }
      let held = point == "after-swap-edited" ? open(root.appendingPathComponent("hosts").path, O_WRONLY | O_CLOEXEC) : -1
      let crashAfterSwap = {
        if held >= 0 {
          let edited = Data("127.0.0.1 localhost\n# another editor\n".utf8)
          precondition(ftruncate(held, 0) == 0 && lseek(held, 0, SEEK_SET) == 0)
          precondition(edited.withUnsafeBytes { write(held, $0.baseAddress, edited.count) } == edited.count)
        }
        _ = kill(getpid(), SIGKILL)
      }
      let store = MacHostsTransaction(directory: root, expectedOwner: getuid())
      try store.apply(domains: point == "cleanup-after-swap" ? [] : ["example.com"],
        afterStageCreated: point == "staged" ? crash : nil,
        beforeCommit: point == "before-swap" ? crash : nil,
        afterCommit: point == "after-swap" || point == "after-swap-edited" || point == "cleanup-after-swap" ? crashAfterSwap : nil)
      preconditionFailure("crash hook did not terminate")
    }

    for point in ["staged", "before-swap", "after-swap", "after-swap-edited", "cleanup-after-swap"] {
      let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      defer { try? FileManager.default.removeItem(at: root) }
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
      let hosts = root.appendingPathComponent("hosts")
      let original = Data("127.0.0.1 localhost\n# isolated fixture\n".utf8)
      try original.write(to: hosts)
      if point == "cleanup-after-swap" {
        try MacHostsTransaction(directory: root, expectedOwner: getuid()).apply(domains: ["example.com"])
      }
      let child = Process()
      child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
      child.arguments = ["child", root.path, point]
      child.standardOutput = Pipe(); child.standardError = Pipe()
      try child.run(); child.waitUntilExit()
      precondition(child.terminationReason == .uncaughtSignal && child.terminationStatus == SIGKILL)
      let store = MacHostsTransaction(directory: root, expectedOwner: getuid())
      if point == "after-swap-edited" {
        precondition(MacHostsRecovery.status { try store.recoverInterruptedTransactions() } == "review")
        let directory = root.appendingPathComponent(".bloom-hosts")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
          .filter { $0.lastPathComponent.hasPrefix("conflict-") }
        precondition(files.count == 1 && (try? Data(contentsOf: files[0])) == Data("127.0.0.1 localhost\n# another editor\n".utf8))
        precondition((try? Data(contentsOf: hosts)) != original)
      } else if point == "cleanup-after-swap" {
        precondition(MacHostsRecovery.status { try store.recoverInterruptedTransactions() } == "clear")
        precondition((try? Data(contentsOf: hosts)) == original)
      } else if point == "after-swap" {
        precondition(MacHostsRecovery.status { try store.recoverInterruptedTransactions() } == "clear")
        precondition((try? Data(contentsOf: hosts)) != original)
        try store.apply(domains: [])
        precondition((try? Data(contentsOf: hosts)) == original)
      } else {
        precondition(MacHostsRecovery.status { try store.recoverInterruptedTransactions() } == "clear")
        precondition((try? Data(contentsOf: hosts)) == original)
        let directory = root.appendingPathComponent(".bloom-hosts")
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        precondition(!files.contains { $0.hasPrefix("txn-") || $0.hasPrefix("conflict-") })
      }
    }
    print("macOS hosts process interruption checks passed")
  }
}
