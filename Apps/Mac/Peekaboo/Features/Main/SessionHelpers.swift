import Foundation
import SwiftUI

// MARK: - Helper Functions

func formatModelName(_ model: String) -> String {
    // Shorten common model names for display
    switch model {
    case "gpt-4.1": "GPT-4.1"
    case "gpt-4.1-mini": "GPT-4.1 mini"
    case "gpt-4o": "GPT-4o"
    case "gpt-4o-mini": "GPT-4o mini"
    case "o3": "o3"
    case "o3-pro": "o3 pro"
    case "o4-mini": "o4-mini"
    case "claude-opus-4-20250514": "Claude Opus 4"
    case "claude-sonnet-4-20250514": "Claude Sonnet 4"
    case "claude-3-5-haiku": "Claude 3.5 Haiku"
    case "claude-3-5-sonnet": "Claude 3.5 Sonnet"
    case "llava:latest": "LLaVA"
    case "llama3.2-vision:latest": "Llama 3.2"
    default: model
    }
}

// MARK: - Time Formatting Components

struct SessionDurationText: View {
    let startTime: Date
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(self.formatDuration(self.currentTime.timeIntervalSince(self.startTime)))
            .onReceive(self.timer) { _ in
                self.currentTime = Date()
            }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            let minutes = Int(interval) / 60
            let seconds = Int(interval) % 60
            return "\(minutes)m \(seconds)s"
        } else {
            let hours = Int(interval) / 3600
            let minutes = (Int(interval) % 3600) / 60
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        }
    }
}

struct TimeIntervalText: View {
    let startTime: Date
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formatTimeInterval(currentTime.timeIntervalSince(startTime)))
            .onReceive(timer) { _ in
                currentTime = Date()
            }
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes):\(String(format: "%02d", remainingSeconds))"
        }
    }
}

// MARK: - Data Extraction Utilities

extension String {
    func extractImageData() -> Data? {
        // Try to extract base64 image data from result
        if let data = self.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let screenshotData = json["screenshot_data"] as? String,
           let imageData = Data(base64Encoded: screenshotData)
        {
            return imageData
        }
        return nil
    }
    
    func formatJSON() -> String {
        guard let data = self.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let formattedData = try? JSONSerialization.data(
                  withJSONObject: jsonObject,
                  options: [.prettyPrinted, .sortedKeys]),
              let formattedString = String(data: formattedData, encoding: .utf8)
        else {
            return self
        }
        return formattedString
    }
}

// MARK: - Visual Effect View

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = self.material
        view.blendingMode = self.blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = self.material
        nsView.blendingMode = self.blendingMode
    }
}