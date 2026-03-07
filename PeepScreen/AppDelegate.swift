//
//  AppDelegate.swift
//  PeepScreen
//

import AppKit
import SwiftTerm

class AppDelegate: NSObject, NSApplicationDelegate, LocalProcessTerminalViewDelegate {

    var panel: FloatingPanel!
    private var terminalView: DroppableTerminalView!
    private let stateManager = PanelStateManager()
    private var miniUpdateWorkItem: DispatchWorkItem?
    private var statusBarController: StatusBarController!
    private var globalMonitor: Any?

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
        panel.center()
        panel.lastExpandedFrame = panel.frame
        panel.makeKeyAndOrderFront(nil)

        panel.applyPreferences()

        statusBarController = StatusBarController(stateManager: stateManager, panel: panel)
        statusBarController.onTogglePanel = { [weak self] in self?.togglePanelVisibility() }
        statusBarController.onPreferencesRequested = { [weak self] in self?.showPreferences() }

        setupGlobalHotkey()

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
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(terminalView)
        }
    }

    // MARK: - Preferences

    func showPreferences() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    // MARK: - Global Hotkey

    private func setupGlobalHotkey() {
        guard AXIsProcessTrusted() else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if mods == [.command, .shift] && event.charactersIgnoringModifiers == "t" {
                self?.togglePanelVisibility()
            }
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
