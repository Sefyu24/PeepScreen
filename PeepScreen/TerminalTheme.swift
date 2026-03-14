//
//  TerminalTheme.swift
//  PeepScreen
//

import AppKit
import SwiftTerm

// MARK: - TerminalTheme

struct TerminalTheme: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var ansiColors: [String] // 16 hex strings (#RRGGBB)
    var foreground: String
    var background: String
    var cursorColor: String?
    var selectionColor: String?

    static func nsColor(from hex: String) -> NSColor {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let val = UInt64(h, radix: 16) else {
            return .white
        }
        let r = CGFloat((val >> 16) & 0xFF) / 255.0
        let g = CGFloat((val >> 8) & 0xFF) / 255.0
        let b = CGFloat(val & 0xFF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    static func swiftTermColor(from hex: String) -> Color {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let val = UInt64(h, radix: 16) else {
            return Color(red: 255, green: 255, blue: 255)
        }
        let r = UInt16((val >> 16) & 0xFF)
        let g = UInt16((val >> 8) & 0xFF)
        let b = UInt16(val & 0xFF)
        return Color(red: r, green: g, blue: b)
    }

    static func hexFromNSColor(_ color: NSColor) -> String {
        guard let c = color.usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(c.redComponent * 255)
        let g = Int(c.greenComponent * 255)
        let b = Int(c.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Built-in Themes

extension TerminalTheme {
    static let dracula = TerminalTheme(
        id: "dracula", name: "Dracula",
        ansiColors: [
            "#21222C", "#FF5555", "#50FA7B", "#F1FA8C",
            "#BD93F9", "#FF79C6", "#8BE9FD", "#F8F8F2",
            "#6272A4", "#FF6E6E", "#69FF94", "#FFFFA5",
            "#D6ACFF", "#FF92DF", "#A4FFFF", "#FFFFFF"
        ],
        foreground: "#F8F8F2", background: "#282A36",
        cursorColor: "#F8F8F2", selectionColor: "#44475A"
    )

    static let solarizedDark = TerminalTheme(
        id: "solarized-dark", name: "Solarized Dark",
        ansiColors: [
            "#073642", "#DC322F", "#859900", "#B58900",
            "#268BD2", "#D33682", "#2AA198", "#EEE8D5",
            "#002B36", "#CB4B16", "#586E75", "#657B83",
            "#839496", "#6C71C4", "#93A1A1", "#FDF6E3"
        ],
        foreground: "#839496", background: "#002B36",
        cursorColor: "#839496", selectionColor: "#073642"
    )

    static let nord = TerminalTheme(
        id: "nord", name: "Nord",
        ansiColors: [
            "#3B4252", "#BF616A", "#A3BE8C", "#EBCB8B",
            "#81A1C1", "#B48EAD", "#88C0D0", "#E5E9F0",
            "#4C566A", "#BF616A", "#A3BE8C", "#EBCB8B",
            "#81A1C1", "#B48EAD", "#8FBCBB", "#ECEFF4"
        ],
        foreground: "#D8DEE9", background: "#2E3440",
        cursorColor: "#D8DEE9", selectionColor: "#4C566A"
    )

    static let defaultDark = TerminalTheme(
        id: "default-dark", name: "Default Dark",
        ansiColors: [
            "#000000", "#BB0000", "#00BB00", "#BBBB00",
            "#0000BB", "#BB00BB", "#00BBBB", "#BBBBBB",
            "#555555", "#FF5555", "#55FF55", "#FFFF55",
            "#5555FF", "#FF55FF", "#55FFFF", "#FFFFFF"
        ],
        foreground: "#FFFFFF", background: "#000000",
        cursorColor: "#FFFFFF", selectionColor: "#4D4D4D"
    )

    static let allBuiltIn: [TerminalTheme] = [
        .defaultDark, .dracula, .solarizedDark, .nord
    ]
}

// MARK: - Theme Parsers

enum TerminalThemeParser {

    enum Format {
        case ghostty, iterm2, alacritty
    }

    static func detect(from url: URL) -> Format? {
        let ext = url.pathExtension.lowercased()
        if ext == "itermcolors" { return .iterm2 }
        if ext == "toml" { return .alacritty }
        // Try reading content to detect ghostty format
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            if content.contains("palette") && content.contains("=") {
                return .ghostty
            }
            if content.contains("foreground") && content.contains("=") && !content.contains("[") {
                return .ghostty
            }
        }
        return nil
    }

    static func parse(from url: URL) -> TerminalTheme? {
        guard let format = detect(from: url) else { return nil }
        switch format {
        case .ghostty: return parseGhostty(from: url)
        case .iterm2: return parseITerm2(from: url)
        case .alacritty: return parseAlacritty(from: url)
        }
    }

    // MARK: Ghostty

    static func parseGhostty(from url: URL) -> TerminalTheme? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var ansi = [String](repeating: "#000000", count: 16)
        var fg = "#FFFFFF"
        var bg = "#000000"
        var cursor: String?

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2 else { continue }

            let key = parts[0]
            let value = parts[1]

            if key == "foreground" || key == "background" || key == "cursor-color" {
                let hex = normalizeHex(value)
                if key == "foreground" { fg = hex }
                else if key == "background" { bg = hex }
                else { cursor = hex }
            } else if key == "palette" {
                // format: palette = N=#RRGGBB
                let paletteParts = value.split(separator: "=", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                if paletteParts.count == 2, let idx = Int(paletteParts[0]), idx >= 0, idx < 16 {
                    ansi[idx] = normalizeHex(paletteParts[1])
                }
            }
        }

        let name = url.deletingPathExtension().lastPathComponent
        return TerminalTheme(
            id: "import-\(name)", name: name,
            ansiColors: ansi, foreground: fg, background: bg,
            cursorColor: cursor
        )
    }

    // MARK: iTerm2

    static func parseITerm2(from url: URL) -> TerminalTheme? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        func colorFromDict(_ dict: [String: Any]) -> String {
            let r = (dict["Red Component"] as? Double) ?? 0
            let g = (dict["Green Component"] as? Double) ?? 0
            let b = (dict["Blue Component"] as? Double) ?? 0
            return String(format: "#%02X%02X%02X",
                          Int(r * 255), Int(g * 255), Int(b * 255))
        }

        var ansi = [String](repeating: "#000000", count: 16)
        for i in 0..<16 {
            let key = "Ansi \(i) Color"
            if let dict = plist[key] as? [String: Any] {
                ansi[i] = colorFromDict(dict)
            }
        }

        let fg = (plist["Foreground Color"] as? [String: Any]).map(colorFromDict) ?? "#FFFFFF"
        let bg = (plist["Background Color"] as? [String: Any]).map(colorFromDict) ?? "#000000"
        let cursor = (plist["Cursor Color"] as? [String: Any]).map(colorFromDict)
        let selection = (plist["Selection Color"] as? [String: Any]).map(colorFromDict)

        let name = url.deletingPathExtension().lastPathComponent
        return TerminalTheme(
            id: "import-\(name)", name: name,
            ansiColors: ansi, foreground: fg, background: bg,
            cursorColor: cursor, selectionColor: selection
        )
    }

    // MARK: Alacritty

    static func parseAlacritty(from url: URL) -> TerminalTheme? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var fg = "#FFFFFF"
        var bg = "#000000"
        var cursor: String?
        var normalColors = [String](repeating: "#000000", count: 8)
        var brightColors = [String](repeating: "#555555", count: 8)

        let colorNames = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]

        enum Section { case none, primary, normal, bright, cursor }
        var section: Section = .none

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if trimmed.hasPrefix("[") {
                let header = trimmed
                    .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    .trimmingCharacters(in: .whitespaces)
                switch header {
                case "colors.primary": section = .primary
                case "colors.normal": section = .normal
                case "colors.bright": section = .bright
                case "colors.cursor": section = .cursor
                default:
                    if header.hasPrefix("colors.") { section = .none }
                    else if !header.hasPrefix("colors") { section = .none }
                }
                continue
            }

            let parts = trimmed.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
            guard parts.count == 2 else { continue }

            let key = parts[0]
            let hex = normalizeHex(parts[1])

            switch section {
            case .primary:
                if key == "foreground" { fg = hex }
                else if key == "background" { bg = hex }
            case .normal:
                if let idx = colorNames.firstIndex(of: key) { normalColors[idx] = hex }
            case .bright:
                if let idx = colorNames.firstIndex(of: key) { brightColors[idx] = hex }
            case .cursor:
                if key == "cursor" { cursor = hex }
            case .none:
                break
            }
        }

        let ansi = normalColors + brightColors
        let name = url.deletingPathExtension().lastPathComponent
        return TerminalTheme(
            id: "import-\(name)", name: name,
            ansiColors: ansi, foreground: fg, background: bg,
            cursorColor: cursor
        )
    }

    // MARK: Helpers

    private static func normalizeHex(_ value: String) -> String {
        var hex = value.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        if !hex.hasPrefix("#") { hex = "#" + hex }
        // Handle 0x prefix
        if hex.hasPrefix("#0x") || hex.hasPrefix("#0X") {
            hex = "#" + String(hex.dropFirst(3))
        }
        return hex.uppercased()
    }
}

