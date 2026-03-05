//
//  AppDelegate.swift
//  PeepScreen
//

import AppKit
import SwiftTerm

class AppDelegate: NSObject, NSApplicationDelegate, LocalProcessTerminalViewDelegate, TerminalViewDelegate {

    private var panel: FloatingPanel!
    private var terminalView: DroppableTerminalView!
    private let stateManager = PanelStateManager()
    private var miniUpdateWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panelRect = NSRect(x: 0, y: 0, width: 500, height: 350)

        terminalView = DroppableTerminalView(frame: NSRect(x: 0, y: 0, width: 500, height: 326))
        terminalView.processDelegate = self
        terminalView.terminalDelegate = self
        terminalView.nativeBackgroundColor = .clear

        panel = FloatingPanel(contentRect: panelRect, terminalView: terminalView, stateManager: stateManager)
        panel.center()
        panel.lastExpandedFrame = panel.frame
        panel.orderFrontRegardless()

        DispatchQueue.main.async { [self] in
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let home = NSHomeDirectory()
            terminalView.startProcess(executable: shell, environment: nil, execName: "-zsh", currentDirectory: home)
            panel.makeFirstResponder(terminalView)
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

    // MARK: - TerminalViewDelegate

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
    }

    func setTerminalTitle(source: TerminalView, title: String) {
    }

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
    }

    func scrolled(source: TerminalView, position: Double) {
    }

    func clipboardCopy(source: TerminalView, content: Data) {
    }

    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
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
