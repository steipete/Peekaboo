//
//  WatchCaptureHUDView.swift
//  Peekaboo
//

import SwiftUI

struct WatchCaptureHUDView: View {
    enum Constants {
        static let timelineSegments = 5
    }

    let sequence: Int
    @State private var pulse = false

    private var activeSegment: Int { self.sequence % Constants.timelineSegments }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.35))
                .background(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.pink.opacity(0.5), .purple.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing),
                            lineWidth: 1.5))

            HStack(spacing: 16) {
                Circle()
                    .fill(Color.pink.opacity(0.7))
                    .frame(width: 18, height: 18)
                    .scaleEffect(self.pulse ? 1.25 : 0.85)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: self.pulse)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Change-aware capture running")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Timeline lights up whenever frames are kept")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.8))

                    WatchTimelineView(activeIndex: self.activeSegment, totalSegments: Constants.timelineSegments)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("watch")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 340, height: 70)
        .onAppear {
            self.pulse = true
        }
    }
}

#Preview("Watch HUD") {
    WatchCaptureHUDView(sequence: 0)
        .padding()
        .background(Color.black.opacity(0.6))
}

private struct WatchTimelineView: View {
    let activeIndex: Int
    let totalSegments: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<self.totalSegments, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(self.segmentColor(for: index))
                    .frame(width: 36, height: 6)
                    .animation(.easeInOut(duration: 0.3), value: self.activeIndex)
            }
        }
    }

    private func segmentColor(for index: Int) -> Color {
        if index == self.activeIndex {
            return Color.pink
        }
        if index == (self.activeIndex - 1 + self.totalSegments) % self.totalSegments {
            return Color.pink.opacity(0.4)
        }
        return Color.white.opacity(0.25)
    }
}