// MARK: - ThemeManager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: TerminalTheme {
        didSet { saveState() }
    }
    @Published var customThemes: [TerminalTheme] = [] {
        didSet { saveState() }
    }
    @Published var fontFamily: String {
        didSet { saveState() }
    }
    @Published var fontSize: Double {
        didSet { saveState() }
    }

    var allThemes: [TerminalTheme] {
        TerminalTheme.allBuiltIn + customThemes
    }

    private init() {
        let defaults = UserDefaults.standard

        // Load font settings
        let loadedFamily = defaults.string(forKey: "theme.fontFamily") ?? ""
        var loadedSize = defaults.double(forKey: "theme.fontSize")
        if loadedSize < 8 { loadedSize = 13 }

        // Load custom themes
        var loadedCustom: [TerminalTheme] = []
        if let data = defaults.data(forKey: "theme.customThemes"),
           let themes = try? JSONDecoder().decode([TerminalTheme].self, from: data) {
            loadedCustom = themes
        }

        // Load current theme
        let themeId = defaults.string(forKey: "theme.currentId") ?? "default-dark"
        let all = TerminalTheme.allBuiltIn + loadedCustom
        let loadedTheme = all.first(where: { $0.id == themeId }) ?? .defaultDark

        // Initialize all stored properties
        self.fontFamily = loadedFamily
        self.fontSize = loadedSize
        self.customThemes = loadedCustom
        self.currentTheme = loadedTheme
    }

    private func saveState() {
        let defaults = UserDefaults.standard
        defaults.set(currentTheme.id, forKey: "theme.currentId")
        defaults.set(fontFamily, forKey: "theme.fontFamily")
        defaults.set(fontSize, forKey: "theme.fontSize")
        if let data = try? JSONEncoder().encode(customThemes) {
            defaults.set(data, forKey: "theme.customThemes")
        }
    }

    func apply(to terminalView: LocalProcessTerminalView) {
        let theme = currentTheme

        // Build color array for installColors
        var colors: [Color] = []
        for i in 0..<16 {
            if i < theme.ansiColors.count {
                colors.append(TerminalTheme.swiftTermColor(from: theme.ansiColors[i]))
            } else {
                colors.append(Color(red: 0, green: 0, blue: 0))
            }
        }
        terminalView.installColors(colors)

        terminalView.nativeForegroundColor = TerminalTheme.nsColor(from: theme.foreground)
        terminalView.nativeBackgroundColor = TerminalTheme.nsColor(from: theme.background)

        if let cursorHex = theme.cursorColor {
            terminalView.caretColor = TerminalTheme.nsColor(from: cursorHex)
        }
        if let selHex = theme.selectionColor {
            terminalView.selectedTextBackgroundColor = TerminalTheme.nsColor(from: selHex)
        }

        // Apply font
        let resolvedFont: NSFont
        if !fontFamily.isEmpty, let font = NSFont(name: fontFamily, size: fontSize) {
            resolvedFont = font
        } else {
            resolvedFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
        terminalView.font = resolvedFont

        terminalView.needsDisplay = true
    }

    func importTheme() {
        let panel = NSOpenPanel()
        panel.title = "Import Theme File"
        panel.allowedContentTypes = [.data]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        if let theme = TerminalThemeParser.parse(from: url) {
            // Avoid duplicates
            customThemes.removeAll { $0.id == theme.id }
            customThemes.append(theme)
            currentTheme = theme
        }
    }

    func autoDetectThemes() -> [TerminalTheme] {
        var found: [TerminalTheme] = []
        let home = FileManager.default.homeDirectoryForCurrentUser

        // Ghostty
        let ghosttyConfig = home.appendingPathComponent(".config/ghostty/config")
        if let theme = TerminalThemeParser.parseGhostty(from: ghosttyConfig) {
            var t = theme
            t.id = "auto-ghostty"
            t.name = "Ghostty Config"
            found.append(t)
        }

        // Alacritty
        let alacrittyConfig = home.appendingPathComponent(".config/alacritty/alacritty.toml")
        if let theme = TerminalThemeParser.parseAlacritty(from: alacrittyConfig) {
            var t = theme
            t.id = "auto-alacritty"
            t.name = "Alacritty Config"
            found.append(t)
        }

        return found
    }
}
