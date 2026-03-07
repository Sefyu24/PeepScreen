//
//  DroppableTerminalView.swift
//  PeepScreen
//

import AppKit
import SwiftTerm

class DroppableTerminalView: LocalProcessTerminalView {

    /// Called when terminal content changes (for mini mode updates)
    var onRangeChanged: ((_ startY: Int, _ endY: Int) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        super.rangeChanged(source: source, startY: startY, endY: endY)
        onRangeChanged?(startY, endY)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard fileURL(from: sender) != nil else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = fileURL(from: sender) else { return false }

        let escaped = url.path.replacingOccurrences(of: " ", with: "\\ ")

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        if isDir.boolValue {
            // Directory: cd into it
            sendText("cd \(escaped)\n")
        } else {
            // File: paste the path (no newline, so user can decide what to do)
            sendText(escaped)
        }
        return true
    }

    private func fileURL(from info: NSDraggingInfo) -> URL? {
        guard let items = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else { return nil }
        return items.first
    }

    private func sendText(_ text: String) {
        let data = Array(text.utf8)
        self.send(data)
    }
}
