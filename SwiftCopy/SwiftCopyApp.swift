import SwiftUI

@main
struct SwiftCopyApp: App {
    @StateObject var settings = AppSettings()
    
    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About SwiftCopy") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [:])
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    openNewWindow()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView(settings: settings)
        }
    }
    
    private func openNewWindow() {
        let bundleURL = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config, completionHandler: nil)
    }
}
