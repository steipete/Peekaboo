//
//  ScrollAnimationView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import PeekabooCore
import SwiftUI

/// A view that displays scroll direction indicators with motion blur
struct ScrollAnimationView: View {
    // MARK: - Properties

    /// Scroll direction
    let direction: ScrollDirection

    /// Number of scroll units
    let amount: Int

    /// Animation states
    @State private var arrowOffset: CGFloat = 0
    @State private var arrowOpacity: Double = 0
    @State private var blurRadius: CGFloat = 0
    @State private var amountLabelOpacity: Double = 0

    /// Arrow rotation based on direction
    private var arrowRotation: Angle {
        switch self.direction {
        case .up:
            .degrees(0)
        case .down:
            .degrees(180)
        case .left:
            .degrees(-90)
        case .right:
            .degrees(90)
        }
    }

    /// Motion offset based on direction
    private var motionOffset: CGSize {
        switch self.direction {
        case .up:
            CGSize(width: 0, height: -30)
        case .down:
            CGSize(width: 0, height: 30)
        case .left:
            CGSize(width: -30, height: 0)
        case .right:
            CGSize(width: 30, height: 0)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Multiple arrows for motion effect
            ForEach(0..<3) { index in
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue.opacity(0.8 - Double(index) * 0.2))
                    .rotationEffect(self.arrowRotation)
                    .offset(
                        x: self.motionOffset.width * CGFloat(index) * 0.3,
                        y: self.motionOffset.height * CGFloat(index) * 0.3 + self.arrowOffset)
                    .blur(radius: self.blurRadius * CGFloat(index))
                    .opacity(self.arrowOpacity)
            }

            // Scroll amount indicator
            VStack {
                Spacer()
                Text("\(self.amount) \(self.amount == 1 ? "line" : "lines")")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.7)))
                    .opacity(self.amountLabelOpacity)
            }
            .offset(y: 10)
        }
        .frame(width: 100, height: 100)
        .onAppear {
            self.startAnimation()
        }
    }

    // MARK: - Methods

    private func startAnimation() {
        // Fade in arrows with motion
        withAnimation(.easeOut(duration: 0.3)) {
            self.arrowOpacity = 1.0
            self.arrowOffset = self.direction == .up || self.direction == .down ? 10 : 0
            self.blurRadius = 2
        }

        // Show amount label
        withAnimation(.easeIn(duration: 0.2).delay(0.1)) {
            self.amountLabelOpacity = 1.0
        }

        // Continue motion animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.4)) {
                switch self.direction {
                case .up:
                    self.arrowOffset = -20
                case .down:
                    self.arrowOffset = 30
                case .left, .right:
                    self.arrowOffset = 0
                }
                self.blurRadius = 5
            }
        }

        // Fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.2)) {
                self.arrowOpacity = 0
                self.amountLabelOpacity = 0
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Scroll Up") {
    ScrollAnimationView(direction: .up, amount: 3)
        .frame(width: 150, height: 150)
        .background(Color.gray.opacity(0.1))
}

#Preview("Scroll Down") {
    ScrollAnimationView(direction: .down, amount: 5)
        .frame(width: 150, height: 150)
        .background(Color.gray.opacity(0.1))
}

#Preview("Scroll Left") {
    ScrollAnimationView(direction: .left, amount: 10)
        .frame(width: 150, height: 150)
        .background(Color.gray.opacity(0.1))
}

#Preview("Scroll Right") {
    ScrollAnimationView(direction: .right, amount: 1)
        .frame(width: 150, height: 150)
        .background(Color.gray.opacity(0.1))
}
#endif
