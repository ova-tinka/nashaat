import ManagedSettings

class ShieldActionExtensionImpl: ShieldActionExtension {

    override func handle(
        action: ShieldAction,
        for application: Application,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        // Primary = "Let's Work Out" → close shield so user returns to Nashaat
        // Secondary = "Close" → same
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomain,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomain,
        in application: Application,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }
}
