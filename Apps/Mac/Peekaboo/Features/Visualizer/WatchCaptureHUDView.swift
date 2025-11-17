//
//  WatchCaptureHUDView.swift
//  Peekaboo
//

import SwiftUI

struct WatchCaptureHUDView: View {
    @State private var pulse = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .leading, endPoint: .trailing), lineWidth: 2)
                )

            HStack(spacing: 16) {
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 18, height: 18)
                    .scaleEffect(self.pulse ? 1.3 : 0.8)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: self.pulse)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Watch capture running")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Text("Saving frames only when something changes")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                ProgressView()
                    .progressViewStyle(.circular)
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
    WatchCaptureHUDView()
        .padding()
        .background(Color.black.opacity(0.6))
}
