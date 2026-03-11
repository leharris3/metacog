import SwiftUI

@main
struct MetaCogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use AppDelegate to manage windows directly (NSPanel for HUD)
        Settings {
            SettingsView()
        }

        Window("Dashboard", id: "dashboard") {
            DashboardView()
                .environmentObject(AppState.shared)
        }
        .defaultSize(width: 900, height: 600)
    }
}
