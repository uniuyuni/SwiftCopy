import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section(header: Text("Copy Rules")) {
                Picker("Overwrite Rule", selection: $settings.overwriteRule) {
                    ForEach(OverwriteRule.allCases) { rule in
                        Text(rule.rawValue).tag(rule)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Toggle("Copy Hidden Files", isOn: $settings.copyHiddenFiles)
                Toggle("Recursive Scan", isOn: $settings.recursiveScan)
                Toggle("Preserve File Attributes", isOn: $settings.preserveAttributes)
            }
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}
