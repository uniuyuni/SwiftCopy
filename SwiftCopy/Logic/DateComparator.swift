import Foundation
import CryptoKit

class DateComparator {
    static func compare(source: FileItem, destRoot: URL) -> ComparisonStatus {
         return .skip // Placeholder
    }
    
    static func compare(source: FileItem, destPath: URL, rule: OverwriteRule = .ifNewer, compareByHash: Bool = false) -> ComparisonStatus {
        let fileManager = FileManager.default
        
        // Check if dest exists
        if !fileManager.fileExists(atPath: destPath.path) {
            return .add // New file
        }
        
        // If exists, check rule
        switch rule {
        case .always:
            return .update
        case .never:
            return .skip
        case .ifNewer:
            // Continue to check
            break
        }
        
        // Get dest attributes info
        do {
            let attributes = try fileManager.attributesOfItem(atPath: destPath.path)
            let destDate = attributes[.modificationDate] as? Date ?? Date.distantPast
            let destSize = attributes[.size] as? Int64 ?? -1
            
            // HASH COMPARISON MODE
            if compareByHash {
                // 1. Fast check: Size
                if source.size != destSize {
                     return .update
                }
                
                // 2. Slow check: Hash
                if let sourceHash = calculateHash(url: source.url),
                   let destHash = calculateHash(url: destPath) {
                    if sourceHash != destHash {
                        return .update
                    } else {
                        return .skip // Same content
                    }
                } else {
                    // Fallback if hash fetch fails (e.g. permission)
                    // Treat as update to be safe? Or fallback to date?
                    // Let's fallback to date if hash fails, or just return .error?
                    // Safe approach: Update if we can't verify they are same.
                    return .update 
                }
            }
            
            // DATE COMPARISON MODE (Default)
            
            // We add a small tolerance (e.g. 2 seconds) to handle file system differences (HFS+ vs APFS vs FAT32)
            // and copy delays.
            let tolerance: TimeInterval = 2.0
            
            if source.modificationDate.timeIntervalSinceReferenceDate > destDate.timeIntervalSinceReferenceDate + tolerance {
                return .update
            } else if abs(source.modificationDate.timeIntervalSinceReferenceDate - destDate.timeIntervalSinceReferenceDate) <= tolerance {
                return .skip
            } else {
                return .skip // Dest is newer
            }
            
        } catch {
            print("Error getting attributes for dest: \(error)")
            return .error // Or treat as missing?
        }
    }
    
    private static func calculateHash(url: URL) -> String? {
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            defer { try? fileHandle.close() }
            
            var hasher = SHA256()
            while autoreleasepool(invoking: {
                let data = fileHandle.readData(ofLength: 1024 * 1024) // 1MB chunks
                if !data.isEmpty {
                    hasher.update(data: data)
                    return true
                }
                return false
            }) {}
            
            let digest = hasher.finalize()
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        } catch {
            print("Hash calculation failed for \(url.path): \(error)")
            return nil
        }
    }
}
