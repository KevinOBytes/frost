import AppKit
import SwiftUI
import ServiceManagement

@MainActor
final class FrostState: ObservableObject {
    @Published var isHiddenSectionVisible: Bool = false {
        didSet { defaults.set(isHiddenSectionVisible, forKey: Keys.hiddenSectionVisible) }
    }
    @Published var hiddenItemIDs: Set<String> = [] {
        didSet { saveHiddenIDs() }
    }
    @Published var alwaysHiddenItemIDs: Set<String> = [] {
        didSet { saveAlwaysHiddenIDs() }
    }
    @Published var visibleItems: [MenuBarItem] = []
    @Published var allDetectedItems: [MenuBarItem] = []
    @Published var autoHideEnabled: Bool = true {
        didSet { defaults.set(autoHideEnabled, forKey: Keys.autoHide) }
    }
    @Published var frostIconVisible: Bool = true {
        didSet { defaults.set(frostIconVisible, forKey: Keys.iconVisible) }
    }
    @Published var hasAccessibilityPermission: Bool = false
    @Published var launchAtLogin: Bool = false {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let hiddenSectionVisible = "frost.hiddenSectionVisible"
        static let hiddenItemIDs = "frost.hiddenItemIDs"
        static let alwaysHiddenItemIDs = "frost.alwaysHiddenItemIDs"
        static let autoHide = "frost.autoHideEnabled"
        static let iconVisible = "frost.frostIconVisible"
        static let launchAtLogin = "frost.launchAtLogin"
    }

    init() {
        isHiddenSectionVisible = defaults.bool(forKey: Keys.hiddenSectionVisible)
        autoHideEnabled = defaults.object(forKey: Keys.autoHide) as? Bool ?? true
        frostIconVisible = defaults.object(forKey: Keys.iconVisible) as? Bool ?? true
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        hiddenItemIDs = Set(defaults.stringArray(forKey: Keys.hiddenItemIDs) ?? [])
        alwaysHiddenItemIDs = Set(defaults.stringArray(forKey: Keys.alwaysHiddenItemIDs) ?? [])
    }

    private func saveHiddenIDs() {
        defaults.set(Array(hiddenItemIDs), forKey: Keys.hiddenItemIDs)
    }

    private func saveAlwaysHiddenIDs() {
        defaults.set(Array(alwaysHiddenItemIDs), forKey: Keys.alwaysHiddenItemIDs)
    }

    var hiddenItems: [MenuBarItem] {
        allDetectedItems.filter { hiddenItemIDs.contains($0.id) }
    }

    var alwaysHiddenItems: [MenuBarItem] {
        allDetectedItems.filter { alwaysHiddenItemIDs.contains($0.id) }
    }

    var visibleOnlyItems: [MenuBarItem] {
        allDetectedItems.filter { !hiddenItemIDs.contains($0.id) && !alwaysHiddenItemIDs.contains($0.id) }
    }
}

struct MenuBarItem: Identifiable, Hashable, @unchecked Sendable {
    let id: String
    let name: String
    let icon: NSImage?
    var isHidden: Bool

    init(id: String, name: String, icon: NSImage? = nil, isHidden: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isHidden = isHidden
    }
}

@MainActor
final class FrostDelegate: NSObject, NSApplicationDelegate {
    let state = FrostState()
    private var statusItem: NSStatusItem!
    private var hiddenControlItem: NSStatusItem!
    private var alwaysHiddenControlItem: NSStatusItem!
    private var pollTimer: Timer?
    private var permissionCheckTimer: Timer?

    // Width constants for the push-to-hide technique
    private let chevronWidth: CGFloat = 20
    private let hiddenWidth: CGFloat = 10000  // extremely wide to push items off-screen

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Create the main Frost status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureMainStatusItem()

        // Create hidden section control item — sits between visible and hidden items
        // When expanded to a huge width, pushes hidden items off-screen
        hiddenControlItem = NSStatusBar.system.statusItem(withLength: chevronWidth)
        configureHiddenControlItem()

        // Create always-hidden section control item
        alwaysHiddenControlItem = NSStatusBar.system.statusItem(withLength: chevronWidth)
        configureAlwaysHiddenControlItem()

        // Apply initial visibility state
        applyHiddenSectionVisibility()
        applyAlwaysHiddenVisibility()

        // Check Accessibility permission
        checkAccessibilityPermission()

        // Start permission monitoring (in case user grants it later)
        startPermissionMonitoring()

