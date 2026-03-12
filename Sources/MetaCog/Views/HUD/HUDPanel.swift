import AppKit
import SwiftUI

/// The floating HUD panel anchored at bottom-center of the screen, 12pt above the Dock.
///
/// **Height is dynamic:** compact (80px) when no project is active, expanded (130px)
/// when a project timeline is visible. Call `resize(height:)` to animate between sizes
/// while keeping the panel anchored at the bottom.
@MainActor
final class HUDPanel: NSPanel {
    private static let panelWidth: CGFloat = 360
    /// Initial height — compact mode (no active project).
    private static let compactHeight: CGFloat = 80

    init(appState: AppState) {
        let initialSize = NSSize(width: Self.panelWidth, height: Self.compactHeight)
        super.init(
            contentRect: NSRect(origin: .zero, size: initialSize),
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

    /// Re-anchors the HUD at bottom-center of the main screen, 12pt above the Dock.
    /// Called on init and after any event that may displace the panel (e.g. sheet dismiss).
    func positionAtBottomCenter() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        let size = frame.size
        let x = visibleFrame.midX - size.width / 2
        let y = visibleFrame.minY + 12
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// Resizes the HUD to a new height and re-anchors at bottom-center.
    /// The width stays fixed. The origin is recalculated so the panel stays
    /// pinned to the bottom of the screen during the transition.
    func resize(height: CGFloat) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        let newSize = NSSize(width: Self.panelWidth, height: height)
        let x = visibleFrame.midX - Self.panelWidth / 2
        let y = visibleFrame.minY + 12
        let newFrame = NSRect(origin: NSPoint(x: x, y: y), size: newSize)

        // Animate the resize for a smooth transition.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(newFrame, display: true)
        }
    }
}
