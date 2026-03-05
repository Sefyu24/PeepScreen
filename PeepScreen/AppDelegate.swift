//
//  AppDelegate.swift
//  PeepScreen
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private var panel: FloatingPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let panelRect = NSRect(x: 0, y: 0, width: 280, height: 48)
        panel = FloatingPanel(contentRect: panelRect, rootView: PanelContentView())
        panel.center()
        panel.orderFrontRegardless()
    }
}
