import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PeekabooFoundation
import UniformTypeIdentifiers

/// Adaptive PNG capture session for agents.
@MainActor
public final class WatchCaptureSession {
    private enum Constants {
        static let diffScaleWidth: CGFloat = 256
        static let motionDelta: UInt8 = 18 // luma delta threshold (0-255)
        static let contactMaxColumns = 6
        static let contactThumb: CGFloat = 200
    }

    private let screenCapture: any ScreenCaptureServiceProtocol
    private let scope: WatchScope
    private let options: WatchCaptureOptions
    private let outputRoot: URL
    private let autocleanMinutes: Int
    private let managedAutoclean: Bool
    private let fileManager = FileManager.default
    private let screenService: (any ScreenServiceProtocol)?
    private let sessionId = UUID().uuidString

    private var frames: [WatchFrameInfo] = []
    private var motionIntervals: [WatchMotionInterval] = []
    private var warnings: [WatchWarning] = []
    private var framesDropped: Int = 0
    private var totalBytes: Int = 0
    private var activeIntervalStart: (index: Int, startMs: Int, maxChange: Double)?

    public init(
        screenCapture: any ScreenCaptureServiceProtocol,
        screenService: (any ScreenServiceProtocol)?,
        scope: WatchScope,
        options: WatchCaptureOptions,
        outputRoot: URL,
        autocleanMinutes: Int,
        managedAutoclean: Bool)
    {
        self.screenCapture = screenCapture
        self.screenService = screenService
        self.scope = scope
        self.options = options
        self.outputRoot = outputRoot
        self.autocleanMinutes = autocleanMinutes
        self.managedAutoclean = managedAutoclean
    }

