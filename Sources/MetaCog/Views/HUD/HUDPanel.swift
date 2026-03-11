import AppKit
import SwiftUI

@MainActor
final class HUDPanel: NSPanel {
    private static let defaultSize = NSSize(width: 360, height: 80)

    init(appState: AppState) {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .hudWindow],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .clear
        isOpaque = false
        // hasShadow = true lets the window compositor draw the panel shadow.
        // It follows the rounded shape because we mask the hosting view's
        // CALayer below, making the corners truly transparent at the AppKit
        // level (not just visually clipped by SwiftUI).
        hasShadow = true

        let hudView = HUDContentView()
            .environmentObject(appState)
        let hostingView = NSHostingView(rootView: hudView)

        // Clip the hosting view's layer to a rounded rect so the window shadow
        // traces the rounded shape instead of the rectangular frame.
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 14
        hostingView.layer?.masksToBounds = true

        contentView = hostingView
        positionAtBottomCenter()
    }

    override var canBecomeKey: Bool { true }

    private func positionAtBottomCenter() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.midX - Self.defaultSize.width / 2
        let y = visibleFrame.minY + 12
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
