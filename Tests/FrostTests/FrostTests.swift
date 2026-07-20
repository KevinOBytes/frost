import Testing
import Foundation
@testable import Frost

@MainActor
final class FrostStateTests {

    @Test("FrostState initializes with persisted values from UserDefaults")
    func initialState() {
        // Clear any existing state
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "com.tkoresearch.frost")

        let state = FrostState()
        // With no persisted state, defaults should apply
        #expect(state.hiddenItemIDs == [])
        #expect(state.alwaysHiddenItemIDs == [])
        #expect(state.autoHideEnabled == true)
        #expect(state.frostIconVisible == true)
        #expect(state.launchAtLogin == false)
        #expect(state.hasAccessibilityPermission == false)
    }

    @Test("FrostState persists hiddenItemIDs")
    func persistHiddenIDs() {
        let state = FrostState()
        state.hiddenItemIDs = ["item_1", "item_2", "item_3"]

        // Create a new state — should load from UserDefaults
        let state2 = FrostState()
        #expect(state2.hiddenItemIDs == ["item_1", "item_2", "item_3"])

        // Cleanup
        state2.hiddenItemIDs = []
    }

    @Test("FrostState persists alwaysHiddenItemIDs")
    func persistAlwaysHiddenIDs() {
        let state = FrostState()
        state.alwaysHiddenItemIDs = ["item_5"]

        let state2 = FrostState()
        #expect(state2.alwaysHiddenItemIDs == ["item_5"])

        // Cleanup
        state2.alwaysHiddenItemIDs = []
    }

    @Test("FrostState toggles autoHideEnabled and persists")
    func toggleAutoHide() {
        let state = FrostState()
        let original = state.autoHideEnabled
        state.autoHideEnabled = !original
        #expect(state.autoHideEnabled != original)

        let state2 = FrostState()
        #expect(state2.autoHideEnabled == !original)

        // Restore
        state2.autoHideEnabled = original
    }

    @Test("FrostState toggles frostIconVisible and persists")
    func toggleIconVisible() {
        let state = FrostState()
        state.frostIconVisible = false
        #expect(state.frostIconVisible == false)

        let state2 = FrostState()
        #expect(state2.frostIconVisible == false)

        // Restore
        state2.frostIconVisible = true
    }

    @Test("FrostState toggles launchAtLogin and persists")
    func toggleLaunchAtLogin() {
        let state = FrostState()
        state.launchAtLogin = true
        #expect(state.launchAtLogin == true)

        let state2 = FrostState()
        #expect(state2.launchAtLogin == true)

        // Restore
        state2.launchAtLogin = false
    }

    @Test("FrostState computed properties filter correctly")
    func computedProperties() {
        let state = FrostState()
        state.allDetectedItems = [
            MenuBarItem(id: "a", name: "A"),
            MenuBarItem(id: "b", name: "B"),
            MenuBarItem(id: "c", name: "C"),
            MenuBarItem(id: "d", name: "D"),
        ]
        state.hiddenItemIDs = ["b"]
        state.alwaysHiddenItemIDs = ["d"]

        #expect(state.hiddenItems.count == 1)
        #expect(state.hiddenItems.first?.id == "b")
        #expect(state.alwaysHiddenItems.count == 1)
        #expect(state.alwaysHiddenItems.first?.id == "d")
        #expect(state.visibleOnlyItems.count == 2)
        #expect(state.visibleOnlyItems.contains { $0.id == "a" })
        #expect(state.visibleOnlyItems.contains { $0.id == "c" })

        // Cleanup
        state.hiddenItemIDs = []
        state.alwaysHiddenItemIDs = []
    }
}

final class MenuBarItemTests {

    @Test("MenuBarItem initializes with defaults")
    func initDefaults() {
        let item = MenuBarItem(id: "test_1", name: "TestItem")
        #expect(item.id == "test_1")
        #expect(item.name == "TestItem")
        #expect(item.icon == nil)
        #expect(item.isHidden == false)
    }

    @Test("MenuBarItem initializes with isHidden=true")
    func initHidden() {
        let item = MenuBarItem(id: "test_2", name: "HiddenItem", isHidden: true)
        #expect(item.isHidden == true)
    }

