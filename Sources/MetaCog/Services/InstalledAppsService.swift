import Foundation
import AppKit

struct InstalledApp: Identifiable, Hashable {
    let id: String  // bundle identifier
    let name: String
    let bundleURL: URL

    @MainActor
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: bundleURL.path)
    }
}

@MainActor
enum InstalledAppsService {
    static func fetchInstalledApps() -> [InstalledApp] {
        var apps: [String: InstalledApp] = [:]

        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications"
        ]

        let fm = FileManager.default
        for searchPath in searchPaths {
            guard let contents = try? fm.contentsOfDirectory(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: nil
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let bundleId = bundle.bundleIdentifier else { continue }

                let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent

                apps[bundleId] = InstalledApp(id: bundleId, name: name, bundleURL: url)
            }
        }

        return apps.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
