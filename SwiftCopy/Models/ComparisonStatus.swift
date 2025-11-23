import Foundation

enum ComparisonStatus {
    case copy // Source is newer or dest missing -> Copy
    case skip // Dest is newer or same -> Skip
    case done // Copied successfully
    case error // Failed to copy
    
    var icon: String {
        switch self {
        case .copy: return "arrow.right"
        case .skip: return ""
        case .done: return "checkmark"
        case .error: return "exclamationmark.triangle"
        }
    }
}
