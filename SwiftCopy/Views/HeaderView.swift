import SwiftUI
import UniformTypeIdentifiers

struct HeaderView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        HStack {
            // Source
            Button("Source: \(viewModel.sourcePath?.lastPathComponent ?? "Select")") {
                viewModel.selectSource()
            }
            .help(viewModel.sourcePath?.path ?? "")
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers, isSource: true)
            }
            
            // Dest
            Button("Dest: \(viewModel.destPath?.lastPathComponent ?? "Select")") {
                viewModel.selectDest()
            }
            .help(viewModel.destPath?.path ?? "")
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers, isSource: false)
            }
            
            // Search & Refresh
            HStack(spacing: 4) {
                TextField("Search", text: $viewModel.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)
                
                Button(action: {
                    viewModel.scan()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh Folder Info")
                .disabled(viewModel.isScanning || viewModel.isCopying)
            }
            
            Spacer()
            
            Button("Start Copy") {
                viewModel.startCopy()
            }
            .disabled(viewModel.sourcePath == nil || viewModel.destPath == nil || viewModel.isScanning || viewModel.isCopying)
            
            if !viewModel.errorLog.isEmpty {
                Button(action: {
                    viewModel.showErrorLog = true
                }) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("\(viewModel.errorLog.count) Errors")
                }
                .sheet(isPresented: $viewModel.showErrorLog) {
                    ErrorLogView(viewModel: viewModel)
                }
            }
        }
        .padding()
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