    public func run() async throws -> WatchCaptureResult {
        try self.prepareOutputRoot()
        self.performAutoclean()

        let diffStrategy = self.options.diffStrategy
        let start = Date()
        let durationNs = UInt64(self.options.duration * 1_000_000_000)
        let heartbeatNs = self.options.heartbeatSeconds > 0
            ? UInt64(self.options.heartbeatSeconds * 1_000_000_000)
            : UInt64.max
        let quietNs = UInt64(self.options.quietMsToIdle) * 1_000_000

        var lastKeptTime = start
        var lastActivityTime = start
        var activeMode = false
        var lastDiffBuffer: LumaBuffer?
        let cadenceIdleNs = UInt64(1_000_000_000 / max(self.options.idleFps, 0.1))
        let cadenceActiveNs = UInt64(1_000_000_000 / max(self.options.activeFps, 0.1))

        var frameIndex = 0
        while true {
            let now = Date()
            let elapsedNs = UInt64(now.timeIntervalSince(start) * 1_000_000_000)
            if elapsedNs >= durationNs { break }
            if self.frames.count >= self.options.maxFrames {
                self.warnings.append(
                    WatchWarning(code: .frameCap, message: "Stopped after reaching max-frames cap"))
                break
            }
            if let maxMb = self.options.maxMegabytes,
               self.totalBytes / (1024 * 1024) >= maxMb {
                self.warnings.append(
                    WatchWarning(code: .sizeCap, message: "Stopped after reaching max-mb cap"))
                break
            }

            let frameStart = Date()
            let capture = try await self.captureFrame()
            guard let cgImage = capture.cgImage else {
                self.framesDropped += 1
                try await self.sleep(ns: activeMode ? cadenceActiveNs : cadenceIdleNs, since: frameStart)
                continue
            }

            let downscaled = self.makeLumaBuffer(from: cgImage)
            let diff = WatchCaptureSession.computeChange(
                strategy: self.options.diffStrategy,
                diffBudgetMs: self.options.diffBudgetMs,
                previous: lastDiffBuffer,
                current: downscaled,
                deltaThreshold: Constants.motionDelta,
                originalSize: CGSize(width: cgImage.width, height: cgImage.height))
            let changePercent = diff.changePercent
            let motionBoxes = diff.boundingBoxes
            lastDiffBuffer = downscaled
            if diff.downgraded {
                self.warnings.append(
                    WatchWarning(code: .diffDowngraded, message: "Diff downgraded to fast due to budget"))
            }

            let threshold = self.options.changeThresholdPercent
            let enterActive = changePercent >= threshold
            let exitActive = activeMode && (changePercent < threshold / 2) &&
                UInt64(Date().timeIntervalSince(lastActivityTime) * 1_000_000_000) >= quietNs

            if enterActive {
                lastActivityTime = now
            }

            if enterActive && !activeMode {
                activeMode = true
                activeIntervalStart = (index: frameIndex, startMs: Int(elapsedNs / 1_000_000), maxChange: changePercent)
            } else if exitActive {
                if let interval = activeIntervalStart {
                    let endMs = Int(elapsedNs / 1_000_000)
                    motionIntervals.append(
                        WatchMotionInterval(
                            startFrameIndex: interval.index,
                            endFrameIndex: max(frameIndex - 1, interval.index),
                            startMs: interval.startMs,
                            endMs: endMs,
                            maxChangePercent: interval.maxChange))
                }
                activeMode = false
                activeIntervalStart = nil
            } else if activeMode, var interval = activeIntervalStart {
                interval.maxChange = max(interval.maxChange, changePercent)
                activeIntervalStart = interval
            }

            let isHeartbeat = UInt64(now.timeIntervalSince(lastKeptTime) * 1_000_000_000) >= heartbeatNs
            let shouldKeep = self.frames.isEmpty
                || enterActive
                || isHeartbeat

            let reason: WatchFrameInfo.Reason = if self.frames.isEmpty {
                .first
            } else if enterActive {
                .motion
            } else if isHeartbeat {
                .heartbeat
            } else {
                .cap
            }

            if shouldKeep {
                let saved = try self.saveFrame(
                    cgImage: cgImage,
                    capture: capture,
                    index: frameIndex,
                    timestampMs: Int(elapsedNs / 1_000_000),
                    changePercent: changePercent,
                    reason: reason,
                    motionBoxes: motionBoxes)
                self.frames.append(saved)
                lastKeptTime = now
            } else {
                self.framesDropped += 1
            }

            frameIndex += 1

            let cadence = activeMode ? cadenceActiveNs : cadenceIdleNs
            try await self.sleep(ns: cadence, since: frameStart)
        }

        if let interval = activeIntervalStart {
            let endMs = Int(Date().timeIntervalSince(start) * 1_000_000)
            motionIntervals.append(
                WatchMotionInterval(
                    startFrameIndex: interval.index,
                    endFrameIndex: max(self.frames.count - 1, interval.index),
                    startMs: interval.startMs,
                    endMs: endMs,
                    maxChangePercent: interval.maxChange))
        }

        if self.frames.isEmpty, let capture = try? await self.captureFrame(), let cg = capture.cgImage {
            let saved = try self.saveFrame(
                cgImage: cg,
                capture: capture,
                index: frameIndex,
                timestampMs: 0,
                changePercent: 0,
                reason: .first,
                motionBoxes: nil)
            self.frames.append(saved)
        }

        if self.frames.isEmpty {
            self.warnings.append(
                WatchWarning(code: .noMotion, message: "No frames were captured"))
        }

        let contact = try self.buildContactSheet()
        let durationMs = Int(Date().timeIntervalSince(start) * 1_000)
        if self.frames.count < 2 {
            self.warnings.append(
                WatchWarning(code: .noMotion, message: "No motion detected; only key frames captured"))
        }

        let fox = WatchOptionsSnapshot(
            duration: self.options.duration,
            idleFps: self.options.idleFps,
            activeFps: self.options.activeFps,
            changeThresholdPercent: self.options.changeThresholdPercent,
            heartbeatSeconds: self.options.heartbeatSeconds,
            quietMsToIdle: self.options.quietMsToIdle,
            maxFrames: self.options.maxFrames,
            maxMegabytes: self.options.maxMegabytes,
            highlightChanges: self.options.highlightChanges,
            captureFocus: self.options.captureFocus,
            resolutionCap: self.options.resolutionCap,
            diffStrategy: self.options.diffStrategy,
            diffBudgetMs: self.options.diffBudgetMs)

        let stats = WatchStats(
            durationMs: durationMs,
            fpsIdle: self.options.idleFps,
            fpsActive: self.options.activeFps,
            fpsEffective: self.computeEffectiveFps(durationMs: durationMs),
            framesKept: self.frames.count,
            framesDropped: self.framesDropped,
            maxFramesHit: self.frames.count >= self.options.maxFrames,
            maxMbHit: self.options.maxMegabytes != nil && self.totalBytes / (1024 * 1024) >= (self.options.maxMegabytes ?? 0))

        let metadataURL = self.outputRoot.appendingPathComponent("metadata.json")
        let metadata = WatchCaptureResult(
            frames: self.frames,
            contactSheet: contact,
            metadataFile: metadataURL.path,
            stats: stats,
            scope: self.scope,
            diffAlgorithm: diffStrategy.rawValue,
            diffScale: "w\(Int(Constants.diffScaleWidth))",
            options: fox,
            warnings: self.warnings)

        try self.writeJSON(metadata, to: metadataURL)
        return metadata
    }

