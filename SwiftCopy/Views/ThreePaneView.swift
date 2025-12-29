import SwiftUI
import UniformTypeIdentifiers

struct ThreePaneView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Headers
            HStack(spacing: 0) {
                // Source Header
                HStack(spacing: 8) {
                    // Expand/Collapse All Button (Left of Type)
                    Button(action: { viewModel.toggleExpandAll() }) {
                        Image(systemName: "list.bullet.indent") // Or some icon
                            .frame(width: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Select All / Deselect All (Checkmark Icon)
                    Image(systemName: "checkmark.circle")
                        .frame(width: 20)
                        .onTapGesture {
                            viewModel.toggleSelectAll()
                        }
                    
                    SortButton(title: "Name", option: .name, viewModel: viewModel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SortButton(title: "Date", option: .date, viewModel: viewModel)
                        .frame(width: 140, alignment: .trailing)
                    SortButton(title: "Size", option: .size, viewModel: viewModel)
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                
                Divider().frame(height: 20)
                
                Text("Status")
                    .font(.headline)
                    .frame(width: 60)
                
                Divider().frame(height: 20)
                
                // Destination Header (Mirrors Source layout but static)
                HStack(spacing: 8) {
                    Text("").frame(width: 20) // No checkbox
                    Text("").frame(width: 20) // No Type/Checkmark
                    Text("Name").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Date").frame(width: 140, alignment: .trailing)
                    Text("Size").frame(width: 60, alignment: .trailing)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            List(viewModel.flatFiles) { displayItem in
                UnifiedRowView(displayItem: displayItem, viewModel: viewModel)
            }
            
            Divider()
            
            // Status Bar
            StatusBarView(viewModel: viewModel)
                .padding(4)
                .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private func handleDrop(providers: [NSItemProvider], isSource: Bool) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    if isSource {
                        viewModel.sourcePath = url
                    } else {
                        viewModel.destPath = url
                    }
                    viewModel.scan()
                }
            }
        }
        return true
    }
}

struct StatusBarView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            Text("Source: \(viewModel.sourceFilesCount) items")
            Text("Dest: \(viewModel.destFilesCount) items")
            Spacer()
            if viewModel.addCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                    Text("\(viewModel.addCount) to Add")
                }
            }
            if viewModel.updateCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("\(viewModel.updateCount) to Update")
                }
            }
        }
        .font(.caption)
        .padding(.horizontal, 8)
    }
}

struct SortButton: View {
    let title: String
    let option: MainViewModel.SortOption
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        Button(action: {
            if viewModel.sortOption == option {
                viewModel.sortAscending.toggle()
            } else {
                viewModel.sortOption = option
                viewModel.sortAscending = true
            }
        }) {
            HStack(spacing: 2) {
                Text(title)
                if viewModel.sortOption == option {
                    Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct UnifiedRowView: View {
    let displayItem: MainViewModel.DisplayItem
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            // Source
            FileRowView(
                item: displayItem.file,
                isSource: true,
                isSelected: viewModel.isSelected(displayItem.file.id),
                depth: displayItem.depth,
                isExpanded: viewModel.expandedFolderPaths.contains(displayItem.file.url),
                onToggle: { viewModel.toggleSelection(for: displayItem.file) },
                onExpand: { viewModel.toggleExpand(displayItem.file) }
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers, isSource: true)
            }
            
            Divider()
            
            // Status
            ZStack {
                if let status = viewModel.comparisonResults[displayItem.file.id] {
                    Image(systemName: status.icon)
                        .foregroundColor(status == .error ? .red : (status == .done ? .green : .blue))
                }
            }
            .frame(width: 60)
            
            Divider()
            
            // Dest
            let status = viewModel.comparisonResults[displayItem.file.id]
            // Hide filename if status is .add (meaning source exists, dest missing)
            // But after copy, status becomes .done, so it should appear.
            if status == .add {
                 // Empty view for Dest
                 Color.clear
                    .frame(maxWidth: .infinity)
            } else {
                // Check if we have an override (updated after copy)
                let destItem: FileItem = {
                    let baseItem = viewModel.destFileOverrides[displayItem.file.id] ?? displayItem.file
                    
                    // Determine if we should preview "Now"
                    var shouldPreview = false
                    
                    // Case 1: Standard update status
                    if status == .update {
                        shouldPreview = true
                    }
                    // Case 2: Manually selected (Forced Copy) AND Destination exists (not .add)
                    // If status is .add, there is no destination file yet, so the date preview logic is handled differently 
                    // (actually .add row handles its own display, usually hidden or phantom)
                    // But here we are in the "else" block of "if status == .add", so destination MUST exist (or be treated as such).
                    else if viewModel.isSelected(displayItem.file.id) {
                         shouldPreview = true
                    }
                    
                    if viewModel.destFileOverrides[displayItem.file.id] == nil && shouldPreview {
                        if !viewModel.settings.preserveAttributes {
                            // Update preview: Show "Now"
                            return FileItem(
                                url: baseItem.url,
                                isDirectory: baseItem.isDirectory,
                                modificationDate: Date(), // Preview current time
                                size: baseItem.size,
                                children: baseItem.children
                            )
                        }
                    }
                    return baseItem
                }()
                
                FileRowView(item: destItem, isSource: false)
                    .opacity(0.5)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                        handleDrop(providers: providers, isSource: false)
                    }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider], isSource: Bool) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async {
                    if isSource {
                        viewModel.sourcePath = url
                    } else {
                        viewModel.destPath = url
                    }
                    viewModel.scan()
                }
            }
        }
        return true
    }
}
