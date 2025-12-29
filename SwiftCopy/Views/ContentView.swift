import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: MainViewModel
    
    init(settings: AppSettings, sourceURL: URL? = nil, destURL: URL? = nil) {
        _viewModel = StateObject(wrappedValue: MainViewModel(settings: settings, launchSource: sourceURL, launchDest: destURL))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(viewModel: viewModel)
            Divider()
            ThreePaneView(viewModel: viewModel)
            if viewModel.isCopying {
                Divider()
                FooterView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            if viewModel.shouldAutoPromptForDest {
                // Slight delay to ensure window is ready?
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.selectDest()
                    viewModel.shouldAutoPromptForDest = false // Reset
                }
            }
        }
        .onChangeCompat(of: viewModel.shouldAutoPromptForDest) { newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.selectDest()
                    viewModel.shouldAutoPromptForDest = false // Reset
                }
            }
        }
        .onOpenURL { url in
            handleURL(url)
        }
    }
    
    private func handleURL(_ url: URL) {
        guard url.scheme == "swiftcopy" else { return }
        
        var path: String?
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {
            path = queryItems.first(where: { $0.name == "path" })?.value
        }
        
        if let path = path {
            let fileUrl = URL(fileURLWithPath: path)
            viewModel.sourcePath = fileUrl
            viewModel.shouldAutoPromptForDest = true
        }
    }
}

struct FooterView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(viewModel.currentFile)
                    .font(.caption)
                    .lineLimit(1)
                Spacer()
                if viewModel.isCopying {
                    Text(String(format: "%.1f MB/s", viewModel.transferSpeed))
                        .font(.caption)
                        .monospacedDigit()
                    Text("•")
                        .font(.caption)
                    Text(formatTime(viewModel.timeRemaining))
                        .font(.caption)
                        .monospacedDigit()
                }
            }
            
            ProgressView(value: viewModel.progress)
                .progressViewStyle(LinearProgressViewStyle())
        }
        .padding(8)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds.isInfinite || seconds.isNaN { return "--:--" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? "--:--"
    }
}

extension View {
    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(macOS 14.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}
