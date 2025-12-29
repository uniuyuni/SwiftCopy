import Cocoa
import FinderSync

class FinderSyncController: FIFinderSync {

    var myFolderURL: URL = URL(fileURLWithPath: "/")

    override init() {
        super.init()
        
        NSLog("FinderSync() launched from %@", Bundle.main.bundlePath)
        
        // Monitor all folders (or a specific set if desired, but user wants generic "Drop")
        // Note: Finder Sync extensions usually monitor specific directories. 
        // For general "Open with...", a Service/Action is better, but Finder Sync can add toolbar items/context menus.
        // We will try to monitor the user's home directory or volumes to be broadly active.
        // FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")] // Root might be too aggressive
        if let home = FileManager.default.urls(for: .userDirectory, in: .localDomainMask).first {
             FIFinderSyncController.default().directoryURLs = [home]
        }
    }

    // MARK: - Menu and Toolbar

    override var toolbarItemName: String {
        return "SwiftCopy"
    }

    override var toolbarItemToolTip: String {
        return "Open selected folder in SwiftCopy"
    }

    override var toolbarItemImage: NSImage {
        return NSImage(named: NSImage.cautionName)! // Placeholder
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        // Produce a menu for the extension.
        
        // Check selection: Single item AND Directory
        guard let items = FIFinderSyncController.default().selectedItemURLs(),
              items.count == 1,
              let url = items.first else {
            return nil
        }
        
        // Fast check if directory
        // Note: For remote URLs or slow checks, this might block UI slightly, but usually fine for local Finder.
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue {
            let menu = NSMenu(title: "")
            _ = menu.addItem(withTitle: "Open with SwiftCopy", action: #selector(openWithSwiftCopy(_:)), keyEquivalent: "")
            return menu
        }
        
        return nil
    }


    @IBAction func openWithSwiftCopy(_ sender: AnyObject?) {
        guard let target = FIFinderSyncController.default().selectedItemURLs()?.first else {
            return
        }
        
        NSLog("Opening SwiftCopy with source: %@", target.path)
        
        var components = URLComponents()
        components.scheme = "swiftcopy"
        components.host = "set-source"
        components.queryItems = [URLQueryItem(name: "path", value: target.path)]
        
        guard let url = components.url else { return }
        
        // Find the app explicitly to avoid "Choose Application" prompt
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.uniuyuni.SwiftCopy") {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            
            NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: config) { app, error in
                if let error = error {
                    NSLog("Failed to open URL: %@", error.localizedDescription)
                    // Fallback to generic open if specific launch fails
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            // Fallback if app not found by ID (e.g. not registered yet)
            NSWorkspace.shared.open(url)
        }
    }

}
