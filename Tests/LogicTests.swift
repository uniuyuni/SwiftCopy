import XCTest
@testable import SwiftCopy

final class LogicTests: XCTestCase {
    var tempDir: URL!
    var sourceDir: URL!
    var destDir: URL!
    
    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        sourceDir = tempDir.appendingPathComponent("Source")
        destDir = tempDir.appendingPathComponent("Dest")
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDir)
    }
    
    func testComparisonMatrix() throws {
        let fileManager = FileManager.default
        
        // Scenarios
        let scenarios: [(name: String, destExists: Bool, destAge: String, rule: OverwriteRule, expected: ComparisonStatus)] = [
            // Missing Dest -> Always Copy
            ("Missing_IfNewer", false, "none", .ifNewer, .add),
            ("Missing_Always", false, "none", .always, .add),
            ("Missing_Never", false, "none", .never, .add),
            
            // Existing (Older) -> Source is Newer
            ("Older_IfNewer", true, "older", .ifNewer, .update),
            ("Older_Always", true, "older", .always, .update),
            ("Older_Never", true, "older", .never, .skip),
            
            // Existing (Newer) -> Source is Older
            ("Newer_IfNewer", true, "newer", .ifNewer, .skip),
            ("Newer_Always", true, "newer", .always, .update),
            ("Newer_Never", true, "newer", .never, .skip),
            
            // Existing (Same)
            ("Same_IfNewer", true, "same", .ifNewer, .skip),
            ("Same_Always", true, "same", .always, .update),
            ("Same_Never", true, "same", .never, .skip),
        ]
        
        for scenario in scenarios {
            print("Testing Scenario: \(scenario.name)")
            
            // Setup Source
            let sourceFile = sourceDir.appendingPathComponent("file_\(scenario.name).txt")
            try "Source".write(to: sourceFile, atomically: true, encoding: .utf8)
            let sourceDate = Date()
            try fileManager.setAttributes([.modificationDate: sourceDate], ofItemAtPath: sourceFile.path)
            
            let item = FileItem(url: sourceFile, isDirectory: false, modificationDate: sourceDate, size: 10, children: nil)
            
            // Setup Dest
            let destFile = destDir.appendingPathComponent("file_\(scenario.name).txt")
            if scenario.destExists {
                try "Dest".write(to: destFile, atomically: true, encoding: .utf8)
                
                var destDate = sourceDate
                if scenario.destAge == "older" {
                    destDate = sourceDate.addingTimeInterval(-100)
                } else if scenario.destAge == "newer" {
                    destDate = sourceDate.addingTimeInterval(100)
                }
                try fileManager.setAttributes([.modificationDate: destDate], ofItemAtPath: destFile.path)
            }
            
            // Test
            let result = DateComparator.compare(source: item, destPath: destFile, rule: scenario.rule)
            XCTAssertEqual(result, scenario.expected, "Failed Scenario: \(scenario.name)")
        }
    }
    
    func testHiddenFiles() throws {
        let hiddenFile = sourceDir.appendingPathComponent(".hidden")
        try "Hidden".write(to: hiddenFile, atomically: true, encoding: .utf8)
        
        // Test Ignore
        let itemsIgnore = FileScanner.scan(path: sourceDir, includeHidden: false)
        XCTAssertFalse(itemsIgnore.contains { $0.name == ".hidden" })
        
        let itemsInclude = FileScanner.scan(path: sourceDir, includeHidden: true)
        XCTAssertTrue(itemsInclude.contains { $0.name == ".hidden" })
    }
    
    func testHashComparison() throws {
        let fileManager = FileManager.default
        
        // 1. Setup Source File "A"
        let sourceFile = sourceDir.appendingPathComponent("hash_test.txt")
        try "Content A".write(to: sourceFile, atomically: true, encoding: .utf8)
        
        // Mock FileItem
        let sourceDate = Date()
        let sourceItem = FileItem(url: sourceFile, isDirectory: false, modificationDate: sourceDate, size: 9, children: nil) // "Content A" is 9 chars
        
        // 2. Scenario 1: Dest has "Content A" but OLDER date
        // Default (Date) -> Update
        // Hash -> Skip
        let destFile = destDir.appendingPathComponent("hash_test.txt")
        try "Content A".write(to: destFile, atomically: true, encoding: .utf8)
        let olderDate = sourceDate.addingTimeInterval(-100)
        try fileManager.setAttributes([.modificationDate: olderDate], ofItemAtPath: destFile.path)
        
        // Verify Default Behavior First
        let resultDefault = DateComparator.compare(source: sourceItem, destPath: destFile, rule: .ifNewer, compareByHash: false)
        XCTAssertEqual(resultDefault, .update, "Default date comparison should update if source is newer")
        
        // Verify Hash Behavior
        let resultHash = DateComparator.compare(source: sourceItem, destPath: destFile, rule: .ifNewer, compareByHash: true)
        XCTAssertEqual(resultHash, .skip, "Hash comparison should skip if content is same, even if timestamps differ")
        
        // 3. Scenario 2: Dest has "Content B" (Partial/Diff) but SAME date (collide?) or just different content
        // To test strictly hash, we can make date SAME.
        // If Dates are same, Default -> Skip
        // If Content differs, Hash -> Update
        
        try "Content B".write(to: destFile, atomically: true, encoding: .utf8)
        // Reset date to match source
        try fileManager.setAttributes([.modificationDate: sourceDate], ofItemAtPath: destFile.path)
        
        // Verify Default Behavior
        let resultDefault2 = DateComparator.compare(source: sourceItem, destPath: destFile, rule: .ifNewer, compareByHash: false)
        XCTAssertEqual(resultDefault2, .skip, "Default date comparison should skip if dates are same")
        
        // Verify Hash Behavior
        // Note: Size matches (9 chars)
        let resultHash2 = DateComparator.compare(source: sourceItem, destPath: destFile, rule: .ifNewer, compareByHash: true)
        XCTAssertEqual(resultHash2, .update, "Hash comparison should update if content differs, even if dates are same")
    }
}