    // MARK: - Capture helpers

    private struct CaptureEnvelope {
        let cgImage: CGImage?
        let metadata: CaptureMetadata
        let motionBoxes: [CGRect]?
    }

    private func captureFrame() async throws -> CaptureEnvelope {
        let result: CaptureResult
        switch self.scope.kind {
        case .screen:
            result = try await self.screenCapture.captureScreen(displayIndex: self.scope.screenIndex)
        case .frontmost:
            result = try await self.screenCapture.captureFrontmost()
        case .window:
            guard let app = self.scope.applicationIdentifier else {
                throw PeekabooError.windowNotFound(criteria: "missing application identifier")
            }
            result = try await self.screenCapture.captureWindow(
                appIdentifier: app,
                windowIndex: self.scope.windowIndex)
        case .region:
            guard let rect = self.scope.region else {
                throw PeekabooError.captureFailed(reason: "Region missing for watch capture")
            }
            let validated = try self.validateRegion(rect)
            result = try await self.screenCapture.captureArea(validated)
        }

        guard let image = WatchCaptureSession.makeCGImage(from: result.imageData) else {
            return CaptureEnvelope(cgImage: nil, metadata: result.metadata, motionBoxes: nil)
        }

        let cappedImage = self.capResolutionIfNeeded(image)
        return CaptureEnvelope(cgImage: cappedImage, metadata: result.metadata, motionBoxes: nil)
    }

    private func capResolutionIfNeeded(_ image: CGImage) -> CGImage {
        guard let cap = self.options.resolutionCap else { return image }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let maxDimension = max(width, height)
        guard maxDimension > cap else { return image }
        let scale = cap / maxDimension
        let newSize = CGSize(width: width * scale, height: height * scale)
        return WatchCaptureSession.resize(image: image, to: newSize) ?? image
    }

    private func saveFrame(
        cgImage: CGImage,
        capture: CaptureEnvelope,
        index: Int,
        timestampMs: Int,
        changePercent: Double,
        reason: WatchFrameInfo.Reason,
        motionBoxes: [CGRect]?) throws -> WatchFrameInfo
    {
        let fileName = String(format: "keep-%04d.png", self.frames.count + 1)
        let url = self.outputRoot.appendingPathComponent(fileName)
        try WatchCaptureSession.writePNG(image: cgImage, to: url, highlight: self.options.highlightChanges ? motionBoxes : nil)

        if let data = try? Data(contentsOf: url) {
            self.totalBytes += data.count
        }

        return WatchFrameInfo(
            index: index,
            path: url.path,
            file: fileName,
            timestampMs: timestampMs,
            changePercent: changePercent,
            reason: reason,
            motionBoxes: motionBoxes?.isEmpty == false ? motionBoxes : nil)
    }

    // MARK: - Contact sheet

