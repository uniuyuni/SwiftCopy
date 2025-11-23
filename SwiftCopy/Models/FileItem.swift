import Foundation

struct FileItem: Identifiable, Equatable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let modificationDate: Date
    let size: Int64
    let isDirectory: Bool
    var children: [FileItem]?
    
    init(url: URL, isDirectory: Bool, modificationDate: Date = Date(), size: Int64 = 0, children: [FileItem]? = nil) {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.modificationDate = modificationDate
        self.size = size
        self.children = children
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        return lhs.url == rhs.url && lhs.modificationDate == rhs.modificationDate && lhs.size == rhs.size
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
