//
//  PeepScreenApp.swift
//  PeepScreen
//

import SwiftUI

@main
struct PeepScreenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