    private func buildContactSheet() throws -> WatchContactSheet {
        let columns = Constants.contactMaxColumns
        let maxCells = columns * columns
        let framesToUse: [WatchFrameInfo]
        let sampledIndexes: [Int]
        if self.frames.count <= maxCells {
            framesToUse = self.frames
            sampledIndexes = self.frames.map(\.index)
        } else {
            // Sample evenly to keep contact sheets readable when many frames are kept.
            framesToUse = WatchCaptureSession.sampleFrames(self.frames, maxCount: maxCells)
            sampledIndexes = framesToUse.map(\.index)
        }
        let rows = Int(ceil(Double(framesToUse.count) / Double(columns)))
        let thumbSize = CGSize(width: Constants.contactThumb, height: Constants.contactThumb)
        let sheetSize = CGSize(width: CGFloat(columns) * thumbSize.width, height: CGFloat(rows) * thumbSize.height)
        guard let context = CGContext(
            data: nil,
            width: Int(sheetSize.width),
            height: Int(sheetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            throw PeekabooError.captureFailed(reason: "Failed to build contact sheet context")
        }

        for (idx, frame) in framesToUse.enumerated() {
            guard let image = WatchCaptureSession.makeCGImage(fromFile: frame.path) else { continue }
            let resized = WatchCaptureSession.resize(image: image, to: thumbSize) ?? image
            let row = idx / columns
            let col = idx % columns
            let origin = CGPoint(
                x: CGFloat(col) * thumbSize.width,
                y: CGFloat(rows - row - 1) * thumbSize.height)
            context.draw(resized, in: CGRect(origin: origin, size: thumbSize))
        }

        guard let cg = context.makeImage() else {
            throw PeekabooError.captureFailed(reason: "Failed to finalize contact sheet")
        }

        let contactURL = self.outputRoot.appendingPathComponent("contact.png")
        try WatchCaptureSession.writePNG(image: cg, to: contactURL, highlight: nil)

        return WatchContactSheet(
            path: contactURL.path,
            file: "contact.png",
            columns: columns,
            rows: rows,
            thumbSize: thumbSize,
            sampledFrameIndexes: sampledIndexes)
    }

    // MARK: - Utilities

    private func computeEffectiveFps(durationMs: Int) -> Double {
        guard durationMs > 0 else { return 0 }
        return Double(self.frames.count) / (Double(durationMs) / 1000.0)
    }

    private func prepareOutputRoot() throws {
        try self.fileManager.createDirectory(
            at: self.outputRoot,
            withIntermediateDirectories: true)
    }

    private func performAutoclean() {
        guard self.managedAutoclean else { return }
        let root = self.outputRoot.deletingLastPathComponent()
        guard root.lastPathComponent == "watch-sessions" else { return }
        guard let contents = try? self.fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles)
        else { return }

        let deadline = Date().addingTimeInterval(TimeInterval(-self.autocleanMinutes) * 60)
        var removed = 0
        for url in contents {
            guard let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = attrs.contentModificationDate else { continue }
            if modified < deadline {
                if (try? self.fileManager.removeItem(at: url)) != nil {
                    removed += 1
                }
            }
        }
        if removed > 0 {
            self.warnings.append(
                WatchWarning(
                    code: .autoclean,
                    message: "Autoclean removed \(removed) old watch sessions",
                    details: ["session": self.sessionId]))
        }
    }

    private func sleep(ns: UInt64, since start: Date) async throws {
        let elapsed = UInt64(Date().timeIntervalSince(start) * 1_000_000_000)
        if ns > elapsed {
            try await Task.sleep(nanoseconds: ns - elapsed)
        }
    }

