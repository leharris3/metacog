import Cocoa
import ApplicationServices

enum Accessibility {
    static func activateApp(_ app: NSRunningApplication) {
        if app.activate() { return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        let value: AnyObject = kCFBooleanTrue
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, value)
    }
}
