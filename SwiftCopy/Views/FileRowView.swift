import SwiftUI

struct FileRowView: View {
    let item: FileItem
    var isSource: Bool = false
    var isSelected: Bool = true
    var depth: Int = 0
    var isExpanded: Bool = false
    var onToggle: (() -> Void)? = nil
    var onExpand: (() -> Void)? = nil
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 8) {
            // Indentation
            if isSource {
                Color.clear.frame(width: CGFloat(depth * 20), height: 1)
            }
            
            if isSource {
                // Expand/Collapse Chevron
                if item.isDirectory {
                    Button(action: { onExpand?() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .frame(width: 12)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Color.clear.frame(width: 12)
                }
                
                Toggle("", isOn: Binding(
                    get: { isSelected },
                    set: { _ in onToggle?() }
                ))
                .labelsHidden()
                .toggleStyle(CheckboxToggleStyle())
                .frame(width: 20)
            }
            
            Image(systemName: item.isDirectory ? "folder.fill" : "doc")
                .foregroundColor(item.isDirectory ? .blue : .secondary)
                .frame(width: 20)
            
            Text(item.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(Self.dateFormatter.string(from: item.modificationDate))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .trailing)
            
            Text(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            Image(systemName: configuration.isOn ? "checkmark.square" : "square")
                .foregroundColor(configuration.isOn ? .blue : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
