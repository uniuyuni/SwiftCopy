import SwiftUI

@main
struct SwiftCopyApp: App {
    @StateObject var settings = AppSettings()

    let sourceURL: URL?
    let destURL: URL?

    init() {
        var source: URL?
        var dest: URL?

        let args = CommandLine.arguments
        for i in 0..<args.count {
            if args[i] == "-source" && i + 1 < args.count {
                source = URL(fileURLWithPath: args[i + 1])
            }
            if (args[i] == "-dest" || args[i] == "-target") && i + 1 < args.count {
                dest = URL(fileURLWithPath: args[i + 1])
            }
        }

        self.sourceURL = source
        self.destURL = dest
    }

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings, sourceURL: sourceURL, destURL: destURL)
        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About SwiftCopy") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [:])
                }
            }

        }

        Settings {
            SettingsView(settings: settings)
        }
    }

}
