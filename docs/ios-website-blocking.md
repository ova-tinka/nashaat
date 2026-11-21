# iPhone website blocking

## Enforcement paths

- **Always rules** are applied with `ManagedSettingsStore.webContent.blockedByFilter` and `WebContentSettings.FilterPolicy.specific`. Apple documents this policy as blocking the specified domains and caps it at 50 domains. Bloom keeps these settings in a named store so clearing app shields for an earned session does not clear Always rules.
- **Focus-only rules** are supplied by Bloom's Safari content-blocker extension. The extension must be enabled by the user in **Settings → Safari → Extensions**. Bloom reloads the extension when Focus starts, stops, or an earned access window suspends Focus blocking.
- **Manual Focus selections** use Apple's Family Activity picker and a separate `bloom.manual.focus` Managed Settings store. The current iOS implementation runs until stopped; it does not offer a duration or recurring routines. Selections remain device- and profile-specific. Apple supplies opaque selection tokens, so Bloom cannot list or identify individual selected items in its own UI.
- Website input is normalized to a host; URL paths and query strings are not used as rules. The account's rule list is capped at 50 distinct Always domains in both app validation and the database, including concurrent inserts.

Apple references: [FilterPolicy.specific](https://developer.apple.com/documentation/managedsettings/webcontentsettings/filterpolicy/specific%28_%3A%29), [WebDomain.init(domain:)](https://developer.apple.com/documentation/managedsettings/webdomain/init%28domain%3A%29), [Safari content blockers](https://developer.apple.com/documentation/safariservices/creating-a-content-blocker), and [Apple's explanation of named stores](https://developer.apple.com/videos/play/wwdc2022/110336/).

## Known platform behavior

Apple's `WebContentSettings` documentation defines website filtering but doesn't promise that every third-party browser enforces the same rules. Always rules need confirmation in each browser used on-device. Focus-only rules are explicitly Safari-only. Apple's Screen Time team also documents that enabling a web content filter disables Safari Private Browsing while the filter is active ([Apple Developer Forums](https://developer.apple.com/forums/thread/729808)).

## Device acceptance checks

Use harmless domains and a signed iPhone build with Screen Time authorization:

1. Add `example.com` as Always. Confirm a new navigation to that site is blocked while Focus is off, and `example.org` still loads. Repeat with any additional browser whose behavior Bloom intends to claim.
2. Add `example.net` as Focus-only. Enable Bloom's Safari extension in Settings. Confirm it is reachable with Focus off, blocked in Safari during Focus, and reachable again after stopping Focus.
3. Start an earned access window. Confirm Focus-only Safari rules suspend and Always rules remain active. Confirm Focus rules resume after the access window ends.
4. Remove an Always rule and sync. Confirm its domain becomes reachable after a new navigation. Check that removing rules does not remove the user's other Screen Time restrictions.
5. Add the 50th unique Always domain, then try a 51st. The 50th should apply and the 51st should be rejected without changing existing rules.
6. Record Safari Private Browsing behavior and the extension's enabled state. Do not infer browser coverage from the extension status alone.
7. With a disposable profile and harmless targets, select a different app or domain for Manual Focus and start it. Verify a temporary earned-access window does not clear the manual shield. Stop Manual Focus and verify the separate Always and Focus rules remain as configured. Repeat after app restart, permission revocation, and profile switching. Do not treat a saved selection or a successful API call as proof that the OS enforced the shield.
