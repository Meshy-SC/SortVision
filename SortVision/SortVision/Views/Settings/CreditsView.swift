import SwiftUI

/// Credits sub-page — shows app info and attribution.
struct CreditsView: View {

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("SortVision!")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("Version \(PlatformInfo.appVersion)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)
            }

            Section("Designed & Developed By") {
                Text("Ahmed DALHI")
            }
        }
        .navigationTitle("Credits")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #elseif os(macOS)
        .formStyle(.grouped)
        #endif
    }
}
