import Testing
@testable import Frost

@MainActor
final class FrostStateTests {

    @Test("FrostState initializes with correct defaults")
    func initialState() {
        let state = FrostState()
        #expect(state.isHiddenSectionVisible == false)
        #expect(state.hiddenItems == [])
        #expect(state.visibleItems == [])
        #expect(state.alwaysHiddenItems == [])
        #expect(state.autoHideEnabled == true)
        #expect(state.iceIconVisible == true)
    }

    @Test("FrostState toggles isHiddenSectionVisible")
    func toggleHiddenSection() {
        let state = FrostState()
        state.isHiddenSectionVisible = true
        #expect(state.isHiddenSectionVisible == true)
        state.isHiddenSectionVisible = false
        #expect(state.isHiddenSectionVisible == false)
    }

    @Test("FrostState toggles autoHideEnabled")
    func toggleAutoHide() {
        let state = FrostState()
        #expect(state.autoHideEnabled == true)
        state.autoHideEnabled = false
        #expect(state.autoHideEnabled == false)
    }

    @Test("FrostState toggles iceIconVisible")
    func toggleIceIcon() {
        let state = FrostState()
        #expect(state.iceIconVisible == true)
        state.iceIconVisible = false
        #expect(state.iceIconVisible == false)
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
        #expect(item.id == "test_2")
        #expect(item.name == "HiddenItem")
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

    @Test("MenuBarItem id uniqueness via index string")
    func idUniqueness() {
        let item1 = MenuBarItem(id: "item_1", name: "A")
        let item2 = MenuBarItem(id: "item_2", name: "B")
        #expect(item1.id != item2.id)
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

    @Test("Moving item from visible to hidden")
    func hideItem() {
        let state = FrostState()
        let item = MenuBarItem(id: "item_5", name: "Wifi")
        state.visibleItems = [item]

        // Simulate hide logic from FrostDelegate.hideItem
        state.visibleItems.removeAll { $0.id == item.id }
        var hiddenItem = item
        hiddenItem.isHidden = true
        state.hiddenItems.append(hiddenItem)

        #expect(state.visibleItems.count == 0)
        #expect(state.hiddenItems.count == 1)
        #expect(state.hiddenItems.first?.id == "item_5")
        #expect(state.hiddenItems.first?.isHidden == true)
    }

    @Test("Moving item from hidden to visible")
    func unhideItem() {
        let state = FrostState()
        let item = MenuBarItem(id: "item_3", name: "Bluetooth", isHidden: true)
        state.hiddenItems = [item]

        // Simulate unhide logic from FrostDelegate.unhideItem
        state.hiddenItems.removeAll { $0.id == item.id }
        var visibleItem = item
        visibleItem.isHidden = false
        state.visibleItems.append(visibleItem)

        #expect(state.hiddenItems.count == 0)
        #expect(state.visibleItems.count == 1)
        #expect(state.visibleItems.first?.id == "item_3")
        #expect(state.visibleItems.first?.isHidden == false)
    }

    @Test("Hiding multiple items preserves others")
    func hideMultiplePreservesOthers() {
        let state = FrostState()
        let item1 = MenuBarItem(id: "item_1", name: "A")
        let item2 = MenuBarItem(id: "item_2", name: "B")
        let item3 = MenuBarItem(id: "item_3", name: "C")
        state.visibleItems = [item1, item2, item3]

        // Hide item2
        state.visibleItems.removeAll { $0.id == item2.id }
        var hidden = item2
        hidden.isHidden = true
        state.hiddenItems.append(hidden)

        #expect(state.visibleItems.count == 2)
        #expect(state.visibleItems.contains { $0.id == "item_1" })
        #expect(state.visibleItems.contains { $0.id == "item_3" })
        #expect(!state.visibleItems.contains { $0.id == "item_2" })
        #expect(state.hiddenItems.count == 1)
    }

    @Test("Unhiding when no items are hidden does nothing")
    func unhideEmpty() {
        let state = FrostState()
        state.hiddenItems.removeAll { $0.id == "nonexistent" }
        #expect(state.hiddenItems.count == 0)
    }

    @Test("Hiding already-hidden item has no duplicate effect")
    func hideAlreadyHidden() {
        let state = FrostState()
        let item = MenuBarItem(id: "item_1", name: "A", isHidden: true)
        state.hiddenItems = [item]

        // Trying to hide again (shouldn't create duplicate)
        state.visibleItems.removeAll { $0.id == item.id }
        var hidden = item
        hidden.isHidden = true
        // Only append if not already in hidden
        if !state.hiddenItems.contains(where: { $0.id == hidden.id }) {
            state.hiddenItems.append(hidden)
        }

        #expect(state.hiddenItems.count == 1)
    }

    @Test("Visible items filter excludes hidden items")
    func filterVisibleItems() {
        let state = FrostState()
        let visible = MenuBarItem(id: "item_1", name: "A", isHidden: false)
        let hidden = MenuBarItem(id: "item_2", name: "B", isHidden: true)
        let allItems = [visible, hidden]
        state.visibleItems = allItems.filter { !$0.isHidden }
        state.hiddenItems = allItems.filter { $0.isHidden }
        #expect(state.visibleItems.count == 1)
        #expect(state.hiddenItems.count == 1)
        #expect(state.visibleItems.first?.id == "item_1")
        #expect(state.hiddenItems.first?.id == "item_2")
    }
}