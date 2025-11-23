
import Foundation

class FileScanner {
    static func scan(path: URL, includeHidden: Bool = false, recursive: Bool = true) -> [FileItem] {
        let fileManager = FileManager.default
        var items: [FileItem] = []
        
        // Ensure the path is a directory
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path.path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }
        
        do {
            let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
            
            // Options for enumeration
            var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
            if !includeHidden {
                options.insert(.skipsHiddenFiles)
            }
            
            let contents = try fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: resourceKeys, options: options)
            
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                let isDirectory = resourceValues.isDirectory ?? false
                let modificationDate = resourceValues.contentModificationDate ?? Date()
                let size = Int64(resourceValues.fileSize ?? 0)
                
                var children: [FileItem]? = nil
                if isDirectory && recursive {
                    // Recursive scan for subdirectories
                    children = scan(path: url, includeHidden: includeHidden, recursive: recursive)
                }
                
                let item = FileItem(url: url, isDirectory: isDirectory, modificationDate: modificationDate, size: size, children: children)
                items.append(item)
            }
        } catch {
            print("Error scanning directory: \(error)")
        }
        
        return items.sorted { $0.name < $1.name }
    }
}
