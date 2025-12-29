import Foundation
import Combine
import SwiftUI

enum OverwriteRule: String, CaseIterable, Identifiable {
    case ifNewer = "If Newer"
    case always = "Always"
    case never = "Never"
    
    var id: String { self.rawValue }
}

class AppSettings: ObservableObject {
    @AppStorage("overwriteRule") var overwriteRule: OverwriteRule = .ifNewer
    @AppStorage("copyHiddenFiles") var copyHiddenFiles: Bool = false
    @AppStorage("recursiveScan") var recursiveScan: Bool = true
    @AppStorage("preserveAttributes") var preserveAttributes: Bool = true
    @AppStorage("compareByHash") var compareByHash: Bool = false
}
