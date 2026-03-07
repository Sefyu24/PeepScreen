//
//  StatusBarController.swift
//  PeepScreen
//

import AppKit

class StatusBarController: NSObject, NSMenuDelegate, PanelStateDelegate {

    private let statusItem: NSStatusItem
    private weak var stateManager: PanelStateManager?
    private weak var panel: FloatingPanel?

    var onTogglePanel: (() -> Void)?
    var onPreferencesRequested: (() -> Void)?

    init(stateManager: PanelStateManager, panel: FloatingPanel) {
        self.stateManager = stateManager
        self.panel = panel
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "PeepScreen")
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        stateManager.statusBarObserver = self
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let panelVisible = panel?.isVisible ?? false
        let toggleItem = NSMenuItem(
            title: panelVisible ? "Hide Panel" : "Show Panel",
            action: #selector(togglePanel),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let currentState = stateManager?.currentState ?? .expanded
        addStateItem(to: menu, title: "Expanded", state: .expanded, current: currentState)
        addStateItem(to: menu, title: "Mini", state: .mini, current: currentState)

        let tuckedTitle = "Tucked"
        let tuckedItem = NSMenuItem(title: tuckedTitle, action: nil, keyEquivalent: "")
        if case .tucked = currentState {
            tuckedItem.state = .on
        }
        menu.addItem(tuckedItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.keyEquivalentModifierMask = .command
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit PeepScreen",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)
    }

    private func addStateItem(to menu: NSMenu, title: String, state: PanelState, current: PanelState) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.state = (current == state) ? .on : .off
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func togglePanel() {
        onTogglePanel?()
    }

    @objc private func openPreferences() {
        onPreferencesRequested?()
    }

    // MARK: - PanelStateDelegate

    func panelStateDidChange(to state: PanelState) {
        // Icon updates happen dynamically via menuNeedsUpdate
    }
}
