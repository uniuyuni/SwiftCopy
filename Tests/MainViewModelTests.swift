import XCTest
@testable import SwiftCopy

class MainViewModelTests: XCTestCase {
    var viewModel: MainViewModel!
    var tempDir: URL!
    var sourceDir: URL!
    var destDir: URL!
    
    override func setUpWithError() throws {
        viewModel = MainViewModel(settings: AppSettings())
        
        let fileManager = FileManager.default
        tempDir = fileManager.temporaryDirectory.appendingPathComponent("SwiftCopyTest_\(UUID().uuidString)")
        sourceDir = tempDir.appendingPathComponent("Source")
        destDir = tempDir.appendingPathComponent("Dest")
        
        try fileManager.createDirectory(at: sourceDir, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true, attributes: nil)
    }
    
    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDir)
    }
    
    func waitFor(condition: @escaping () -> Bool, timeout: TimeInterval = 2.0) {
        let expectation = XCTestExpectation(description: "Condition met")
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if condition() {
                timer.invalidate()
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
        timer.invalidate()
    }

    func testScanAndCompare() throws {
        // Setup files
        let fileA = sourceDir.appendingPathComponent("FileA.txt")
        try "Content A".write(to: fileA, atomically: true, encoding: .utf8)
        
        viewModel.sourcePath = sourceDir
        viewModel.destPath = destDir
        
        viewModel.scan()
        
        // Wait for scanning to finish
        waitFor(condition: { !self.viewModel.isScanning && !self.viewModel.sourceFiles.isEmpty })
        
        XCTAssertEqual(self.viewModel.sourceFiles.count, 1)
        if let item = self.viewModel.sourceFiles.first {
            XCTAssertEqual(item.name, "FileA.txt")
            XCTAssertEqual(self.viewModel.comparisonResults[item.id], .add)
        }
    }
    
    func testCopyExecution() throws {
        // Setup files
        let fileA = sourceDir.appendingPathComponent("FileA.txt")
        try "Content A".write(to: fileA, atomically: true, encoding: .utf8)
        
        viewModel.sourcePath = sourceDir
        viewModel.destPath = destDir
        
        // 1. Scan
        viewModel.scan()
        waitFor(condition: { !self.viewModel.isScanning && !self.viewModel.sourceFiles.isEmpty })
        
        XCTAssertEqual(viewModel.sourceFiles.count, 1)
        
        // 2. Copy
        viewModel.startCopy()
        
        // Wait for copying to finish
        waitFor(condition: { !self.viewModel.isCopying })
        
        // 3. Verify
        let destFileA = self.destDir.appendingPathComponent("FileA.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destFileA.path))
        
        if let item = self.viewModel.sourceFiles.first {
            XCTAssertEqual(self.viewModel.comparisonResults[item.id], .done)
        }
    }
    
    func testFiltering() throws {
        // Setup files
        let fileA = sourceDir.appendingPathComponent("FileA.txt")
        let fileB = sourceDir.appendingPathComponent("FileB.log")
        try "Content A".write(to: fileA, atomically: true, encoding: .utf8)
        try "Content B".write(to: fileB, atomically: true, encoding: .utf8)
        
        viewModel.sourcePath = sourceDir
        viewModel.destPath = destDir
        
        viewModel.scan()
        waitFor(condition: { !self.viewModel.isScanning && !self.viewModel.sourceFiles.isEmpty })
        
        XCTAssertEqual(viewModel.sourceFiles.count, 2)
        
        // Filter "txt"
        viewModel.searchText = "txt"
        XCTAssertEqual(viewModel.flatFiles.count, 1)
        XCTAssertEqual(viewModel.flatFiles.first?.file.name, "FileA.txt")
        
        // Filter "log"
        viewModel.searchText = "log"
        XCTAssertEqual(viewModel.flatFiles.count, 1)
        XCTAssertEqual(viewModel.flatFiles.first?.file.name, "FileB.log")
        
        // Filter "File"
        viewModel.searchText = "File"
        XCTAssertEqual(viewModel.flatFiles.count, 2)
        
        // Filter "None"
        viewModel.searchText = "None"
        XCTAssertEqual(viewModel.flatFiles.count, 0)
    }
}