    @Test("MenuBarItem conforms to Hashable and Equatable")
    func equalityAndHashing() {
        let item1 = MenuBarItem(id: "x", name: "A")
        let item2 = MenuBarItem(id: "x", name: "A")
        let item3 = MenuBarItem(id: "y", name: "B")
        #expect(item1 == item2)
        #expect(item1 != item3)
        #expect(item1.hashValue == item2.hashValue)
    }

    @Test("MenuBarItem isHidden can be mutated")
    func mutableIsHidden() {
        var item = MenuBarItem(id: "test", name: "Test")
        item.isHidden = true
        #expect(item.isHidden == true)
        item.isHidden = false
        #expect(item.isHidden == false)
    }
}

@MainActor
final class HideUnhideLogicTests {

    @Test("Hiding an item adds ID to hiddenItemIDs")
    func hideItem() {
        let state = FrostState()
        state.allDetectedItems = [MenuBarItem(id: "item_5", name: "Wifi")]
        state.hiddenItemIDs.insert("item_5")

        #expect(state.hiddenItemIDs.contains("item_5"))
        #expect(state.hiddenItems.count == 1)
        #expect(state.visibleOnlyItems.count == 0)

        // Cleanup
        state.hiddenItemIDs = []
    }

    @Test("Unhiding removes ID from hiddenItemIDs")
    func unhideItem() {
        let state = FrostState()
        state.allDetectedItems = [MenuBarItem(id: "item_3", name: "BT")]
        state.hiddenItemIDs.insert("item_3")
        state.hiddenItemIDs.remove("item_3")

        #expect(!state.hiddenItemIDs.contains("item_3"))
        #expect(state.hiddenItems.count == 0)
        #expect(state.visibleOnlyItems.count == 1)
    }

    @Test("Always-hiding moves to alwaysHiddenItemIDs")
    func alwaysHideItem() {
        let state = FrostState()
        state.allDetectedItems = [MenuBarItem(id: "item_7", name: "Docker")]
        state.alwaysHiddenItemIDs.insert("item_7")

        #expect(state.alwaysHiddenItems.count == 1)
        #expect(state.visibleOnlyItems.count == 0)
        #expect(state.hiddenItems.count == 0)

        // Cleanup
        state.alwaysHiddenItemIDs = []
    }

    @Test("Unhide from always-hidden removes from alwaysHiddenItemIDs")
    func unhideAlwaysItem() {
        let state = FrostState()
        state.allDetectedItems = [MenuBarItem(id: "item_8", name: "Slack")]
        state.alwaysHiddenItemIDs.insert("item_8")
        state.alwaysHiddenItemIDs.remove("item_8")

        #expect(state.alwaysHiddenItems.count == 0)
        #expect(state.visibleOnlyItems.count == 1)
    }

    @Test("Hiding multiple items preserves others")
    func hideMultiplePreservesOthers() {
        let state = FrostState()
        state.allDetectedItems = [
            MenuBarItem(id: "a", name: "A"),
            MenuBarItem(id: "b", name: "B"),
            MenuBarItem(id: "c", name: "C"),
        ]
        state.hiddenItemIDs.insert("b")

        #expect(state.visibleOnlyItems.count == 2)
        #expect(state.visibleOnlyItems.contains { $0.id == "a" })
        #expect(state.visibleOnlyItems.contains { $0.id == "c" })
        #expect(!state.visibleOnlyItems.contains { $0.id == "b" })
        #expect(state.hiddenItems.count == 1)

        // Cleanup
        state.hiddenItemIDs = []
    }

    @Test("An item can be in both hidden and alwaysHidden (edge case)")
    func itemInBothSets() {
        let state = FrostState()
        state.allDetectedItems = [MenuBarItem(id: "x", name: "X")]
        state.hiddenItemIDs.insert("x")
        state.alwaysHiddenItemIDs.insert("x")

        // It should appear in hidden items, but NOT in visibleOnlyItems
        #expect(state.visibleOnlyItems.count == 0)
        #expect(state.hiddenItems.count == 1)
        #expect(state.alwaysHiddenItems.count == 1)

        // Cleanup
        state.hiddenItemIDs = []
        state.alwaysHiddenItemIDs = []
    }

    @Test("Empty state has no items in any category")
    func emptyState() {
        let state = FrostState()
        state.allDetectedItems = []
        #expect(state.visibleOnlyItems.count == 0)
        #expect(state.hiddenItems.count == 0)
        #expect(state.alwaysHiddenItems.count == 0)
    }
}