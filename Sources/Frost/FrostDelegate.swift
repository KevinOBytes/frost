import AppKit
import SwiftUI

@MainActor
final class FrostState: ObservableObject {
    @Published var isHiddenSectionVisible: Bool = false
    @Published var hiddenItems: [MenuBarItem] = []
    @Published var visibleItems: [MenuBarItem] = []
    @Published var alwaysHiddenItems: [MenuBarItem] = []
    @Published var autoHideEnabled: Bool = true
    @Published var iceIconVisible: Bool = true
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Create the main Frost status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureMainStatusItem()

        // Create hidden section control item
        hiddenControlItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureHiddenControlItem()

        // Create always-hidden section control item
        alwaysHiddenControlItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureAlwaysHiddenControlItem()

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
            button.toolTip = "Frost — Hidden Section"
            button.action = #selector(toggleHiddenSection)
            button.target = self
        }
    }

    private func configureAlwaysHiddenControlItem() {
        if let button = alwaysHiddenControlItem.button {
            button.image = createChevronIcon(direction: .left)
            button.image?.isTemplate = true
            button.toolTip = "Frost — Always Hidden Section"
            button.action = #selector(toggleAlwaysHiddenSection)
            button.target = self
        }
        alwaysHiddenControlItem.isVisible = false
    }

    // MARK: - Menu Building

    private func buildMainMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(withTitle: "Frost", action: nil, keyEquivalent: "")
        menu.addItem(.separator())

        let aboutItem = menu.addItem(withTitle: "About Frost", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self

        let settingsItem = menu.addItem(withTitle: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self

        menu.addItem(.separator())

        // List visible items
        let visibleHeader = menu.addItem(withTitle: "Visible Items (\(state.visibleItems.count))", action: nil, keyEquivalent: "")
        visibleHeader.isEnabled = false

        for item in state.visibleItems.prefix(10) {
            let menuItem = menu.addItem(withTitle: item.name, action: #selector(hideItem(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item
            menuItem.image = item.icon
        }

        menu.addItem(.separator())

        // List hidden items
        let hiddenHeader = menu.addItem(withTitle: "Hidden Items (\(state.hiddenItems.count))", action: nil, keyEquivalent: "")
        hiddenHeader.isEnabled = false

        for item in state.hiddenItems.prefix(10) {
            let menuItem = menu.addItem(withTitle: item.name, action: #selector(unhideItem(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item
            menuItem.image = item.icon
        }

        menu.addItem(.separator())

        let autoHideItem = menu.addItem(withTitle: "Auto-hide enabled", action: #selector(toggleAutoHide), keyEquivalent: "")
        autoHideItem.target = self
        autoHideItem.state = state.autoHideEnabled ? .on : .off

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

        let path = NSBezierPath()
        let center = NSPoint(x: 8, y: 8)

        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3.0
            let endX = center.x + cos(angle) * 6
            let endY = center.y + sin(angle) * 6
            path.move(to: center)
            path.line(to: NSPoint(x: endX, y: endY))
        }
        path.lineWidth = 1.5
        NSColor.controlTextColor.setStroke()
        path.stroke()

        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3.0
            let dotX = center.x + cos(angle) * 6
            let dotY = center.y + sin(angle) * 6
            let dotRect = NSRect(x: dotX - 1, y: dotY - 1, width: 2, height: 2)
            NSColor.controlTextColor.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
        }

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
        state.visibleItems = items.filter { !$0.isHidden }
        state.hiddenItems = items.filter { $0.isHidden }
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
            if title == "Frost" || title.contains("Hidden Section") { continue }

            let item = MenuBarItem(
                id: "item_\(index)",
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
        showHiddenItemsPopover()
    }

    @objc func toggleAlwaysHiddenSection() {
        alwaysHiddenControlItem.isVisible.toggle()
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Frost"
        alert.informativeText = "Menu bar manager for macOS Tahoe\n\nA lightweight alternative to Ice/Bartender"
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
        rebuildMenu()
    }

    @objc func hideItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? MenuBarItem else { return }
        state.visibleItems.removeAll { $0.id == item.id }
        var hiddenItem = item
        hiddenItem.isHidden = true
        state.hiddenItems.append(hiddenItem)
        rebuildMenu()
    }

    @objc func unhideItem(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? MenuBarItem else { return }
        state.hiddenItems.removeAll { $0.id == item.id }
        var visibleItem = item
        visibleItem.isHidden = false
        state.visibleItems.append(visibleItem)
        rebuildMenu()
    }

    @objc func quit() {
        NSApp.terminate(self)
    }

    // MARK: - Hidden Items Popover

    private func showHiddenItemsPopover() {
        if state.hiddenItems.isEmpty {
            return
        }

        guard let button = hiddenControlItem.button else { return }

        let menu = NSMenu()
        let header = menu.addItem(withTitle: "Hidden Items", action: nil, keyEquivalent: "")
        header.isEnabled = false

        menu.addItem(.separator())

        for item in state.hiddenItems {
            let menuItem = menu.addItem(withTitle: item.name, action: #selector(unhideItem(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = item
            menuItem.image = item.icon
        }

        if let event = NSApp.currentEvent {
            menu.popUp(positioning: nil, at: event.locationInWindow, in: button)
        }
    }
}