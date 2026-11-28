import Foundation

@main struct MacBrowserBridgeCheck {
  static func main() throws {
    let storeId = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

    // 1. Native messaging host manifest generation & multi-ID install
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let nativeDir = tempDir.appendingPathComponent("BraveSoftware/Brave-Browser/NativeMessagingHosts", isDirectory: true)
    let count = try MacBrowserBridgeInstaller.install(
      bridgePath: "/Applications/Bloom.app/Contents/MacOS/BloomBrowserBridge",
      directories: [nativeDir],
      extensionIds: [storeId, MacBrowserBridgeInstaller.devExtensionId]
    )
    precondition(count == 1)
    let manifestFile = nativeDir.appendingPathComponent("\(MacBrowserBridgeInstaller.hostName).json")
    let data = try Data(contentsOf: manifestFile)
    let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    precondition(parsed?["name"] as? String == MacBrowserBridgeInstaller.hostName)
    precondition(parsed?["type"] as? String == "stdio")
    precondition(parsed?["path"] as? String == "/Applications/Bloom.app/Contents/MacOS/BloomBrowserBridge")
    precondition((parsed?["allowed_origins"] as? [String]) == [
      "chrome-extension://\(storeId)/",
      "chrome-extension://\(MacBrowserBridgeInstaller.devExtensionId)/",
    ])

    // 2. External Extensions JSON installation
    let extDir = tempDir.appendingPathComponent("BraveSoftware/Brave-Browser/External Extensions", isDirectory: true)
    let extCount = try MacBrowserBridgeInstaller.installExternalExtensions(extensionId: storeId, directories: [extDir])
    precondition(extCount == 1)
    let extFile = extDir.appendingPathComponent("\(storeId).json")
    let extParsed = try JSONSerialization.jsonObject(with: Data(contentsOf: extFile)) as? [String: Any]
    precondition(extParsed?["external_update_url"] as? String == MacBrowserPolicyProfile.chromeWebStoreUpdateURL)

    // 3. Mobileconfig policy profile generation (standard & strict)
    precondition(MacBrowserPolicyProfile.isValidExtensionId(storeId))
    precondition(!MacBrowserPolicyProfile.isValidExtensionId("invalid-id"))

    let standardData = try MacBrowserPolicyProfile.mobileconfigData(extensionId: storeId, strict: false)
    let standardPlist = try PropertyListSerialization.propertyList(from: standardData, format: nil) as? [String: Any]
    let standardPayloads = standardPlist?["PayloadContent"] as? [[String: Any]] ?? []
    precondition(standardPayloads.count == 3)
    precondition(standardPayloads.contains { $0["PayloadType"] as? String == "com.brave.Browser" })
    precondition(standardPayloads.allSatisfy {
      ($0["ExtensionInstallForcelist"] as? [String]) == ["\(storeId);\(MacBrowserPolicyProfile.chromeWebStoreUpdateURL)"]
        && $0["MandatoryExtensionsForIncognitoNavigation"] == nil
        && $0["ExtensionSettings"] == nil
    })

    let strictData = try MacBrowserPolicyProfile.mobileconfigData(extensionId: storeId, strict: true)
    let strictPlist = try PropertyListSerialization.propertyList(from: strictData, format: nil) as? [String: Any]
    let strictPayloads = strictPlist?["PayloadContent"] as? [[String: Any]] ?? []
    precondition(strictPayloads.allSatisfy {
      ($0["MandatoryExtensionsForIncognitoNavigation"] as? [String]) == [storeId]
    })

    // 4. Parent-process browser heartbeat classification & throttling
    precondition(MacBrowserHeartbeat.classifyBrowser(executablePath: "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser") == "brave")
    precondition(MacBrowserHeartbeat.classifyBrowser(executablePath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome") == "chrome")
    precondition(MacBrowserHeartbeat.classifyBrowser(executablePath: "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge") == "edge")
    precondition(MacBrowserHeartbeat.classifyBrowser(executablePath: "/Applications/Arc.app/Contents/MacOS/Arc") == "arc")
    precondition(MacBrowserHeartbeat.classifyBrowser(executablePath: "/usr/bin/curl") == nil)

    precondition(MacBrowserHeartbeat.shouldWrite(lastWrittenMillis: nil, nowMillis: 1_000))
    precondition(!MacBrowserHeartbeat.shouldWrite(lastWrittenMillis: 1_000, nowMillis: 5_000))
    precondition(MacBrowserHeartbeat.shouldWrite(lastWrittenMillis: 1_000, nowMillis: 11_000))

    // 5. Native messaging length-prefix framing roundtrip
    let payload = Data("{\"type\":\"getPolicy\"}".utf8)
    guard let framed = MacNativeMessaging.encodeMessage(payload) else {
      preconditionFailure("Failed to encode native message")
    }
    precondition(framed.count == 4 + payload.count)
    let pipe = Pipe()
    pipe.fileHandleForWriting.write(framed)
    try pipe.fileHandleForWriting.close()
    precondition(MacNativeMessaging.readMessage(from: pipe.fileHandleForReading) == payload)

    // Oversized message rejected
    precondition(MacNativeMessaging.encodeMessage(Data(repeating: 0x41, count: MacNativeMessaging.maxMessageBytes + 1)) == nil)

    // 6. Display-only earned-time balance hints
    let suiteName = "bloom.test.display.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    precondition(MacDisplayBalance.read(from: defaults, nowMillis: 10_000) == MacDisplayBalance.Snapshot(creditsEnabled: false, balanceMinutes: nil))

    defaults.set(true, forKey: MacDisplayBalance.enabledKey)
    defaults.set(14.7, forKey: MacDisplayBalance.minutesKey)
    defaults.set(10_000.0, forKey: MacDisplayBalance.syncedAtKey)
    let fresh = MacDisplayBalance.read(from: defaults, nowMillis: 20_000)
    precondition(fresh == MacDisplayBalance.Snapshot(creditsEnabled: true, balanceMinutes: 14.7))
    precondition(MacDisplayBalance.formatHint(fresh) == "You have 14 min of earned screen time ready in Bloom.")

    defaults.set(0.4, forKey: MacDisplayBalance.minutesKey)
    precondition(MacDisplayBalance.formatHint(MacDisplayBalance.read(from: defaults, nowMillis: 20_000))?.contains("less than 1 min") == true)

    defaults.set(0.0, forKey: MacDisplayBalance.minutesKey)
    precondition(MacDisplayBalance.formatHint(MacDisplayBalance.read(from: defaults, nowMillis: 20_000))?.contains("0 min earned") == true)

    // Stale (> 24h) drops balanceMinutes cleanly
    let stale = MacDisplayBalance.read(from: defaults, nowMillis: 10_000 + MacDisplayBalance.maxAgeMillis + 1)
    precondition(stale == MacDisplayBalance.Snapshot(creditsEnabled: true, balanceMinutes: nil))
    precondition(MacDisplayBalance.formatHint(stale) == nil)

    print("macOS browser bridge checks passed")
  }
}
