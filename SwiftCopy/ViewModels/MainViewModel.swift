import Foundation
import SwiftUI
import Combine

class MainViewModel: ObservableObject {
    @Published var sourcePath: URL?
    @Published var destPath: URL?
    @Published var sourceFiles: [FileItem] = []
    @Published var comparisonResults: [UUID: ComparisonStatus] = [:] // Map FileItem ID to status
    @Published var isScanning: Bool = false
    @Published var isCopying: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentFile: String = ""
    @Published var transferSpeed: Double = 0.0 // MB/s
    @Published var timeRemaining: TimeInterval = 0.0 // Seconds
    
    @Published var sourceFilesCount: Int = 0
    @Published var destFilesCount: Int = 0
    @Published var addCount: Int = 0
    @Published var updateCount: Int = 0
    
    @Published var errorLog: [ErrorLogItem] = []
    @Published var showErrorLog: Bool = false
    @Published var searchText: String = ""
    
    @Published var shouldAutoPromptForDest: Bool = false
    
    let settings: AppSettings
    
    private var cancellables = Set<AnyCancellable>()
    
    init(settings: AppSettings, launchSource: URL? = nil, launchDest: URL? = nil) {
        self.settings = settings
        
        if let launchSource = launchSource {
            self.sourcePath = launchSource
            // If checking "source only" logic for launch
            if launchDest == nil {
                self.shouldAutoPromptForDest = true
            }
        } else if let sourcePathStr = UserDefaults.standard.string(forKey: "lastSourcePath") {
            self.sourcePath = resolveExistingPath(sourcePathStr)
        }
        
        if let launchDest = launchDest {
            self.destPath = launchDest
        } else if let destPathStr = UserDefaults.standard.string(forKey: "lastDestPath") {
            self.destPath = resolveExistingPath(destPathStr)
        }
        
        // Auto-scan logic
        if launchSource != nil && launchDest != nil {
            self.scan()
        }
        
        // Real-time updates
        settings.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleSettingsChange()
            }
            .store(in: &cancellables)
    }
    
    private func resolveExistingPath(_ pathStr: String) -> URL? {
        let fileManager = FileManager.default
        var url = URL(fileURLWithPath: pathStr)
        
        if pathStr.isEmpty { return nil }
        
        // Loop until we find an existing directory
        while true {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    return url
                }
                // If it's a file, return parent
                return url.deletingLastPathComponent()
            }
            
            // If we are at root and it doesn't exist (unlikely), break
            if url.path == "/" {
                break
            }
            
            // Go up
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break } // Safety
            url = parent
        }
        return nil
    }
    
    private func handleSettingsChange() {
        print("Settings changed, re-scanning...")
        scan()
    }
    
    enum SortOption {
        case name, date, size
    }
    
    struct DisplayItem: Identifiable {
        var id: UUID { file.id }
        let file: FileItem
        let depth: Int
    }
    
    @Published var sortOption: SortOption = .name
    @Published var sortAscending: Bool = true
    @Published var excludedFileIds: Set<UUID> = []
    @Published var expandedFolderPaths: Set<URL> = []
    
    var flatFiles: [DisplayItem] {
        let sorted = sortItems(sourceFiles) // Sort top level
        return flatten(items: sorted, depth: 0)
    }
    
    private func flatten(items: [FileItem], depth: Int) -> [DisplayItem] {
        var result: [DisplayItem] = []
        for item in items {
            // Filter check
            if !searchText.isEmpty && !itemMatches(item, query: searchText) {
                continue
            }
            
            result.append(DisplayItem(file: item, depth: depth))
            
            if item.isDirectory && expandedFolderPaths.contains(item.url), let children = item.children {
                let sortedChildren = sortItems(children)
                result.append(contentsOf: flatten(items: sortedChildren, depth: depth + 1))
            }
        }
        return result
    }
    
    private func itemMatches(_ item: FileItem, query: String) -> Bool {
        if item.name.localizedCaseInsensitiveContains(query) { return true }
        if let children = item.children {
            return children.contains { itemMatches($0, query: query) }
        }
        return false
    }
    
    func toggleExpand(_ item: FileItem) {
        if expandedFolderPaths.contains(item.url) {
            expandedFolderPaths.remove(item.url)
        } else {
            expandedFolderPaths.insert(item.url)
        }
    }
    
    func toggleExpandAll() {
        if expandedFolderPaths.isEmpty {
            // Expand All
            var allPaths: Set<URL> = []
            func collect(_ items: [FileItem]) {
                for item in items {
                    if item.isDirectory {
                        allPaths.insert(item.url)
                        if let children = item.children {
                            collect(children)
                        }
                    }
                }
            }
            collect(sourceFiles)
            expandedFolderPaths = allPaths
        } else {
            // Collapse All
            expandedFolderPaths.removeAll()
        }
    }
    
    func toggleSelectAll() {
        let allCandidates = getAllFiles(sourceFiles)
        
        // Identify actual copy targets
        let copyTargets = allCandidates.filter { item in
            if let status = comparisonResults[item.id] {
                return status == .add || status == .update
            }
            return false
        }
        
        // Check if all copy targets are currently selected
        let allTargetsSelected = copyTargets.allSatisfy { !excludedFileIds.contains($0.id) }
        
        if allTargetsSelected && !copyTargets.isEmpty {
            // Deselect All
            for item in allCandidates {
                excludedFileIds.insert(item.id)
            }
        } else {
            // Smart Select (Select only copy targets)
            var newExcluded: Set<UUID> = []
            for item in allCandidates {
                newExcluded.insert(item.id)
            }
            
            for item in copyTargets {
                newExcluded.remove(item.id)
                // Include ancestors
                var currentId = item.id
                while let parentId = parentMap[currentId] {
                    newExcluded.remove(parentId)
                    currentId = parentId
                }
            }
            excludedFileIds = newExcluded
        }
    }
    
    private func getAllFiles(_ items: [FileItem]) -> [FileItem] {
        var result: [FileItem] = []
        for item in items {
            result.append(item)
            if let children = item.children {
                result.append(contentsOf: getAllFiles(children))
            }
        }
        return result
    }
    
    private func sortItems(_ items: [FileItem]) -> [FileItem] {
        return items.sorted { lhs, rhs in
            let result: Bool
            switch sortOption {
            case .name:
                result = lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .date:
                result = lhs.modificationDate < rhs.modificationDate
            case .size:
                result = lhs.size < rhs.size
            }
            return sortAscending ? result : !result
        }
    }
    
    func toggleSelection(for item: FileItem) {
        let isSelected = !excludedFileIds.contains(item.id)
        let shouldSelect = !isSelected // Toggle
        
        setSelection(for: item, selected: shouldSelect)
        
        // Sync Parent
        if shouldSelect {
            // If we selected a child, we MUST select all its ancestors
            selectAncestors(of: item)
        }
    }
    
    private func setSelection(for item: FileItem, selected: Bool) {
        if selected {
            excludedFileIds.remove(item.id)
        } else {
            excludedFileIds.insert(item.id)
        }
        
        if let children = item.children {
            for child in children {
                setSelection(for: child, selected: selected)
            }
        }
    }
    
    @Published var parentMap: [UUID: UUID] = [:] // Child ID -> Parent ID
    
    private func buildParentMap(items: [FileItem], parentId: UUID? = nil) {
        for item in items {
            if let parentId = parentId {
                parentMap[item.id] = parentId
            }
            if let children = item.children {
                buildParentMap(items: children, parentId: item.id)
            }
        }
    }
    
    private func selectAncestors(of item: FileItem) {
        var currentId = item.id
        while let parentId = parentMap[currentId] {
            if excludedFileIds.contains(parentId) {
                excludedFileIds.remove(parentId)
            }
            currentId = parentId
        }
    }
    
    func isSelected(_ id: UUID) -> Bool {
        return !excludedFileIds.contains(id)
    }
    
    private var totalBytesToCopy: Int64 = 0
    private var processedBytes: Int64 = 0
    private var startTime: Date?
    
    private var isSelectingDest: Bool = false
    
    func selectSource() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if let source = sourcePath {
            panel.directoryURL = source
        }
        if panel.runModal() == .OK {
            self.sourcePath = panel.url
            scan()
        }
    }
    
    func selectDest() {
        guard !isSelectingDest else { return }
        isSelectingDest = true
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if let dest = destPath {
            panel.directoryURL = dest
        }
        
        // Use beginSheet or simple runModal, but handle flag reset
        let response = panel.runModal()
        
        if response == .OK {
            self.destPath = panel.url
            scan()
        }
        
        // Reset flag after a short delay to prevent bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isSelectingDest = false
        }
    }
    
    func scan() {
        guard let source = sourcePath, let dest = destPath else { return }
        
        // Save paths
        UserDefaults.standard.set(source.path, forKey: "lastSourcePath")
        UserDefaults.standard.set(dest.path, forKey: "lastDestPath")
        
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async {
            // Stage 1: Scan Source
            let items = FileScanner.scan(path: source, includeHidden: self.settings.copyHiddenFiles, recursive: true)
            let destItems = FileScanner.scan(path: dest, includeHidden: self.settings.copyHiddenFiles, recursive: true)
            
            DispatchQueue.main.async {
                self.sourceFiles = items
                self.sourceFilesCount = self.countFiles(items)
                self.destFilesCount = self.countFiles(destItems)
                
                self.parentMap = [:]
                self.buildParentMap(items: items)
                self.comparisonResults = [:] // Clear previous results
            }
            
            // Stage 2: Compare
            var results: [UUID: ComparisonStatus] = [:]
            self.compareRecursively(items: items, sourceRoot: source, destRoot: dest, results: &results)
            
            // Smart Selection
            var excluded: Set<UUID> = []
            self.calculateSmartSelection(items: items, results: results, excluded: &excluded)
            
            DispatchQueue.main.async {
                // Calculate Stats (Add/Update)
                var add = 0
                var update = 0
                for status in results.values {
                    if status == .add { add += 1 }
                    else if status == .update { update += 1 }
                }

                self.comparisonResults = results
                self.excludedFileIds = excluded
                self.addCount = add
                self.updateCount = update
                self.isScanning = false
            }
        }
    }
    
    private func countFiles(_ items: [FileItem]) -> Int {
        var count = 0
        for item in items {
            count += 1
            if let children = item.children {
                count += self.countFiles(children)
            }
        }
        return count
    }
    
    @discardableResult
    private func calculateSmartSelection(items: [FileItem], results: [UUID: ComparisonStatus], excluded: inout Set<UUID>) -> Bool {
        var hasIncludedItem = false
        
        for item in items {
            var isIncluded = false
            
            // Check children first
            if let children = item.children {
                let childrenIncluded = calculateSmartSelection(items: children, results: results, excluded: &excluded)
                if childrenIncluded {
                    isIncluded = true
                }
            }
            
            // Check self
            if let status = results[item.id] {
                if status == .add || status == .update {
                    isIncluded = true
                }
            }
            
            if isIncluded {
                hasIncludedItem = true
            } else {
                excluded.insert(item.id)
            }
        }
        
        return hasIncludedItem
    }
    
    private func compareRecursively(items: [FileItem], sourceRoot: URL, destRoot: URL, results: inout [UUID: ComparisonStatus]) {
        let sourcePath = sourceRoot.standardized.path
        let destPath = destRoot.standardized.path
        
        for item in items {
            let itemPath = item.url.standardized.path
            var relativePath = itemPath.replacingOccurrences(of: sourcePath, with: "")
            if relativePath.hasPrefix("/") {
                relativePath.removeFirst()
            }
            
            let destItemURL = URL(fileURLWithPath: destPath).appendingPathComponent(relativePath)
            
            let status = DateComparator.compare(source: item, destPath: destItemURL, rule: self.settings.overwriteRule, compareByHash: self.settings.compareByHash)
            results[item.id] = status
            
            if let children = item.children {
                if self.settings.recursiveScan {
                    compareRecursively(items: children, sourceRoot: sourceRoot, destRoot: destRoot, results: &results)
                }
            }
        }
    }
    
    func startCopy() {
        guard !isCopying else { return }
        isCopying = true
        progress = 0.0
        transferSpeed = 0.0
        timeRemaining = 0.0
        processedBytes = 0
        startTime = Date()
        errorLog.removeAll()
        
        let copyList = getCopyList(items: sourceFiles)
        let total = Double(copyList.count)
        
        totalBytesToCopy = copyList.reduce(0) { $0 + $1.size }
        
        var current = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let sourceRoot = self.sourcePath, let destRoot = self.destPath else { return }
            
            for item in copyList {
                DispatchQueue.main.async {
                    self.currentFile = item.name
                }
                
                let sourcePath = sourceRoot.resolvingSymlinksInPath().path
                let itemPath = item.url.resolvingSymlinksInPath().path
                let relativePath = itemPath.replacingOccurrences(of: sourcePath, with: "")
                let safeRelativePath = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
                let destItemURL = destRoot.appendingPathComponent(safeRelativePath)
                
                let status = DateComparator.compare(source: item, destPath: destItemURL, rule: self.settings.overwriteRule, compareByHash: self.settings.compareByHash)
                
                DispatchQueue.main.async {
                    self.comparisonResults[item.id] = status
                }
                
                do {
                    if item.isDirectory {
                        try FileManager.default.createDirectory(at: destItemURL, withIntermediateDirectories: true, attributes: nil)
                    } else {
                        try CopyManager.copy(source: item.url, dest: destItemURL, preserveAttributes: self.settings.preserveAttributes)
                    }
                    
                    DispatchQueue.main.async {
                        self.comparisonResults[item.id] = .done
                        if status == .add { self.addCount = max(0, self.addCount - 1) }
                        if status == .update { self.updateCount = max(0, self.updateCount - 1) }
                        if status == .add { self.destFilesCount += 1 }
                    }
                } catch {
                    print("Copy error: \(error)")
                    Logger.shared.error("Failed to copy \(item.name): \(error.localizedDescription)")
                    let logItem = ErrorLogItem(date: Date(), message: error.localizedDescription, fileURL: item.url)
                    DispatchQueue.main.async {
                        self.comparisonResults[item.id] = .error
                        self.errorLog.append(logItem)
                    }
                }
                
                self.processedBytes += item.size
                current += 1
                
                let now = Date()
                let timeElapsed = now.timeIntervalSince(self.startTime ?? now)
                
                DispatchQueue.main.async {
                    self.progress = current / total
                    if timeElapsed > 0.5 {
                        let bytesPerSec = Double(self.processedBytes) / timeElapsed
                        self.transferSpeed = bytesPerSec / 1024 / 1024 // MB/s
                        if bytesPerSec > 0 {
                            let remainingBytes = Double(self.totalBytesToCopy - self.processedBytes)
                            self.timeRemaining = remainingBytes / bytesPerSec
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isCopying = false
                self.currentFile = "Done"
                self.transferSpeed = 0.0
                self.timeRemaining = 0.0
            }
        }
    }
    
    private func getCopyList(items: [FileItem]) -> [FileItem] {
        var list: [FileItem] = []
        for item in items {
            if excludedFileIds.contains(item.id) { continue }
            
            if let status = comparisonResults[item.id] {
                if status == .add || status == .update {
                     list.append(item)
                }
            }
            if let children = item.children {
                list.append(contentsOf: getCopyList(items: children))
            }
        }
        return list
    }
}
