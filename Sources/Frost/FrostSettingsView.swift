import SwiftUI

struct FrostSettingsView: View {
    @EnvironmentObject var state: FrostState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            ItemSettingsView()
                .tabItem { Label("Items", systemImage: "list.bullet") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .environmentObject(state)
        .frame(width: 500, height: 420)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var state: FrostState

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch Frost at Login", isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { newValue in
                        if let delegate = NSApp.delegate as? FrostDelegate {
                            delegate.setLaunchAtLogin(newValue)
                        }
                    }
                ))
            }

            Section("Menu Bar") {
                Toggle("Show Frost icon", isOn: $state.frostIconVisible)
                Toggle("Auto-hide enabled", isOn: $state.autoHideEnabled)
                Toggle("Show hidden section on launch", isOn: $state.isHiddenSectionVisible)
            }

            Section("Permissions") {
                HStack {
                    if state.hasAccessibilityPermission {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Accessibility: Granted")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Accessibility: Not Granted")
                        Spacer()
                        Button("Open Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct ItemSettingsView: View {
    @EnvironmentObject var state: FrostState

    var body: some View {
        Form {
            Section("Visible Items (\(state.visibleOnlyItems.count))") {
                if state.visibleOnlyItems.isEmpty {
                    Text("No visible items detected")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(state.visibleOnlyItems) { item in
                                HStack {
                                    Image(systemName: "eye")
                                        .foregroundStyle(.secondary)
                                    Text(item.name)
                                    Spacer()
                                    Button("Hide") {
                                        state.hiddenItemIDs.insert(item.id)
                                    }
                                    .buttonStyle(.borderless)
                                    Button("Always") {
                                        state.alwaysHiddenItemIDs.insert(item.id)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }

            Section("Hidden Items (\(state.hiddenItems.count))") {
                if state.hiddenItems.isEmpty {
                    Text("No hidden items")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(state.hiddenItems) { item in
                                HStack {
                                    Image(systemName: "eye.slash")
                                        .foregroundStyle(.secondary)
                                    Text(item.name)
                                    Spacer()
                                    Button("Show") {
                                        state.hiddenItemIDs.remove(item.id)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }

            Section("Always Hidden (\(state.alwaysHiddenItems.count))") {
                if state.alwaysHiddenItems.isEmpty {
                    Text("No always-hidden items")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(state.alwaysHiddenItems) { item in
                                HStack {
                                    Image(systemName: "eye.slash.fill")
                                        .foregroundStyle(.secondary)
                                    Text(item.name)
                                    Spacer()
                                    Button("Show") {
                                        state.alwaysHiddenItemIDs.remove(item.id)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }
        }
        .padding()
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "snowflake")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Frost")
                .font(.title)
                .fontWeight(.bold)

            Text("Menu bar manager for macOS Tahoe")
                .foregroundStyle(.secondary)

            Text("Version 1.1.0")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 8) {
                Link("GitHub Repository", destination: URL(string: "https://github.com/KevinOBytes/frost")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/KevinOBytes/frost/issues")!)
            }

            Spacer()

            Text("MIT License — © 2026 Kevin O'Connor / TKOResearch LLC")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}