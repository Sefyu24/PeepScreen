//
//  PanelContentView.swift
//  PeepScreen
//

import SwiftUI

struct DragBarView: View {
    var isMini: Bool
    var lastLine: String

    var body: some View {
        if isMini {
            miniBody
        } else {
            expandedBody
        }
    }

    private var expandedBody: some View {
        HStack(spacing: 6) {
            Text("AgentPiP")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
    }

    private var miniBody: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
            Text(lastLine.isEmpty ? "PeepScreen" : lastLine)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TuckedTabView: View {
    var isVertical: Bool

    var body: some View {
        ZStack {
            // Soft green glow background
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.green.opacity(0.5),
                            Color.green.opacity(0.2),
                            Color.green.opacity(0.05)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )

            // Brighter center glow
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.15))
                .blur(radius: 8)
                .padding(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
