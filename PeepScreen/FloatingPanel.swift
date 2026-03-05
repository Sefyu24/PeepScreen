//
//  FloatingPanel.swift
//  PeepScreen
//

import AppKit
import SwiftUI
import SwiftTerm

class FloatingPanel: NSPanel, PanelStateDelegate {

    private let dragBarHeight: CGFloat = 24
    private let miniWidth: CGFloat = 200
    private let miniHeight: CGFloat = 44
    private let tuckedThickness: CGFloat = 8
    private let tuckedLength: CGFloat = 200
    private let edgeSnapThreshold: CGFloat = 30

    private var terminalView: NSView!
    private var dragBarHostView: NSHostingView<DragBarView>!
    private var tuckedTabHostView: NSHostingView<TuckedTabView>?
    private var previewWindow: NSWindow?
    var stateManager: PanelStateManager!
    var lastExpandedFrame: NSRect = .zero

    private var currentScreen: NSScreen {
        self.screen ?? NSScreen.main ?? NSScreen.screens[0]
    }

    init(contentRect: NSRect, terminalView: LocalProcessTerminalView, stateManager: PanelStateManager) {
        self.stateManager = stateManager
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.terminalView = terminalView
        stateManager.delegate = self

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        let effectView = NSVisualEffectView(frame: contentRect)
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 12
        effectView.layer?.masksToBounds = true

        dragBarHostView = NSHostingView(rootView: DragBarView(isMini: false, lastLine: ""))
        dragBarHostView.translatesAutoresizingMaskIntoConstraints = false

        terminalView.translatesAutoresizingMaskIntoConstraints = false

        effectView.addSubview(dragBarHostView)
        effectView.addSubview(terminalView)

        NSLayoutConstraint.activate([
            dragBarHostView.topAnchor.constraint(equalTo: effectView.topAnchor),
            dragBarHostView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            dragBarHostView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            dragBarHostView.heightAnchor.constraint(equalToConstant: dragBarHeight),

            terminalView.topAnchor.constraint(equalTo: dragBarHostView.bottomAnchor),
            terminalView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            terminalView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
        ])

        contentView = effectView
        invalidateShadow()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        let locationInWindow = event.locationInWindow
        let contentHeight = contentView?.frame.height ?? 0

        switch stateManager.currentState {
        case .tucked:
            if event.clickCount == 2 {
                stateManager.untuck()
            } else {
                startTuckedDrag(with: event)
            }
            return

        case .mini:
            if event.clickCount == 2 {
                stateManager.toggleMini()
                return
            }
            startCustomDrag(with: event)
            return

        case .expanded:
            if locationInWindow.y >= contentHeight - dragBarHeight && event.clickCount == 2 {
                stateManager.toggleMini()
                return
            }
            if locationInWindow.y >= contentHeight - dragBarHeight {
                startCustomDrag(with: event)
            } else {
                super.mouseDown(with: event)
            }
        }
    }

    // MARK: - Custom drag with edge preview

    private func startCustomDrag(with event: NSEvent) {
        let startMouseLocation = NSEvent.mouseLocation
        let startOrigin = frame.origin
        let offsetX = startMouseLocation.x - startOrigin.x
        let offsetY = startMouseLocation.y - startOrigin.y

        trackDrag { currentMouse in
            let newOrigin = NSPoint(
                x: currentMouse.x - offsetX,
                y: currentMouse.y - offsetY
            )
            self.setFrameOrigin(newOrigin)

            if let edge = self.detectNearEdge() {
                self.showEdgePreview(for: edge)
            } else {
                self.hideEdgePreview()
            }
        } onRelease: {
            if let edge = self.detectNearEdge() {
                self.hideEdgePreview()
                self.stateManager.tuck(edge: edge)
            } else {
                self.hideEdgePreview()
            }
        }
    }

    // MARK: - Tucked drag (constrained to edge)

    private func startTuckedDrag(with event: NSEvent) {
        guard case .tucked(let edge) = stateManager.currentState else { return }

        let startMouseLocation = NSEvent.mouseLocation
        let startOrigin = frame.origin
        var maxDisplacement: CGFloat = 0

        trackDrag { currentMouse in
            let deltaX = currentMouse.x - startMouseLocation.x
            let deltaY = currentMouse.y - startMouseLocation.y

            let displacement = abs(edge.isVertical ? deltaY : deltaX)
            maxDisplacement = max(maxDisplacement, displacement)

            var newOrigin = startOrigin
            if edge.isVertical {
                newOrigin.y = startOrigin.y + deltaY
            } else {
                newOrigin.x = startOrigin.x + deltaX
            }

            let sf = self.currentScreen.visibleFrame
            newOrigin.x = max(sf.minX, min(newOrigin.x, sf.maxX - self.frame.width))
            newOrigin.y = max(sf.minY, min(newOrigin.y, sf.maxY - self.frame.height))

            self.setFrameOrigin(newOrigin)
        } onRelease: {
            if maxDisplacement < 4 {
                self.stateManager.untuck()
            }
        }
    }

    // MARK: - Shared drag loop

    private func trackDrag(onMove: @escaping (NSPoint) -> Void, onRelease: @escaping () -> Void) {
        var isDragging = true
        while isDragging {
            guard let event = nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { continue }
            switch event.type {
            case .leftMouseDragged:
                onMove(NSEvent.mouseLocation)
            case .leftMouseUp:
                isDragging = false
                onRelease()
            default:
                break
            }
        }
    }

