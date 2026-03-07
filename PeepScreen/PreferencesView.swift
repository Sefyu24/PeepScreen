//
//  PreferencesView.swift
//  PeepScreen
//

import SwiftUI
import ServiceManagement

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { updateLoginItem() }
    }
    @AppStorage("defaultShell") var defaultShell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    @AppStorage("panelOpacity") var panelOpacity: Double = 1.0

    private func updateLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Login item error: \(error)")
        }
    }
}

struct PreferencesView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    var onOpacityChanged: ((Double) -> Void)?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $prefs.launchAtLogin)
            }

            Section("Terminal") {
                TextField("Default Shell", text: $prefs.defaultShell)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Appearance") {
                HStack {
                    Text("Panel Opacity")
                    Slider(value: $prefs.panelOpacity, in: 0.3...1.0, step: 0.05)
                    Text("\(Int(prefs.panelOpacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 240)
        .onChange(of: prefs.panelOpacity) { _, newValue in
            onOpacityChanged?(newValue)
        }
    }
}
