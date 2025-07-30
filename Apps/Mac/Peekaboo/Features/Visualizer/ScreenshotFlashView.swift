//
//  ScreenshotFlashView.swift
//  Peekaboo
//
//  Created by Peekaboo on 2025-01-30.
//

import SwiftUI

/// A view that displays a camera flash animation for screenshot capture
struct ScreenshotFlashView: View {
    
    // MARK: - Properties
    
    /// Whether to show the ghost easter egg
    let showGhost: Bool
    
    /// Effect intensity (0.0 to 1.0)
    let intensity: Double
    
    /// Animation state
    @State private var flashOpacity: Double = 0
    @State private var ghostScale: Double = 0
    @State private var ghostOpacity: Double = 0
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Flash overlay
            Color.white
                .opacity(flashOpacity * intensity * 0.2) // Max 20% opacity
                .ignoresSafeArea()
            
            // Ghost easter egg (every 100th screenshot)
            if showGhost {
                VStack {
                    Text("👻")
                        .font(.system(size: 50))
                        .scaleEffect(ghostScale)
                        .opacity(ghostOpacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            startFlashAnimation()
        }
    }
    
    // MARK: - Methods
    
    private func startFlashAnimation() {
        // Flash animation
        withAnimation(.easeOut(duration: 0.1)) {
            flashOpacity = 1.0
        }
        
        // Fade out after flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.1)) {
                flashOpacity = 0
            }
        }
        
        // Ghost animation (if enabled)
        if showGhost {
            // Delay ghost appearance slightly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    ghostScale = 1.0
                    ghostOpacity = 0.8
                }
                
                // Fade out ghost
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        ghostScale = 1.2
                        ghostOpacity = 0
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Normal Flash") {
    ScreenshotFlashView(showGhost: false, intensity: 1.0)
        .frame(width: 400, height: 300)
}

#Preview("With Ghost") {
    ScreenshotFlashView(showGhost: true, intensity: 1.0)
        .frame(width: 400, height: 300)
}

#Preview("Half Intensity") {
    ScreenshotFlashView(showGhost: false, intensity: 0.5)
        .frame(width: 400, height: 300)
}
#endif