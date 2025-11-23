import SwiftUI

struct ErrorLogView: View {
    @ObservedObject var viewModel: MainViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text("Error Log")
                .font(.headline)
                .padding()
            
            List(viewModel.errorLog) { item in
                VStack(alignment: .leading) {
                    Text(item.message)
                        .foregroundColor(.red)
                    if let url = item.fileURL {
                        Text(url.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(item.date, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Button("Close") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}
