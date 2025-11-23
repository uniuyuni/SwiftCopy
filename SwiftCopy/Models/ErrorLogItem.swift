import Foundation

struct ErrorLogItem: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let message: String
    let fileURL: URL?
}
