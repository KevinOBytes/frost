import SwiftUI

@main
struct FrostApp: App {
    @NSApplicationDelegateAdaptor(FrostDelegate.self) var delegate

    var body: some Scene {
        Settings {
            FrostSettingsView()
                .environmentObject(delegate.state)
        }
    }
}