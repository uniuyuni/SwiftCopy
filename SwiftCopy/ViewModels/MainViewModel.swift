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
    @Published var errorLog: [ErrorLogItem] = []
    @Published var showErrorLog: Bool = false
    @Published var searchText: String = ""
    
    let settings: AppSettings
    
    private var cancellables = Set<AnyCancellable>()
    
    init(settings: AppSettings) {
        self.settings = settings
        
        if let sourcePathStr = UserDefaults.standard.string(forKey: "lastSourcePath") {
            self.sourcePath = resolveExistingPath(sourcePathStr)
        }
        if let destPathStr = UserDefaults.standard.string(forKey: "lastDestPath") {
            self.destPath = resolveExistingPath(destPathStr)
        }
        
        // Real-time updates
        settings.objectWillChange.sink { [weak self] _ in
            // objectWillChange emits BEFORE the change. We need to wait for the change to propagate?
            // Or we can observe individual properties.
            // Observing objectWillChange is easier but might trigger too often.
            // Let's observe individual properties for precision.
        }.store(in: &cancellables)
        
        // We need to observe the properties of the passed settings object.
        // Since AppSettings uses @AppStorage, it might be tricky to observe directly via $property if it's not a @Published property wrapper in the same sense?
        // AppSettings is ObservableObject, so @AppStorage triggers objectWillChange.
        // But we want to know WHICH property changed to decide whether to scan or just compare.
        // Actually, for MVP, let's just re-scan on any change. It's safer.
        // But wait, re-scanning is expensive.
        // Let's try to be smart.
        
        // Note: @AppStorage properties in an ObservableObject do trigger objectWillChange.
        // But we can't easily distinguish which one changed without checking values or using specific publishers if we made them @Published.
        // But they are @AppStorage.
        // Let's just listen to objectWillChange and debounce?
        // Or better, let's just re-scan.
        
        // Actually, we can attach logic to the View? No, ViewModel should handle it.
        // Let's use a simple approach: Observe objectWillChange, wait a bit (debounce), then re-scan.
        
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
        // We don't know exactly what changed, so we have to assume the worst (re-scan needed).
        // Unless we cache the old values?
        // For now, let's just re-scan. It handles everything.
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
            comparisonResults[item.id] == .copy
        }
        
        // Check if all copy targets are currently selected
        // (i.e., none of them are in excludedFileIds)
        let allTargetsSelected = copyTargets.allSatisfy { !excludedFileIds.contains($0.id) }
        
        if allTargetsSelected && !copyTargets.isEmpty {
            // If all targets are already selected, we Deselect All.
            // (This covers the "Smart Select" state -> "Deselect All" state transition)
            for item in allCandidates {
                excludedFileIds.insert(item.id)
            }
        } else {
            // Otherwise, we apply Smart Select (Select only copy targets)
            // 1. Start by excluding everything
            var newExcluded: Set<UUID> = []
            for item in allCandidates {
                newExcluded.insert(item.id)
            }
            
            // 2. Include .copy items and their ancestors
            for item in copyTargets {
                // Include this item
                newExcluded.remove(item.id)
                
                // Include ancestors
                var currentId = item.id
                while let parentId = parentMap[currentId] {
                    newExcluded.remove(parentId)
                    currentId = parentId
                }
            }
            
            // Special case: If there are NO copy targets, and we are not fully deselected, maybe we should just deselect all?
            // But the logic above does exactly that (newExcluded has everything).
            // If copyTargets is empty: allTargetsSelected is true.
            // So it enters first block -> Deselect All.
            // If we are already deselected, it stays deselected.
            // If we have manual selection but no copy targets, it deselects all.
            // This seems correct.
            
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
    
    // ... (inside scan, after sourceFiles = items)
    
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
    
    // ...
    
    private func selectAncestors(of item: FileItem) {
        var currentId = item.id
        while let parentId = parentMap[currentId] {
            if excludedFileIds.contains(parentId) {
                excludedFileIds.remove(parentId)
            }
            currentId = parentId
        }
    }
    
    // Remove findItem as it's no longer needed for this purpose
    // private func findItem...
    
    func isSelected(_ id: UUID) -> Bool {
        return !excludedFileIds.contains(id)
    }
    
    private func filterItems(_ items: [FileItem], query: String) -> [FileItem] {
        var result: [FileItem] = []
        for item in items {
            let matches = item.name.localizedCaseInsensitiveContains(query)
            var childrenMatch = false
            var filteredChildren: [FileItem]? = nil
            
            if let children = item.children {
                let filtered = filterItems(children, query: query)
                if !filtered.isEmpty {
                    childrenMatch = true
                    filteredChildren = filtered
                }
            }
            
            if matches || childrenMatch {
                var newItem = item
                newItem.children = filteredChildren
                result.append(newItem)
            }
        }
        return result
    }
    
    private var totalBytesToCopy: Int64 = 0
    private var processedBytes: Int64 = 0
    private var startTime: Date?
    
    // For MVP, we flatten the list for display or handle hierarchy.
    // Let's keep it simple: Top level list, and we scan recursively but maybe just show top level?
    // The spec says "Finder-like list" and "Subfolders are hierarchical".
    // Handling a full hierarchical tree in SwiftUI List can be tricky with `OutlineGroup` or `DisclosureGroup`.
    // `FileItem` has `children`, so `OutlineGroup` should work.
    
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
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if let dest = destPath {
            panel.directoryURL = dest
        }
        if panel.runModal() == .OK {
            self.destPath = panel.url
            scan()
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
            // Always scan recursively so UI shows structure
            let items = FileScanner.scan(path: source, includeHidden: self.settings.copyHiddenFiles, recursive: true)
            
            DispatchQueue.main.async {
                self.sourceFiles = items
                self.parentMap = [:]
                self.buildParentMap(items: items)
                self.comparisonResults = [:] // Clear previous results
                // Auto-expand top level? Maybe not.
            }
            
            // Stage 2: Compare
            var results: [UUID: ComparisonStatus] = [:]
            self.compareRecursively(items: items, sourceRoot: source, destRoot: dest, results: &results)
            
            // Smart Selection
            var excluded: Set<UUID> = []
            self.calculateSmartSelection(items: items, results: results, excluded: &excluded)
            
            DispatchQueue.main.async {
                self.comparisonResults = results
                self.excludedFileIds = excluded
                self.isScanning = false
            }
        }
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
                if status == .copy {
                    isIncluded = true
                }
            }
            
            if isIncluded {
                // If included, ensure NOT in excluded set
                // (It's not in there by default since we start with empty, but good to be explicit if we change logic)
                hasIncludedItem = true
            } else {
                // Exclude
                excluded.insert(item.id)
            }
        }
        
        return hasIncludedItem
    }
    
    private func compareRecursively(items: [FileItem], sourceRoot: URL, destRoot: URL, results: inout [UUID: ComparisonStatus]) {
        let sourcePath = sourceRoot.standardized.path
        let destPath = destRoot.standardized.path
        
        for item in items {
            // Calculate relative path safely
            let itemPath = item.url.standardized.path
            
            // Ensure itemPath starts with sourcePath
            // Note: If sourcePath has no trailing slash, and itemPath is /.../source/file, it works.
            // But we should be careful about partial matches (e.g. /source vs /source_backup).
            // Since we scanned FROM sourceRoot, it should be safe usually.
            
            var relativePath = itemPath.replacingOccurrences(of: sourcePath, with: "")
            if relativePath.hasPrefix("/") {
                relativePath.removeFirst()
            }
            
            let destItemURL = URL(fileURLWithPath: destPath).appendingPathComponent(relativePath)
            
            let status = DateComparator.compare(source: item, destPath: destItemURL, rule: self.settings.overwriteRule)
            results[item.id] = status
            
            if let children = item.children {
                // Only compare children if recursive scan is enabled
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
        
        // Flatten items to get copy list
        let copyList = getCopyList(items: sourceFiles)
        let total = Double(copyList.count)
        
        // Calculate total bytes
        totalBytesToCopy = copyList.reduce(0) { $0 + $1.size }
        
        var current = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let sourceRoot = self.sourcePath, let destRoot = self.destPath else { return }
            
            for item in copyList {
                DispatchQueue.main.async {
                    self.currentFile = item.name
                }
                
                // Standardize paths to handle /private/var vs /var symlinks
                let sourcePath = sourceRoot.resolvingSymlinksInPath().path
                let itemPath = item.url.resolvingSymlinksInPath().path
                let relativePath = itemPath.replacingOccurrences(of: sourcePath, with: "")
                
                // Ensure relative path doesn't start with / if we are appending
                let safeRelativePath = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
                let destItemURL = destRoot.appendingPathComponent(safeRelativePath)
                
                let status = DateComparator.compare(source: item, destPath: destItemURL, rule: self.settings.overwriteRule)
                
                DispatchQueue.main.async {
                    self.comparisonResults[item.id] = status
                }
                
                let startFileTime = Date()
                
                do {
                    if item.isDirectory {
                        // Create dir if needed
                        try FileManager.default.createDirectory(at: destItemURL, withIntermediateDirectories: true, attributes: nil)
                    } else {
                        // Check rule again just in case, or rely on comparison status?
                        // Actually we should only copy if status is .copy.
                        // But startCopy iterates copyList which is derived from comparisonResults.
                        // So we are good.
                        try CopyManager.copy(source: item.url, dest: destItemURL, preserveAttributes: self.settings.preserveAttributes)
                    }
                    
                    DispatchQueue.main.async {
                        self.comparisonResults[item.id] = .done
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
                
                // Update stats
                self.processedBytes += item.size
                current += 1
                
                let now = Date()
                let timeElapsed = now.timeIntervalSince(self.startTime ?? now)
                
                DispatchQueue.main.async {
                    self.progress = current / total
                    
                    if timeElapsed > 0.5 { // Update speed every 0.5s or so to avoid jitter, or just every file?
                        // Simple average speed
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
            // Skip if excluded
            if excludedFileIds.contains(item.id) { continue }
            
            if comparisonResults[item.id] == .copy {
                list.append(item)
            }
            if let children = item.children {
                list.append(contentsOf: getCopyList(items: children))
            }
        }
        return list
    }
}
