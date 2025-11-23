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
            ("Missing_IfNewer", false, "none", .ifNewer, .copy),
            ("Missing_Always", false, "none", .always, .copy),
            ("Missing_Never", false, "none", .never, .copy),
            
            // Existing (Older) -> Source is Newer
            ("Older_IfNewer", true, "older", .ifNewer, .copy),
            ("Older_Always", true, "older", .always, .copy),
            ("Older_Never", true, "older", .never, .skip),
            
            // Existing (Newer) -> Source is Older
            ("Newer_IfNewer", true, "newer", .ifNewer, .skip),
            ("Newer_Always", true, "newer", .always, .copy),
            ("Newer_Never", true, "newer", .never, .skip),
            
            // Existing (Same)
            ("Same_IfNewer", true, "same", .ifNewer, .skip),
            ("Same_Always", true, "same", .always, .copy),
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
        
        // Test Include
        let itemsInclude = FileScanner.scan(path: sourceDir, includeHidden: true)
        XCTAssertTrue(itemsInclude.contains { $0.name == ".hidden" })
    }
}
