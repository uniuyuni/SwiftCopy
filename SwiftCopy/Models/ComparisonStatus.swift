import Foundation

enum ComparisonStatus {
    case add // Source exists, dest missing -> Add
    case update // Source is newer -> Update
    case skip // Dest is newer or same -> Skip
    case done // Copied successfully
    case error // Failed to copy
    
    var icon: String {
        switch self {
        case .add: return "plus.circle"
        case .update: return "arrow.triangle.2.circlepath"
        case .skip: return ""
        case .done: return "checkmark"
        case .error: return "exclamationmark.triangle"
        }
    }
}
