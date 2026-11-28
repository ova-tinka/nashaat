import AppKit
import Foundation

@MainActor final class MacAppShieldOverlay {
  enum ShieldTarget: Equatable {
    case app(bundleID: String, displayName: String, isManaged: Bool)
    case website(host: String, browserBundleID: String, browserName: String, isManaged: Bool)
    case unreadableBrowser(browserBundleID: String, browserName: String)
  }

  private final class ShieldWindow: NSWindow {
    var onEscape: (() -> Void)?
    var onConfirm: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
      if event.keyCode == 53 { // Escape
        onEscape?()
        return
      }
      if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
        onConfirm?()
        return
      }
      super.keyDown(with: event)
    }
  }

  private final class ActionTarget: NSObject {
    let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    @objc func invoke() { handler() }
  }

  private var windows: [NSWindow] = []
  private var actionTargets: [ActionTarget] = []
  private var activeTarget: ShieldTarget?
  private var activeBalanceHint: String?
  private var activeIcon: NSImage?
  private var activeOnOpenBloom: (() -> Void)?
  private var activeOnSwitchAway: (() -> Void)?
  private var screenObserver: NSObjectProtocol?

  var isVisible: Bool { !windows.isEmpty }

  func show(target: ShieldTarget, appIcon: NSImage?, balanceHint: String?,
            onOpenBloom: @escaping () -> Void, onSwitchAway: @escaping () -> Void) {
    if !windows.isEmpty, activeTarget == target, activeBalanceHint == balanceHint {
      for window in windows {
        window.orderFrontRegardless()
      }
      windows.first?.makeKeyAndOrderFront(nil)
      NSApplication.shared.activate(ignoringOtherApps: true)
      return
    }

    render(target: target, appIcon: appIcon, balanceHint: balanceHint,
           onOpenBloom: onOpenBloom, onSwitchAway: onSwitchAway)
  }

  private func render(target: ShieldTarget, appIcon: NSImage?, balanceHint: String?,
                      onOpenBloom: @escaping () -> Void, onSwitchAway: @escaping () -> Void) {
    dismissWindowsOnly()
    activeTarget = target
    activeBalanceHint = balanceHint
    activeIcon = appIcon
    activeOnOpenBloom = onOpenBloom
    activeOnSwitchAway = onSwitchAway

    if screenObserver == nil {
      screenObserver = NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
          guard let self, let currentTarget = self.activeTarget,
                let openHandler = self.activeOnOpenBloom,
                let switchHandler = self.activeOnSwitchAway,
                !self.windows.isEmpty else { return }
          self.render(target: currentTarget, appIcon: self.activeIcon,
                      balanceHint: self.activeBalanceHint,
                      onOpenBloom: openHandler, onSwitchAway: switchHandler)
        }
      }
    }

    let screens = NSScreen.screens
    guard !screens.isEmpty else { return }

    let mouseLocation = NSEvent.mouseLocation
    let primaryScreen = screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main ?? screens[0]
    let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

    var primaryWindow: NSWindow?
    for screen in screens {
      let window = ShieldWindow(
        contentRect: screen.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false,
        screen: screen
      )
      window.onEscape = onSwitchAway
      window.onConfirm = onOpenBloom
      window.level = .statusBar
      window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
      window.isOpaque = false
      window.backgroundColor = .clear
      window.hasShadow = false
      window.ignoresMouseEvents = false
      window.isReleasedWhenClosed = false

      let backdrop = NSVisualEffectView(frame: NSRect(origin: .zero, size: screen.frame.size))
      backdrop.autoresizingMask = [.width, .height]
      backdrop.blendingMode = .behindWindow
      backdrop.material = .hudWindow
      backdrop.state = .active

      let tint = NSView(frame: backdrop.bounds)
      tint.autoresizingMask = [.width, .height]
      tint.wantsLayer = true
      tint.layer?.backgroundColor = (isDark
        ? NSColor(calibratedRed: 0x10 / 255.0, green: 0x16 / 255.0, blue: 0x2B / 255.0, alpha: 0.86)
        : NSColor(calibratedRed: 0xF7 / 255.0, green: 0xF9 / 255.0, blue: 0xFF / 255.0, alpha: 0.82)).cgColor
      backdrop.addSubview(tint)

      if screen == primaryScreen {
        let card = buildCard(
          target: target,
          appIcon: appIcon,
          balanceHint: balanceHint,
          isDark: isDark,
          onOpenBloom: onOpenBloom,
          onSwitchAway: onSwitchAway
        )
        card.frame = NSRect(
          x: round((backdrop.bounds.width - card.frame.width) / 2),
          y: round((backdrop.bounds.height - card.frame.height) / 2),
          width: card.frame.width,
          height: card.frame.height
        )
        card.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
        backdrop.addSubview(card)
        primaryWindow = window
      }

      window.contentView = backdrop
      window.orderFrontRegardless()
      windows.append(window)
    }

    NSApplication.shared.activate(ignoringOtherApps: true)
    (primaryWindow ?? windows.first)?.makeKeyAndOrderFront(nil)
  }

  private func dismissWindowsOnly() {
    for window in windows {
      window.orderOut(nil)
      window.close()
    }
    windows.removeAll()
    actionTargets.removeAll()
  }

  func dismiss() {
    dismissWindowsOnly()
    if let screenObserver {
      NotificationCenter.default.removeObserver(screenObserver)
      self.screenObserver = nil
    }
    activeTarget = nil
    activeBalanceHint = nil
    activeIcon = nil
    activeOnOpenBloom = nil
    activeOnSwitchAway = nil
  }

  private func buildCard(target: ShieldTarget, appIcon: NSImage?, balanceHint: String?, isDark: Bool,
                         onOpenBloom: @escaping () -> Void, onSwitchAway: @escaping () -> Void) -> NSView {
    let badgeText: String
    let titleText: String
    let bodyText: String
    let primaryTitle: String
    let secondaryTitle: String
    let resolvedIcon: NSImage?
    let showBalance: Bool

    switch target {
    case .app(let bundleID, let displayName, let isManaged):
      let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
      let name = cleanName.isEmpty ? (bundleID.isEmpty ? "This app" : bundleID) : cleanName
      badgeText = isManaged ? "FAMILY RULE" : "BLOOM FOCUS"
      titleText = "\(name) is blocked by Bloom"
      bodyText = (isManaged
        ? "A parent-managed rule is blocking this app on this Mac."
        : "App protection is currently active on this Mac.")
        + "\n\nComplete Exercise, Study, Reading, or Tasks to earn screen time, or start an earned session in Bloom."
      primaryTitle = "Open Bloom to unlock"
      secondaryTitle = "Switch away"
      resolvedIcon = appIcon ?? NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "Blocked app")
      showBalance = balanceHint != nil
    case .website(let host, _, let browserName, let isManaged):
      badgeText = isManaged ? "FAMILY RULE" : "BLOOM FOCUS"
      titleText = "\(host) is blocked by Bloom"
      bodyText = (isManaged
        ? "A parent-managed rule is blocking this website in \(browserName)."
        : "Website protection is active in \(browserName).")
        + "\n\nComplete Exercise, Study, Reading, or Tasks to earn screen time, or start an earned session in Bloom."
      primaryTitle = "Open Bloom to unlock"
      secondaryTitle = "Hide \(browserName)"
      resolvedIcon = NSImage(systemSymbolName: "globe", accessibilityDescription: "Blocked website") ?? appIcon
      showBalance = balanceHint != nil
    case .unreadableBrowser(_, let browserName):
      badgeText = "BLOOM FOCUS"
      titleText = "\(browserName) needs permission"
      bodyText = "Bloom cannot inspect the active tab address in \(browserName) while website protection is active.\n\nAllow Automation or Accessibility for Bloom in System Settings, or switch away."
      primaryTitle = "Open Bloom"
      secondaryTitle = "Hide \(browserName)"
      resolvedIcon = NSImage(systemSymbolName: "exclamationmark.shield.fill", accessibilityDescription: "Permission required") ?? appIcon
      showBalance = false
    }

    let width: CGFloat = 480
    let balanceOffset: CGFloat = showBalance ? 46 : 0
    let height: CGFloat = 414 + balanceOffset
    let card = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
    card.wantsLayer = true
    card.layer?.cornerRadius = 24
    card.layer?.borderWidth = 1
    card.layer?.backgroundColor = (isDark
      ? NSColor(calibratedRed: 0x18 / 255.0, green: 0x21 / 255.0, blue: 0x3A / 255.0, alpha: 1)
      : NSColor.white).cgColor
    card.layer?.borderColor = (isDark
      ? NSColor(calibratedRed: 0x34 / 255.0, green: 0x41 / 255.0, blue: 0x5F / 255.0, alpha: 1)
      : NSColor(calibratedRed: 0xDF / 255.0, green: 0xE6 / 255.0, blue: 0xF1 / 255.0, alpha: 1)).cgColor
    card.layer?.shadowColor = NSColor(calibratedRed: 0x12 / 255.0, green: 0x1E / 255.0, blue: 0x3E / 255.0, alpha: 1).cgColor
    card.layer?.shadowOpacity = isDark ? 0.42 : 0.14
    card.layer?.shadowRadius = 28
    card.layer?.shadowOffset = NSSize(width: 0, height: -8)

    let inkColor = isDark
      ? NSColor(calibratedRed: 0xF4 / 255.0, green: 0xF6 / 255.0, blue: 0xFF / 255.0, alpha: 1)
      : NSColor(calibratedRed: 0x14 / 255.0, green: 0x1B / 255.0, blue: 0x35 / 255.0, alpha: 1)
    let mutedColor = isDark
      ? NSColor(calibratedRed: 0xC0 / 255.0, green: 0xC8 / 255.0, blue: 0xE0 / 255.0, alpha: 1)
      : NSColor(calibratedRed: 0x58 / 255.0, green: 0x67 / 255.0, blue: 0x84 / 255.0, alpha: 1)
    let accentColor = isDark
      ? NSColor(calibratedRed: 0x8D / 255.0, green: 0xB3 / 255.0, blue: 0xFF / 255.0, alpha: 1)
      : NSColor(calibratedRed: 0x1E / 255.0, green: 0x5E / 255.0, blue: 0xBE / 255.0, alpha: 1)
    let softSurface = isDark
      ? NSColor(calibratedRed: 0x22 / 255.0, green: 0x2C / 255.0, blue: 0x49 / 255.0, alpha: 1)
      : NSColor(calibratedRed: 0xED / 255.0, green: 0xF2 / 255.0, blue: 0xFA / 255.0, alpha: 1)

    let badge = NSTextField(labelWithString: badgeText)
    badge.font = NSFont.systemFont(ofSize: 11, weight: .bold)
    badge.textColor = accentColor
    badge.alignment = .center
    badge.frame = NSRect(x: 36, y: height - 48, width: width - 72, height: 18)
    card.addSubview(badge)

    let iconView = NSImageView(frame: NSRect(x: (width - 64) / 2, y: height - 126, width: 64, height: 64))
    iconView.imageScaling = .scaleProportionallyUpOrDown
    iconView.contentTintColor = accentColor
    iconView.image = resolvedIcon
    card.addSubview(iconView)

    let titleLabel = NSTextField(wrappingLabelWithString: titleText)
    titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
    titleLabel.textColor = inkColor
    titleLabel.alignment = .center
    titleLabel.frame = NSRect(x: 36, y: height - 194, width: width - 72, height: 54)
    card.addSubview(titleLabel)

    let subtitleLabel = NSTextField(wrappingLabelWithString: bodyText)
    subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
    subtitleLabel.textColor = mutedColor
    subtitleLabel.alignment = .center
    subtitleLabel.frame = NSRect(x: 40, y: 142 + balanceOffset, width: width - 80, height: 84)
    card.addSubview(subtitleLabel)

    if showBalance, let balanceHint {
      let pill = NSView(frame: NSRect(x: 40, y: 142, width: width - 80, height: 34))
      pill.wantsLayer = true
      pill.layer?.cornerRadius = 10
      pill.layer?.backgroundColor = softSurface.cgColor
      let pillLabel = NSTextField(labelWithString: balanceHint)
      pillLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
      pillLabel.textColor = accentColor
      pillLabel.alignment = .center
      pillLabel.lineBreakMode = .byTruncatingTail
      pillLabel.frame = NSRect(x: 12, y: 8, width: pill.bounds.width - 24, height: 18)
      pill.addSubview(pillLabel)
      card.addSubview(pill)
    }

    let primaryButton = makeButton(
      title: primaryTitle,
      frame: NSRect(x: 40, y: 92, width: width - 80, height: 42),
      background: accentColor,
      foreground: isDark ? NSColor(calibratedRed: 0x10 / 255.0, green: 0x1A / 255.0, blue: 0x33 / 255.0, alpha: 1) : .white,
      font: NSFont.systemFont(ofSize: 14, weight: .semibold),
      action: onOpenBloom
    )
    card.addSubview(primaryButton)

    let secondaryButton = makeButton(
      title: secondaryTitle,
      frame: NSRect(x: 40, y: 42, width: width - 80, height: 40),
      background: softSurface,
      foreground: inkColor,
      font: NSFont.systemFont(ofSize: 14, weight: .medium),
      action: onSwitchAway
    )
    card.addSubview(secondaryButton)

    let hintLabel = NSTextField(labelWithString: "Press Return to open Bloom · Esc to switch away")
    hintLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
    hintLabel.textColor = mutedColor
    hintLabel.alignment = .center
    hintLabel.frame = NSRect(x: 36, y: 14, width: width - 72, height: 18)
    card.addSubview(hintLabel)

    return card
  }

  private func makeButton(title: String, frame: NSRect, background: NSColor, foreground: NSColor,
                          font: NSFont, action: @escaping () -> Void) -> NSButton {
    let target = ActionTarget(action)
    actionTargets.append(target)
    let button = NSButton(frame: frame)
    button.title = ""
    button.isBordered = false
    button.wantsLayer = true
    button.layer?.backgroundColor = background.cgColor
    button.layer?.cornerRadius = 12
    button.attributedTitle = NSAttributedString(
      string: title,
      attributes: [
        .foregroundColor: foreground,
        .font: font,
      ]
    )
    button.target = target
    button.action = #selector(ActionTarget.invoke)
    return button
  }

  static func openBloomApp() {
    if let deepLink = URL(string: "bloomexercise://focus?section=earned"),
       NSWorkspace.shared.open(deepLink) {
      return
    }
    var bundleURL = URL(fileURLWithPath: "/Applications/Bloom.app")
    if let executable = NSRunningApplication.current.executableURL {
      let candidate = executable
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
      if candidate.pathExtension == "app" {
        bundleURL = candidate
      }
    }
    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in }
  }
}