    private static func makeCGImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func makeCGImage(fromFile path: String) -> CGImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return self.makeCGImage(from: data)
    }

    private static func resize(image: CGImage, to size: CGSize) -> CGImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue)
        else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    struct LumaBuffer {
        let width: Int
        let height: Int
        let pixels: [UInt8]
    }

    private func makeLumaBuffer(from image: CGImage) -> LumaBuffer {
        let maxWidth = Constants.diffScaleWidth
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let scale = min(1, maxWidth / max(width, height))
        let targetSize = CGSize(width: width * scale, height: height * scale)
        let w = Int(targetSize.width)
        let h = Int(targetSize.height)
        var pixels = [UInt8](repeating: 0, count: w * h)
        guard let context = CGContext(
            data: &pixels,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else {
            return LumaBuffer(width: 1, height: 1, pixels: [0])
        }
        context.draw(image, in: CGRect(origin: .zero, size: targetSize))
        return LumaBuffer(width: w, height: h, pixels: pixels)
    }

    struct DiffResult {
        let changePercent: Double
        let boundingBoxes: [CGRect]
        let downgraded: Bool
    }

    nonisolated static func computeChange(
        strategy: WatchCaptureOptions.DiffStrategy,
        diffBudgetMs: Int?,
        previous: LumaBuffer?,
        current: LumaBuffer,
        deltaThreshold: UInt8,
        originalSize: CGSize) -> DiffResult
    {
        guard let previous else {
            // First frame: force 100% change and a full-frame box so downstream logic always keeps it.
            return DiffResult(
                changePercent: 100.0,
                boundingBoxes: [CGRect(origin: .zero, size: originalSize)],
                downgraded: false)
        }

        // Fast path always runs to get bounding boxes; quality may replace change% but keeps the boxes.
        let pixelDiff = self.computePixelDelta(
            previous: previous,
            current: current,
            deltaThreshold: deltaThreshold,
            originalSize: originalSize)

        var changePercent: Double
        switch strategy {
        case .fast:
            changePercent = pixelDiff.changePercent
        case .quality:
            if let budget = diffBudgetMs {
                let start = DispatchTime.now().uptimeNanoseconds
                let ssim = self.computeSSIM(previous: previous, current: current)
                let elapsedMs = Int((DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
                if elapsedMs > budget {
                    // Guardrail: fall back to fast diff if SSIM is too slow to keep the session responsive.
                    changePercent = pixelDiff.changePercent
                    return DiffResult(changePercent: changePercent, boundingBoxes: pixelDiff.boundingBoxes, downgraded: true)
                } else {
                    changePercent = max(0, min(100, (1 - ssim) * 100))
                }
            } else {
                let ssim = self.computeSSIM(previous: previous, current: current)
                changePercent = max(0, min(100, (1 - ssim) * 100))
            }
        }

        return DiffResult(
            changePercent: changePercent,
            boundingBoxes: pixelDiff.boundingBoxes,
            downgraded: false)
    }

    nonisolated private static func computePixelDelta(
        previous: LumaBuffer,
        current: LumaBuffer,
        deltaThreshold: UInt8,
        originalSize: CGSize) -> DiffResult
    {
        let count = min(previous.pixels.count, current.pixels.count)
        if count == 0 { return DiffResult(changePercent: 0, boundingBoxes: [], downgraded: false) }

        var changed = 0
        var mask = Array(repeating: false, count: count)
        for idx in 0..<count {
            let diff = abs(Int(previous.pixels[idx]) - Int(current.pixels[idx]))
            if diff >= deltaThreshold {
                changed += 1
                mask[idx] = true
            }
        }

        let percent = (Double(changed) / Double(count)) * 100.0
        if changed == 0 { return DiffResult(changePercent: percent, boundingBoxes: [], downgraded: false) }

        let boxes = self.extractBoundingBoxes(mask: mask, width: current.width, height: current.height, originalSize: originalSize)
        return DiffResult(changePercent: percent, boundingBoxes: boxes, downgraded: false)
    }

    /// Extract axis-aligned bounding boxes for connected components in the diff mask.
    nonisolated private static func extractBoundingBoxes(
        mask: [Bool],
        width: Int,
        height: Int,
        originalSize: CGSize) -> [CGRect]
    {
        var visited = Array(repeating: false, count: mask.count)
        var boxes: [CGRect] = []
        let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        let maxBoxes = 5      // Avoid overwhelming overlays
        let minPixels = 1     // Tiny blobs still count; caller can filter when drawing

        func index(_ x: Int, _ y: Int) -> Int { y * width + x }

        for y in 0..<height {
            for x in 0..<width {
                let idx = index(x, y)
                if !mask[idx] || visited[idx] { continue }

                var stack = [(x, y)]
                visited[idx] = true
                var minX = x, maxX = x, minY = y, maxY = y
                var count = 0

                while let (cx, cy) = stack.popLast() {
                    count += 1
                    minX = min(minX, cx); maxX = max(maxX, cx)
                    minY = min(minY, cy); maxY = max(maxY, cy)
                    for (dx, dy) in directions {
                        let nx = cx + dx, ny = cy + dy
                        if nx < 0 || ny < 0 || nx >= width || ny >= height { continue }
                        let nIdx = index(nx, ny)
                        if mask[nIdx] && !visited[nIdx] {
                            visited[nIdx] = true
                            stack.append((nx, ny))
                        }
                    }
                }

                guard count >= minPixels else { continue }

                let scaleX = originalSize.width / CGFloat(width)
                let scaleY = originalSize.height / CGFloat(height)
                let rect = CGRect(
                    x: CGFloat(minX) * scaleX,
                    y: CGFloat(minY) * scaleY,
                    width: CGFloat(maxX - minX + 1) * scaleX,
                    height: CGFloat(maxY - minY + 1) * scaleY)
                boxes.append(rect)
                if boxes.count >= maxBoxes { return boxes }
            }
        }

        return boxes
    }

    nonisolated static func computeSSIM(previous: LumaBuffer, current: LumaBuffer) -> Double {
        let count = min(previous.pixels.count, current.pixels.count)
        if count == 0 { return 0 }

        var meanX: Double = 0
        var meanY: Double = 0
        for idx in 0..<count {
            meanX += Double(previous.pixels[idx])
            meanY += Double(current.pixels[idx])
        }
        meanX /= Double(count)
        meanY /= Double(count)

        var varianceX: Double = 0
        var varianceY: Double = 0
        var covariance: Double = 0
        for idx in 0..<count {
            let x = Double(previous.pixels[idx]) - meanX
            let y = Double(current.pixels[idx]) - meanY
            varianceX += x * x
            varianceY += y * y
            covariance += x * y
        }
        varianceX /= Double(count - 1)
        varianceY /= Double(count - 1)
        covariance /= Double(count - 1)

        let c1 = pow(0.01 * 255.0, 2.0)
        let c2 = pow(0.03 * 255.0, 2.0)

        let numerator = (2 * meanX * meanY + c1) * (2 * covariance + c2)
        let denominator = (meanX * meanX + meanY * meanY + c1) * (varianceX + varianceY + c2)

        guard denominator != 0 else { return 0 }
        return numerator / denominator
    }

    private static func sampleFrames(_ frames: [WatchFrameInfo], maxCount: Int) -> [WatchFrameInfo] {
        guard frames.count > maxCount else { return frames }
        let step = Double(frames.count - 1) / Double(maxCount - 1)
        var indexes: [Int] = []
        for i in 0..<maxCount {
            let idx = Int(round(Double(i) * step))
            indexes.append(min(idx, frames.count - 1))
        }
        let set = Set(indexes)
        return frames.enumerated()
            .filter { set.contains($0.offset) }
            .map(\.element)
    }

    private static func writePNG(image: CGImage, to url: URL, highlight: [CGRect]?) throws {
        let finalImage: CGImage
        if let highlight, !highlight.isEmpty,
           let annotated = self.annotate(image: image, boxes: highlight) {
            finalImage = annotated
        } else {
            finalImage = image
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw PeekabooError.captureFailed(reason: "Failed to create image destination")
        }
        CGImageDestinationAddImage(destination, finalImage, nil)
        if !CGImageDestinationFinalize(destination) {
            throw PeekabooError.captureFailed(reason: "Failed to write PNG")
        }
    }

    private static func annotate(image: CGImage, boxes: [CGRect]) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: image.bitmapInfo.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.setStrokeColor(NSColor.systemRed.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(max(2, CGFloat(image.width) * 0.002))
        for box in boxes {
            context.stroke(box)
        }
        return context.makeImage()
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Region validation

    private func validateRegion(_ rect: CGRect) throws -> CGRect {
        let screens = self.screenCaptureScreens()
        guard !screens.isEmpty else {
            throw PeekabooError.invalidInput("No screens available for region capture")
        }

        // Global coords are expected; find intersection across all screens.
        var union = CGRect.null
        for screen in screens {
            union = union.union(screen.frame)
        }

        guard rect.intersects(union) else {
            throw PeekabooError.invalidInput("Region lies outside all screens")
        }

        let clamped = rect.intersection(union)
        if clamped != rect {
            // Clamp instead of failing when partially visible; signal to callers via warning.
            self.warnings.append(
                WatchWarning(code: .displayChanged, message: "Region adjusted to visible area"))
        }
        return clamped
    }

    private func screenCaptureScreens() -> [ScreenInfo] {
        self.screenService?.listScreens() ?? []
    }
}
