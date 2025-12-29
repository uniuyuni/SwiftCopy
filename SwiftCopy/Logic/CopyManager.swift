import Foundation

class CopyManager {
    static func copy(source: URL, dest: URL, preserveAttributes: Bool = true) throws {
        let fileManager = FileManager.default
        
        // Ensure parent directory exists
        let destParent = dest.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: destParent.path) {
            try fileManager.createDirectory(at: destParent, withIntermediateDirectories: true, attributes: nil)
        }
        
        // If dest exists, remove it first (overwrite)
        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
        
        try fileManager.copyItem(at: source, to: dest)
        
        if preserveAttributes {
            try copyAttributes(source: source, dest: dest)
        } else {
            // Fix: FileManager.copyItem preserves attributes by default. 
            // If we strictly don't want to preserve them, we must explicitly update dates to "now".
            let now = Date()
            try fileManager.setAttributes([.modificationDate: now, .creationDate: now], ofItemAtPath: dest.path)
        }
    }
    
    static func copyAttributes(source: URL, dest: URL) throws {
        let fileManager = FileManager.default
        // Copy attributes (modification date and creation date)
        // We filter attributes to avoid setting read-only ones which might cause failure
        let attributes = try fileManager.attributesOfItem(atPath: source.path)
        var newAttributes: [FileAttributeKey: Any] = [:]
        
        if let modDate = attributes[.modificationDate] {
            newAttributes[.modificationDate] = modDate
        }
        if let creationDate = attributes[.creationDate] {
            newAttributes[.creationDate] = creationDate
        }
        
        if !newAttributes.isEmpty {
            try fileManager.setAttributes(newAttributes, ofItemAtPath: dest.path)
        }
    }
}