    // MARK: - Edge detection

    private func detectNearEdge() -> TuckEdge? {
        let sf = currentScreen.visibleFrame

        let distLeft = frame.minX - sf.minX
        let distRight = sf.maxX - frame.maxX
        let distTop = sf.maxY - frame.maxY
        let distBottom = frame.minY - sf.minY

        let minDist = min(distLeft, distRight, distTop, distBottom)
        guard minDist <= edgeSnapThreshold else { return nil }

        if minDist == distLeft { return .left }
        if minDist == distRight { return .right }
        if minDist == distTop { return .top }
        return .bottom
    }

    // MARK: - Edge preview

    private func showEdgePreview(for edge: TuckEdge) {
        let previewFrame = tuckedFrame(for: edge)

        if let preview = previewWindow {
            preview.setFrame(previewFrame, display: true)
        } else {
            let preview = NSWindow(
                contentRect: previewFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            preview.level = .floating
            preview.isOpaque = false
            preview.backgroundColor = NSColor.white.withAlphaComponent(0.15)
            preview.hasShadow = false
            preview.ignoresMouseEvents = true
            preview.contentView?.wantsLayer = true
            preview.contentView?.layer?.cornerRadius = 4

            preview.orderFront(nil)
            previewWindow = preview
        }
    }

    private func hideEdgePreview() {
        previewWindow?.orderOut(nil)
        previewWindow = nil
    }

    private func tuckedFrame(for edge: TuckEdge) -> NSRect {
        let sf = currentScreen.visibleFrame

        switch edge {
        case .left:
            return NSRect(x: sf.minX, y: frame.midY - tuckedLength / 2,
                          width: tuckedThickness, height: tuckedLength)
        case .right:
            return NSRect(x: sf.maxX - tuckedThickness, y: frame.midY - tuckedLength / 2,
                          width: tuckedThickness, height: tuckedLength)
        case .top:
            return NSRect(x: frame.midX - tuckedLength / 2, y: sf.maxY - tuckedThickness,
                          width: tuckedLength, height: tuckedThickness)
        case .bottom:
            return NSRect(x: frame.midX - tuckedLength / 2, y: sf.minY,
                          width: tuckedLength, height: tuckedThickness)
        }
    }

    // MARK: - PanelStateDelegate

    func panelStateDidChange(to state: PanelState) {
        switch state {
        case .expanded:
            transitionToExpanded()
        case .mini:
            transitionToMini()
        case .tucked(let edge):
            transitionToTucked(edge: edge)
        }
    }

    // MARK: - Transitions

    private func animateFrame(to target: NSRect, duration: TimeInterval = 0.25,
                              cornerRadius: CGFloat, completion: (() -> Void)? = nil) {
        (contentView as? NSVisualEffectView)?.layer?.cornerRadius = cornerRadius
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            self?.invalidateShadow()
            completion?()
        })
    }

    private func removeTuckedTab() {
        tuckedTabHostView?.removeFromSuperview()
        tuckedTabHostView = nil
    }

    private func saveExpandedFrameIfNeeded() {
        if frame.width > miniWidth {
            lastExpandedFrame = frame
        }
    }

    private func transitionToExpanded() {
        removeTuckedTab()

        dragBarHostView.isHidden = false
        terminalView.isHidden = false
        dragBarHostView.rootView = DragBarView(isMini: false, lastLine: "")

        animateFrame(to: lastExpandedFrame, cornerRadius: 12) { [weak self] in
            guard let self else { return }
            if let tv = self.terminalView as? LocalProcessTerminalView {
                self.makeFirstResponder(tv)
            }
        }
    }

    private func transitionToMini() {
        saveExpandedFrameIfNeeded()

        terminalView.isHidden = true
        dragBarHostView.rootView = DragBarView(isMini: true, lastLine: stateManager.lastLineText)
        dragBarHostView.isHidden = false
        removeTuckedTab()

        let miniFrame = NSRect(
            x: frame.midX - miniWidth / 2,
            y: frame.maxY - miniHeight,
            width: miniWidth,
            height: miniHeight
        )

        animateFrame(to: miniFrame, cornerRadius: miniHeight / 2)
    }

    private func transitionToTucked(edge: TuckEdge) {
        saveExpandedFrameIfNeeded()

        terminalView.isHidden = true
        dragBarHostView.isHidden = true

        let targetFrame = tuckedFrame(for: edge)

        animateFrame(to: targetFrame, duration: 0.2, cornerRadius: 4) { [weak self] in
            self?.addTuckedTabView(edge: edge)
        }
    }

    private func addTuckedTabView(edge: TuckEdge) {
        removeTuckedTab()
        guard let effectView = contentView else { return }
        let tabView = NSHostingView(rootView: TuckedTabView(isVertical: edge.isVertical))
        tabView.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: effectView.topAnchor),
            tabView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            tabView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
        ])
        tuckedTabHostView = tabView
    }

    func updateMiniContent() {
        guard stateManager.currentState == .mini else { return }
        let newLine = stateManager.lastLineText
        guard dragBarHostView.rootView.lastLine != newLine else { return }
        dragBarHostView.rootView = DragBarView(isMini: true, lastLine: newLine)
    }
}