        // Start polling for menu bar items
        startPolling()
    }

    // MARK: - Status Item Configuration

    private func configureMainStatusItem() {
        if let button = statusItem.button {
            button.image = createFrostIcon()
            button.image?.isTemplate = true
            button.toolTip = "Frost"
        }
        statusItem.menu = buildMainMenu()
    }

    private func configureHiddenControlItem() {
        if let button = hiddenControlItem.button {
            button.image = createChevronIcon(direction: .left)
            button.image?.isTemplate = true
            button.toolTip = "Frost — Click to toggle hidden section"
            button.action = #selector(toggleHiddenSection)
            button.target = self
        }
    }

    private func configureAlwaysHiddenControlItem() {
        if let button = alwaysHiddenControlItem.button {
            button.image = createChevronIcon(direction: .left)
            button.image?.isTemplate = true
            button.toolTip = "Frost — Click to toggle always-hidden section"
            button.action = #selector(toggleAlwaysHiddenSection)
            button.target = self
        }
        // Always-hidden starts collapsed
        alwaysHiddenControlItem.length = hiddenWidth
    }

    // MARK: - Physical Hiding (Push Technique)

    /// When hidden section is collapsed: control item expands to huge width,
    /// pushing items to its left off-screen.
    /// When expanded: control item shrinks to just the chevron.
    private func applyHiddenSectionVisibility() {
        hiddenControlItem.length = state.isHiddenSectionVisible ? chevronWidth : hiddenWidth
    }

    private func applyAlwaysHiddenVisibility() {
        // Always-hidden items are always pushed off unless explicitly shown
        let showAlwaysHidden = state.isHiddenSectionVisible && state.autoHideEnabled == false
        alwaysHiddenControlItem.length = showAlwaysHidden ? chevronWidth : hiddenWidth
    }

    // MARK: - Accessibility Permission

    private nonisolated func checkAXTrusted(prompt: Bool) -> Bool {
        // kAXTrustedCheckOptionPrompt is a global CFStringRef — safe to read but Swift 6 flags it
        let key: String = "AXTrustedCheckOptionPrompt"
        let dict: CFDictionary = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(dict)
    }

    private func checkAccessibilityPermission() {
        let trusted = checkAXTrusted(prompt: false)
        state.hasAccessibilityPermission = trusted

        if !trusted {
            DispatchQueue.main.async { [weak self] in
                self?.showPermissionAlert()
            }
        }
    }

    private func startPermissionMonitoring() {
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let trusted = self.checkAXTrusted(prompt: false)
                if trusted != self.state.hasAccessibilityPermission {
                    self.state.hasAccessibilityPermission = trusted
                    if trusted {
                        self.permissionCheckTimer?.invalidate()
                        self.refreshMenuBarItems()
                    }
                }
            }
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Frost Needs Accessibility Permission"
        alert.informativeText = """
        Frost uses the Accessibility API to detect and manage your menu bar items.

        To grant permission:
        1. Open System Settings > Privacy & Security > Accessibility
        2. Add Frost (or toggle it on)

        Frost will automatically detect when permission is granted.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Launch at Login

    func setLaunchAtLogin(_ enabled: Bool) {
        state.launchAtLogin = enabled
        do {
            if #available(macOS 13.0, *) {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("Frost: Failed to \(enabled ? "register" : "unregister") launch at login: \(error)")
            state.launchAtLogin = !enabled
        }
    }

    // MARK: - Menu Building

    private func buildMainMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(withTitle: "Frost", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        // Permission status
        if !state.hasAccessibilityPermission {
            let permItem = menu.addItem(withTitle: "⚠ No Accessibility Permission", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            permItem.target = self
            menu.addItem(.separator())
        }

        let aboutItem = menu.addItem(withTitle: "About Frost", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self

        let settingsItem = menu.addItem(withTitle: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self

        menu.addItem(.separator())

        // Visible items (click to hide)
        let visibleHeader = menu.addItem(withTitle: "Visible (\(state.visibleOnlyItems.count))", action: nil, keyEquivalent: "")
        visibleHeader.isEnabled = false

        for item in state.visibleOnlyItems.prefix(15) {
            let submenu = NSMenu()
            let hideItem = submenu.addItem(withTitle: "Hide", action: #selector(hideItem(_:)), keyEquivalent: "")
            hideItem.target = self
            hideItem.representedObject = item
            let alwaysHideItem = submenu.addItem(withTitle: "Always Hide", action: #selector(alwaysHideItem(_:)), keyEquivalent: "")
            alwaysHideItem.target = self
            alwaysHideItem.representedObject = item

            let menuItem = menu.addItem(withTitle: item.name, action: nil, keyEquivalent: "")
            menuItem.submenu = submenu
        }

        menu.addItem(.separator())

        // Hidden items (click to unhide)
        let hiddenHeader = menu.addItem(withTitle: "Hidden (\(state.hiddenItems.count))", action: nil, keyEquivalent: "")
        hiddenHeader.isEnabled = false

        for item in state.hiddenItems.prefix(15) {
            let menuItem = menu.addItem(withTitle: item.name, action: #selector(unhideItem(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item
        }

        menu.addItem(.separator())

        // Always-hidden items
        let alwaysHeader = menu.addItem(withTitle: "Always Hidden (\(state.alwaysHiddenItems.count))", action: nil, keyEquivalent: "")
        alwaysHeader.isEnabled = false

        for item in state.alwaysHiddenItems.prefix(15) {
            let menuItem = menu.addItem(withTitle: item.name, action: #selector(unhideAlwaysItem(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item
        }

        menu.addItem(.separator())

        let autoHideItem = menu.addItem(withTitle: "Auto-hide enabled", action: #selector(toggleAutoHide), keyEquivalent: "")
        autoHideItem.target = self
        autoHideItem.state = state.autoHideEnabled ? .on : .off

        let loginItem = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = state.launchAtLogin ? .on : .off

        menu.addItem(.separator())

        let quitItem = menu.addItem(withTitle: "Quit Frost", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self

        return menu
    }

    // MARK: - Icon Creation

    private func createFrostIcon() -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()

        // Draw a snowflake
        let path = NSBezierPath()
        let center = NSPoint(x: 8, y: 8)

        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3.0
            let endX = center.x + cos(angle) * 6
            let endY = center.y + sin(angle) * 6
            path.move(to: center)
            path.line(to: NSPoint(x: endX, y: endY))

            // Small branch lines
            let branchStart = NSPoint(x: center.x + cos(angle) * 3.5, y: center.y + sin(angle) * 3.5)
            let branchAngle1 = angle + .pi / 6
            let branchAngle2 = angle - .pi / 6
            path.move(to: branchStart)
            path.line(to: NSPoint(x: branchStart.x + cos(branchAngle1) * 2, y: branchStart.y + sin(branchAngle1) * 2))
            path.move(to: branchStart)
            path.line(to: NSPoint(x: branchStart.x + cos(branchAngle2) * 2, y: branchStart.y + sin(branchAngle2) * 2))
        }
        path.lineWidth = 1.2
        NSColor.controlTextColor.setStroke()
        path.stroke()

        image.unlockFocus()
        return image
    }

    private enum ChevronDirection {
        case left, right
    }

    private func createChevronIcon(direction: ChevronDirection) -> NSImage {
        let size = NSSize(width: 8, height: 14)
        let image = NSImage(size: size)
        image.lockFocus()

        let path = NSBezierPath()
        path.lineWidth = 2
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        if direction == .left {
            path.move(to: NSPoint(x: 6, y: 4))
            path.line(to: NSPoint(x: 2, y: 7))
            path.line(to: NSPoint(x: 6, y: 10))
        } else {
            path.move(to: NSPoint(x: 2, y: 4))
            path.line(to: NSPoint(x: 6, y: 7))
            path.line(to: NSPoint(x: 2, y: 10))
        }

        NSColor.controlTextColor.setStroke()
        path.stroke()

        image.unlockFocus()
        return image
    }

    // MARK: - App Icon Generation (for .app bundle)

    static func generateAppIcon(size: Int) -> NSImage {
        let nsSize = NSSize(width: size, height: size)
        let image = NSImage(size: nsSize)
        image.lockFocus()

        // Background — rounded rect with gradient blue
        let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
        let radius = CGFloat(size) * 0.22
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: radius, yRadius: radius)

        // Gradient
        let gradient = NSGradient(colors: [
            NSColor(srgbRed: 0.35, green: 0.6, blue: 0.95, alpha: 1.0),
            NSColor(srgbRed: 0.15, green: 0.35, blue: 0.8, alpha: 1.0)
        ])
        gradient?.draw(in: bgPath, angle: -90)

        // Draw snowflake in white
        let center = NSPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2)
        let armLength = CGFloat(size) * 0.3
        let path = NSBezierPath()
        path.lineWidth = CGFloat(size) * 0.04

        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3.0
            let endX = center.x + cos(angle) * armLength
            let endY = center.y + sin(angle) * armLength
            path.move(to: center)
            path.line(to: NSPoint(x: endX, y: endY))

            // Branch lines
            let branchDist = armLength * 0.55
            let branchStart = NSPoint(x: center.x + cos(angle) * branchDist, y: center.y + sin(angle) * branchDist)
            let branchLen = armLength * 0.3
            let ba1 = angle + .pi / 6
            let ba2 = angle - .pi / 6
            path.move(to: branchStart)
            path.line(to: NSPoint(x: branchStart.x + cos(ba1) * branchLen, y: branchStart.y + sin(ba1) * branchLen))
            path.move(to: branchStart)
            path.line(to: NSPoint(x: branchStart.x + cos(ba2) * branchLen, y: branchStart.y + sin(ba2) * branchLen))
        }

        NSColor.white.setStroke()
        path.stroke()

        image.unlockFocus()
        return image
    }

    // MARK: - Menu Bar Item Detection

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMenuBarItems()
            }
        }
        refreshMenuBarItems()
    }

    private func refreshMenuBarItems() {
        let items = scanMenuBarItems()
        state.allDetectedItems = items
        state.visibleItems = state.visibleOnlyItems
        rebuildMenu()
    }

    private func scanMenuBarItems() -> [MenuBarItem] {
        var items: [MenuBarItem] = []

        let systemWideElement = AXUIElementCreateSystemWide()

        var menuBarRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXMenuBarAttribute as CFString, &menuBarRef)

        guard result == .success, let menuBar = menuBarRef else {
            return items
        }
        let menuBarElement = menuBar as! AXUIElement

        var childrenRef: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &childrenRef)

        guard childrenResult == .success, let children = childrenRef else {
            return items
        }
        let childrenArray = children as! [AXUIElement]

        for (index, child) in childrenArray.enumerated() {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef)
            let title = (titleRef as? String) ?? "Unknown"

            if index == 0 { continue }
            if title == "Frost" || title.contains("Hidden Section") || title.contains("toggle") { continue }

            // Use AX position to create a stable ID
            var positionRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &positionRef)
            var posValue = CGPoint.zero
            if let val = positionRef {
                AXValueGetValue(val as! AXValue, .cgPoint, &posValue)
            }

            let itemId = "mb_\(Int(posValue.x))_\(title.isEmpty ? "item" : title)"

            let item = MenuBarItem(
                id: itemId,
                name: title.isEmpty ? "Item \(index)" : title,
                icon: nil,
                isHidden: false
            )
            items.append(item)
        }

        return items
    }

    private func rebuildMenu() {
        statusItem.menu = buildMainMenu()
    }

    // MARK: - Actions

    @objc func toggleHiddenSection() {
        state.isHiddenSectionVisible.toggle()
        applyHiddenSectionVisibility()
        rebuildMenu()
    }

    @objc func toggleAlwaysHiddenSection() {
        // Show/hide always-hidden items
        alwaysHiddenControlItem.length = (alwaysHiddenControlItem.length > chevronWidth) ? chevronWidth : hiddenWidth
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Frost"
        alert.informativeText = "Menu bar manager for macOS Tahoe\n\nA lightweight, open-source alternative to Ice/Bartender\n\nVersion 1.1.0\nMIT License"
        alert.alertStyle = .informational
        alert.icon = createFrostIcon()
        alert.runModal()
    }

    @objc func showSettings() {
        NSApp.activate()
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc func toggleAutoHide() {
        state.autoHideEnabled.toggle()
        applyAlwaysHiddenVisibility()
        rebuildMenu()
    }

    @objc func toggleLaunchAtLogin() {
        setLaunchAtLogin(!state.launchAtLogin)
        rebuildMenu()
    }

    @objc func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func hideItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? MenuBarItem else { return }
        state.hiddenItemIDs.insert(item.id)
        rebuildMenu()
    }

    @objc func alwaysHideItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? MenuBarItem else { return }
        state.alwaysHiddenItemIDs.insert(item.id)
        rebuildMenu()
    }

    @objc func unhideItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? MenuBarItem else { return }
        state.hiddenItemIDs.remove(item.id)
        rebuildMenu()
    }

    @objc func unhideAlwaysItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? MenuBarItem else { return }
        state.alwaysHiddenItemIDs.remove(item.id)
        rebuildMenu()
    }

    @objc func quit() {
        NSApp.terminate(self)
    }
}