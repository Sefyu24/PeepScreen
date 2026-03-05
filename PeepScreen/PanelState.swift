//
//  PanelState.swift
//  PeepScreen
//

import AppKit

enum PanelState: Equatable {
    case expanded
    case mini
    case tucked(edge: TuckEdge)
}

enum TuckEdge: Equatable {
    case left, right, top, bottom

    var isVertical: Bool {
        self == .left || self == .right
    }
}

protocol PanelStateDelegate: AnyObject {
    func panelStateDidChange(to state: PanelState)
}

class PanelStateManager {

    private(set) var currentState: PanelState = .expanded
    var lastLineText: String = ""

    weak var delegate: PanelStateDelegate?

    func toggleMini() {
        switch currentState {
        case .expanded:
            transition(to: .mini)
        case .mini:
            transition(to: .expanded)
        case .tucked:
            break
        }
    }

    func tuck(edge: TuckEdge) {
        transition(to: .tucked(edge: edge))
    }

    func untuck() {
        transition(to: .expanded)
    }

    private func transition(to newState: PanelState) {
        currentState = newState
        delegate?.panelStateDidChange(to: newState)
    }
}
