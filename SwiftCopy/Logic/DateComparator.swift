import Foundation

class DateComparator {
    static func compare(source: FileItem, destRoot: URL) -> ComparisonStatus {
        // Construct the destination URL for this item
        // We assume source is relative to some root, but here we just have the item.
        // Wait, to compare, we need to know the relative path of the source item to the source root,
        // and apply that to the dest root.
        // The current FileItem doesn't store relative path. 
        // We might need to adjust the logic.
        // For now, let's assume the caller handles the path resolution or we pass the relative path.
        
        // Let's change the signature to take the full dest URL for this specific item.
        return .skip // Placeholder, see updated implementation below
    }
    
    static func compare(source: FileItem, destPath: URL, rule: OverwriteRule = .ifNewer) -> ComparisonStatus {
        let fileManager = FileManager.default
        
        // Check if dest exists
        if !fileManager.fileExists(atPath: destPath.path) {
            return .copy // New file
        }
        
        // If exists, check rule
        switch rule {
        case .always:
            return .copy
        case .never:
            return .skip
        case .ifNewer:
            // Continue to date check
            break
        }
        
        // Get dest attributes info
        do {
            let attributes = try fileManager.attributesOfItem(atPath: destPath.path)
            let destDate = attributes[.modificationDate] as? Date ?? Date.distantPast
            
            // 3. Compare dates
            // Spec: Source > Dest -> Copy
            // Spec: Dest >= Source -> Skip
            // Spec: Same -> Skip
            
            // We can add a small tolerance for file systems (e.g. 1 second) if needed, 
            // but spec says "Date comparison accuracy: Second/Minute". 
            // Let's stick to strict comparison for now.
            
            // We add a small tolerance (e.g. 2 seconds) to handle file system differences (HFS+ vs APFS vs FAT32)
            // and copy delays.
            let tolerance: TimeInterval = 2.0
            
            if source.modificationDate.timeIntervalSinceReferenceDate > destDate.timeIntervalSinceReferenceDate + tolerance {
                return .copy
            } else if abs(source.modificationDate.timeIntervalSinceReferenceDate - destDate.timeIntervalSinceReferenceDate) <= tolerance {
                 return .done // Same
            } else {
                return .skip // Dest is newer
            }
            
        } catch {
            print("Error getting attributes for dest: \(error)")
            return .error // Or treat as missing?
        }
    }
}
