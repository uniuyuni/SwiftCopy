import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: MainViewModel
    
    init(settings: AppSettings) {
        _viewModel = StateObject(wrappedValue: MainViewModel(settings: settings))
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
