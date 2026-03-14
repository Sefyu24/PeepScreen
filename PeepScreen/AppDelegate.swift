//
//  AppDelegate.swift
//  PeepScreen
//

import AppKit
import SwiftUI
import SwiftTerm

class AppDelegate: NSObject, NSApplicationDelegate, LocalProcessTerminalViewDelegate {

    var panel: FloatingPanel!
    private var terminalView: DroppableTerminalView!
    private let stateManager = PanelStateManager()
    private var miniUpdateWorkItem: DispatchWorkItem?
    private var statusBarController: StatusBarController!
    private var previousApp: NSRunningApplication?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var preferencesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panelRect = NSRect(x: 0, y: 0, width: 500, height: 350)

        terminalView = DroppableTerminalView(frame: NSRect(x: 0, y: 0, width: 500, height: 326))
        terminalView.processDelegate = self
        terminalView.nativeBackgroundColor = .clear

        terminalView.onRangeChanged = { [weak self] startY, endY in
            self?.handleRangeChanged(startY: startY, endY: endY)
        }

        panel = FloatingPanel(contentRect: panelRect, terminalView: terminalView, stateManager: stateManager)

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - panelRect.width / 2
            let y = screenFrame.midY - panelRect.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.lastExpandedFrame = panel.frame
        panel.makeKeyAndOrderFront(nil)

        panel.applyPreferences()

        statusBarController = StatusBarController(stateManager: stateManager, panel: panel)
        statusBarController.onTogglePanel = { [weak self] in self?.togglePanelVisibility() }
        statusBarController.onPreferencesRequested = { [weak self] in self?.showPreferences() }

        setupGlobalHotkey()
        setupPreferencesObservers()

        DispatchQueue.main.async { [self] in
            let shell = PreferencesManager.shared.defaultShell
            let home = NSHomeDirectory()
            terminalView.startProcess(executable: shell, environment: nil, execName: "-\(((shell as NSString).lastPathComponent))", currentDirectory: home)
            panel.makeKey()
            panel.makeFirstResponder(terminalView)
        }
    }

    // MARK: - Panel Toggle

    func togglePanelVisibility() {
        switch stateManager.currentState {
        case .expanded, .mini:
            previousApp = NSWorkspace.shared.frontmostApplication
            stateManager.tuck(edge: .left)
            previousApp?.activate()
        case .tucked:
            stateManager.untuck()
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(terminalView)
        }
    }

    // MARK: - Preferences

    func showPreferences() {
        if let existing = preferencesWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Dispatch async so the status bar menu fully closes first —
        // otherwise NSApp.activate can be swallowed on accessory apps.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let hostingController = NSHostingController(rootView: PreferencesView())
            let window = NSWindow(contentViewController: hostingController)
            window.styleMask = [.titled, .closable]
            window.title = "PeepScreen Settings"
            window.center()
            window.isReleasedWhenClosed = false
            window.level = .floating
            self.preferencesWindow = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Global Hotkey

    private func setupGlobalHotkey() {
        // Local monitor: works when our app is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) &&
               event.keyCode == 17 { // 17 = T key
                self?.togglePanelVisibility()
                return nil
            }
            // Cmd+, for preferences
            if event.modifierFlags.contains(.command) &&
               event.charactersIgnoringModifiers == "," {
                self?.showPreferences()
                return nil
            }
            return event
        }

        // Global monitor: works when another app is focused (requires Accessibility)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) &&
               event.keyCode == 17 {
                self?.togglePanelVisibility()
            }
        }
    }

    // MARK: - Preferences Observers

    private func setupPreferencesObservers() {
        NotificationCenter.default.addObserver(
            forName: .preferencesChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.panel?.applyPreferences()
        }
        NotificationCenter.default.addObserver(
            forName: .themeChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.panel?.applyTheme()
        }
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
    }

    // MARK: - Terminal range change (for mini mode)

    private func handleRangeChanged(startY: Int, endY: Int) {
        miniUpdateWorkItem?.cancel()
        miniUpdateWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let terminal = self.terminalView.getTerminal()
            let cursorRow = terminal.buffer.y
            if let line = terminal.getLine(row: cursorRow) {
                let text = line.translateToString(trimRight: true)
                if !text.isEmpty {
                    self.stateManager.lastLineText = text
                    self.panel?.updateMiniContent()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: miniUpdateWorkItem!)
    }
}
