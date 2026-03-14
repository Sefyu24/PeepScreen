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

struct ThemeSectionView: View {
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        Section("Theme") {
            Picker("Color Scheme", selection: $themeManager.currentTheme) {
                ForEach(themeManager.allThemes) { theme in
                    Text(theme.name).tag(theme)
                }
            }

            ColorPreviewStrip(colors: themeManager.currentTheme.ansiColors)

            HStack {
                Button("Import Theme File...") {
                    themeManager.importTheme()
                }
                Button("Auto-Detect") {
                    let found = themeManager.autoDetectThemes()
                    for theme in found {
                        themeManager.customThemes.removeAll { $0.id == theme.id }
                        themeManager.customThemes.append(theme)
                    }
                    if let first = found.first {
                        themeManager.currentTheme = first
                    }
                }
            }
        }
    }
}

struct ColorPreviewStrip: View {
    var colors: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<min(colors.count, 16), id: \.self) { i in
                Rectangle()
                    .fill(Color(nsColor: TerminalTheme.nsColor(from: colors[i])))
                    .frame(width: 16, height: 16)
                    .cornerRadius(2)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FontSectionView: View {
    @ObservedObject var themeManager: ThemeManager

    var body: some View {
        Section("Font") {
            TextField("Font Family (blank = system mono)", text: $themeManager.fontFamily)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text("Size")
                Slider(value: $themeManager.fontSize, in: 8...28, step: 1)
                Text("\(Int(themeManager.fontSize))pt")
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }
}

extension Notification.Name {
    static let preferencesChanged = Notification.Name("PreferencesChanged")
    static let themeChanged = Notification.Name("ThemeChanged")
}

struct PreferencesView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var themeManager = ThemeManager.shared

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: $prefs.launchAtLogin)
            }

            Section("Terminal") {
                TextField("Default Shell", text: $prefs.defaultShell)
                    .textFieldStyle(.roundedBorder)
            }

            ThemeSectionView(themeManager: themeManager)

            FontSectionView(themeManager: themeManager)

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
        .frame(width: 420, height: 480)
        .onChange(of: prefs.panelOpacity) { _, _ in
            NotificationCenter.default.post(name: .preferencesChanged, object: nil)
        }
    }
}
