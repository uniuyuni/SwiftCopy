import Foundation

class Logger {
    static let shared = Logger()
    private let logFileURL: URL
    
    private init() {
        let fileManager = FileManager.default
        let logsDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs")
            .appendingPathComponent("SwiftCopy")
        
        try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true, attributes: nil)
        logFileURL = logsDir.appendingPathComponent("application.log")
    }
    
    func log(_ message: String, level: String = "INFO") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [\(level)] \(message)\n"
        
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }
    
    func info(_ message: String) {
        log(message, level: "INFO")
    }
    
    func error(_ message: String) {
        log(message, level: "ERROR")
    }
}
