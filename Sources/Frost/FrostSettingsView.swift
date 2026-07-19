import SwiftUI

struct FrostSettingsView: View {
    @EnvironmentObject var state: FrostState

    var body: some View {
        Form {
            Section("General") {
                Toggle("Auto-hide enabled", isOn: $state.autoHideEnabled)
                Toggle("Show Frost icon", isOn: $state.iceIconVisible)
            }

            Section("Hidden Items") {
                if state.hiddenItems.isEmpty {
                    Text("No hidden items")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.hiddenItems) { item in
                        HStack {
                            Image(nsImage: item.icon ?? NSImage())
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(item.name)
                        }
                    }
                }
            }

            Section("Visible Items") {
                if state.visibleItems.isEmpty {
                    Text("No visible items detected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(state.visibleItems) { item in
                        HStack {
                            Image(nsImage: item.icon ?? NSImage())
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(item.name)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}