import Foundation

// Mocking the environment for testing
let fileManager = FileManager.default
let tempDir = fileManager.temporaryDirectory.appendingPathComponent("SwiftCopyTest_\(UUID().uuidString)")
var sourceDir = tempDir.appendingPathComponent("Source")
var destDir = tempDir.appendingPathComponent("Dest")

func setup() throws {
    try? fileManager.removeItem(at: tempDir)
    try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true, attributes: nil)
    try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)
    
    // Resolve symlinks after creation
    print("Original Source: \(sourceDir.path)")
    sourceDir = sourceDir.resolvingSymlinksInPath()
    print("Resolved Source: \(sourceDir.path)")
    
    destDir = destDir.resolvingSymlinksInPath()
    
    // Hack for macOS /var vs /private/var issue in tests
    if sourceDir.path.hasPrefix("/var/") {
        sourceDir = URL(fileURLWithPath: "/private" + sourceDir.path)
    }
    if destDir.path.hasPrefix("/var/") {
        destDir = URL(fileURLWithPath: "/private" + destDir.path)
    }
    
    print("Final Source: \(sourceDir.path)")
    
    // Create File A in Source (Newer)
    let fileA = sourceDir.appendingPathComponent("FileA.txt")
    try "Content A".write(to: fileA, atomically: true, encoding: .utf8)
    let dateA = Date()
    try fileManager.setAttributes([.modificationDate: dateA], ofItemAtPath: fileA.path)
    
    // Create File A in Dest (Older)
    let destFileA = destDir.appendingPathComponent("FileA.txt")
    try "Old Content A".write(to: destFileA, atomically: true, encoding: .utf8)
    let dateOld = dateA.addingTimeInterval(-100)
    try fileManager.setAttributes([.modificationDate: dateOld], ofItemAtPath: destFileA.path)
    
    // Create File B in Source (Only in Source)
    let fileB = sourceDir.appendingPathComponent("FileB.txt")
    try "Content B".write(to: fileB, atomically: true, encoding: .utf8)
    
    // Create Subfolder and File D
    let subDir = sourceDir.appendingPathComponent("Sub")
    try fileManager.createDirectory(at: subDir, withIntermediateDirectories: true, attributes: nil)
    let fileD = subDir.appendingPathComponent("FileD.txt")
    try "Content D".write(to: fileD, atomically: true, encoding: .utf8)
}

func testScanner() {
    print("--- Testing Scanner ---")
    // Test Recursive
    let itemsRecursive = FileScanner.scan(path: sourceDir, recursive: true)
    print("Found \(itemsRecursive.count) items in source (recursive).")
    // Should be FileA, FileB, Sub (FileD is inside Sub)
    // Wait, FileScanner returns top level items, and children are inside.
    // So top level: FileA, FileB, Sub. Count = 3.
    assert(itemsRecursive.count == 3, "Should find 3 top level items")
    
    let subDirItem = itemsRecursive.first { $0.name == "Sub" }
    assert(subDirItem != nil, "Sub directory should exist")
    assert(subDirItem?.children?.count == 1, "Sub directory should have 1 child")
    assert(subDirItem?.children?.first?.name == "FileD.txt", "Child should be FileD.txt")
    
    // Test Non-Recursive
    // Actually FileScanner.scan always returns children structure if recursive=true.
    // If recursive=false, children should be nil or empty?
    // Let's check implementation.
    // Implementation: if isDirectory && recursive { children = scan(...) }
    
    let itemsNonRecursive = FileScanner.scan(path: sourceDir, recursive: false)
    let subDirItemNR = itemsNonRecursive.first { $0.name == "Sub" }
    assert(subDirItemNR?.children == nil, "Sub directory should have no children when recursive is false")
}

func testComparator() {
    print("\n--- Testing Comparator ---")
    let items = FileScanner.scan(path: sourceDir, recursive: true)
    
    for item in items {
        let destItemURL = destDir.appendingPathComponent(item.name)
        let status = DateComparator.compare(source: item, destPath: destItemURL, rule: .ifNewer)
        print("File: \(item.name), Status: \(status)")
        
        if item.name == "FileA.txt" {
            assert(status == .copy, "FileA should be copy (newer)")
        } else if item.name == "FileB.txt" {
            assert(status == .copy, "FileB should be copy (missing)")
        } else if item.name == "Sub" {
            // Folder itself might be .copy if it doesn't exist?
            // DateComparator for folder: if dest doesn't exist -> .copy.
            // If exists -> .done (or .skip/traverse?)
            // Let's check DateComparator logic for folders.
        }
    }
}

func testCopy() {
    print("\n--- Testing Copy ---")
    let items = FileScanner.scan(path: sourceDir, recursive: true)
    
    func copyItem(_ item: FileItem, relativeTo source: URL, destRoot: URL) {
        let sourcePath = source.standardized.path
        let itemPath = item.url.standardized.path
        
        guard itemPath.hasPrefix(sourcePath) else {
            print("Error: Item path \(itemPath) does not start with source path \(sourcePath)")
            return
        }
        
        let relativePath = String(itemPath.dropFirst(sourcePath.count))
        let destItemURL = URL(fileURLWithPath: destRoot.standardized.path + relativePath)
        
        print("Copying: \(item.name)")
        print("  Source: \(itemPath)")
        print("  Dest:   \(destItemURL.path)")
        
        let status = DateComparator.compare(source: item, destPath: destItemURL, rule: .ifNewer)
        
        if status == .copy {
            do {
                if item.isDirectory {
                    try fileManager.createDirectory(at: destItemURL, withIntermediateDirectories: true, attributes: nil)
                } else {
                    try CopyManager.copy(source: item.url, dest: destItemURL, preserveAttributes: true)
                }
                print("Copied \(item.name)")
            } catch {
                print("Failed to copy \(item.name): \(error)")
            }
        }
        
        if let children = item.children {
            for child in children {
                copyItem(child, relativeTo: source, destRoot: destRoot)
            }
        }
    }
    
    for item in items {
        copyItem(item, relativeTo: sourceDir, destRoot: destDir)
    }
    
    // Verify FileB exists
    let destFileB = destDir.appendingPathComponent("FileB.txt")
    assert(fileManager.fileExists(atPath: destFileB.path))
    
    // Verify FileA content updated
    let destFileA = destDir.appendingPathComponent("FileA.txt")
    let content = try! String(contentsOf: destFileA, encoding: .utf8)
    assert(content == "Content A")
    
    // Verify Sub/FileD exists
    let destFileD = destDir.appendingPathComponent("Sub").appendingPathComponent("FileD.txt")
    print("Checking existence of: \(destFileD.path)")
    if fileManager.fileExists(atPath: destFileD.path) {
        print("File exists!")
    } else {
        print("File NOT found!")
        // List contents of Dest
        if let enumerator = fileManager.enumerator(at: destDir, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                print("Found in Dest: \(fileURL.path)")
            }
        }
    }
    assert(fileManager.fileExists(atPath: destFileD.path))
}

@main
struct VerifyLogic {
    static func main() {
        do {
            try setup()
            testScanner()
            testComparator()
            testCopy()
            print("\nAll tests passed!")
        } catch {
            print("Test failed: \(error)")
            exit(1)
        }
    }
}
