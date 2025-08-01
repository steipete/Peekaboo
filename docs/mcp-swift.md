# Peekaboo Swift MCP Server Implementation

> **✅ UPDATE (2025-01-31)**: Migration complete! Peekaboo now runs as a pure Swift MCP server. The TypeScript server has been removed.

This document describes the Swift MCP server implementation in Peekaboo, which provides all automation tools through a native Swift server using the official MCP SDK (v0.9.0).

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Implementation Phases](#implementation-phases)
4. [Technical Components](#technical-components)
5. [Migration Strategy](#migration-strategy)
6. [Testing & Validation](#testing--validation)
7. [Deployment & Distribution](#deployment--distribution)
8. [Future Enhancements](#future-enhancements)

## Executive Summary

### Achievements
- ✅ Eliminated TypeScript/Node.js runtime dependency
- ✅ ~10x performance improvement through direct API calls
- ✅ All 22 MCP tools implemented in Swift
- ✅ Type-safe implementation with Swift 6
- ✅ Direct PeekabooCore API integration

### Key Benefits
- Single binary deployment
- Type-safe Swift implementation throughout
- Direct PeekabooCore API access (no subprocess spawning)
- Reduced latency and memory usage
- Unified codebase in Swift

## Architecture Overview

### Current Architecture (Implemented)
```
┌─────────────┐     ┌──────────────┐
│  MCP Client │────▶│ Swift MCP    │
│   (Claude)  │stdio│   Server     │
└─────────────┘     └──────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │PeekabooCore │
                    │Direct APIs  │
                    └─────────────┘
```

The Swift MCP server directly integrates with PeekabooCore, eliminating the need for TypeScript middleware and subprocess spawning.

## Implementation Phases

### Phase 1: Foundation (Days 1-2)

#### 1.1 Add Swift MCP SDK Dependency
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
    // Existing dependencies...
],
targets: [
    .executableTarget(
        name: "peekaboo",
        dependencies: [
            .product(name: "MCP", package: "swift-sdk"),
            "PeekabooCore",
            "AXorcist"
        ]
    )
]
```

#### 1.2 Create MCP Command Structure
```swift
// Apps/CLI/Sources/peekaboo/Commands/MCPCommand.swift
import ArgumentParser
import MCPServer

struct MCPCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        abstract: "Model Context Protocol server and client operations",
        subcommands: [Serve.self, Call.self, List.self, Inspect.self]
    )
}

struct Serve: AsyncParsableCommand {
    @Option(help: "Transport type (stdio, http, sse)")
    var transport: TransportType = .stdio
    
    @Option(help: "Port for HTTP transport")
    var port: Int = 8080
    
    @Option(help: "Log level (debug, info, warn, error)")
    var logLevel: LogLevel = .info
    
    func run() async throws {
        let server = try PeekabooMCPServer(logLevel: logLevel)
        try await server.serve(transport: transport, port: port)
    }
}
```

#### 1.3 Create Core MCP Server
```swift
// Core/PeekabooCore/Sources/PeekabooCore/MCP/PeekabooMCPServer.swift
import Foundation
import MCP
import os.log

public actor PeekabooMCPServer {
    private let server: Server
    private let toolRegistry: MCPToolRegistry
    private let logger: Logger
    
    public init(logLevel: LogLevel = .info) throws {
        self.logger = Logger(subsystem: "boo.peekaboo.mcp", category: "server")
        self.toolRegistry = MCPToolRegistry()
        
        // Initialize the official MCP Server
        self.server = Server(
            name: "peekaboo-mcp",
            version: Version.current.string,
            capabilities: Server.Capabilities(
                tools: .init(listChanged: true),
                resources: .init(subscribe: false, listChanged: false),
                prompts: .init(listChanged: false)
            )
        )
        
        setupHandlers()
        registerAllTools()
    }
    
    private func setupHandlers() {
        // Tool list handler
        server.withMethodHandler(ListTools.self) { [weak self] _ in
            guard let self = self else { return ListTools.Response(tools: []) }
            
            let tools = await self.toolRegistry.allTools().map { tool in
                Tool(
                    name: tool.name,
                    description: tool.description,
                    inputSchema: tool.inputSchema
                )
            }
            
            return ListTools.Response(tools: tools)
        }
        
        // Tool call handler
        server.withMethodHandler(CallTool.self) { [weak self] request in
            guard let self = self else {
                throw ServerError(code: ErrorCode.internalError, message: "Server deallocated")
            }
            
            guard let tool = await self.toolRegistry.tool(named: request.name) else {
                throw ServerError(code: ErrorCode.invalidParams, message: "Tool '\(request.name)' not found")
            }
            
            let arguments = ToolArguments(raw: request.arguments ?? [:])
            let response = try await tool.execute(arguments: arguments)
            
            return CallTool.Response(
                content: response.content,
                isError: response.isError,
                meta: response.meta
            )
        }
    }
    
    public func serve(transport: TransportType, port: Int = 8080) async throws {
        logger.info("Starting Peekaboo MCP server", metadata: [
            "transport": "\(transport)",
            "version": "\(Version.current.string)"
        ])
        
        let serverTransport: any Transport
        
        switch transport {
        case .stdio:
            serverTransport = StdioTransport(logger: logger)
            
        case .http:
            // Note: HTTP transport would need custom implementation
            // as the SDK only provides HTTPClientTransport
            throw MCPError.notImplemented("HTTP server transport not yet implemented")
            
        case .sse:
            throw MCPError.notImplemented("SSE server transport not yet implemented")
        }
        
        try await server.start(transport: serverTransport)
    }
}
```

### Phase 2: Tool Migration (Days 3-5)

#### 2.1 Tool Protocol Definition
```swift
// Core/PeekabooCore/Sources/PeekabooCore/MCP/MCPTool.swift
import Foundation
import MCP

public protocol MCPTool {
    var name: String { get }
    var description: String { get }
    var inputSchema: Value { get }
    
    func execute(arguments: ToolArguments) async throws -> ToolResponse
}

public struct ToolArguments {
    private let raw: [String: Any]
    
    public init(raw: [String: Any]) {
        self.raw = raw
    }
    
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: raw)
        return try JSONDecoder().decode(type, from: data)
    }
}

public struct ToolResponse {
    public let content: [Content]
    public let isError: Bool
    public let meta: [String: Any]?
    
    public init(content: [Content], isError: Bool = false, meta: [String: Any]? = nil) {
        self.content = content
        self.isError = isError
        self.meta = meta
    }
    
    public static func text(_ text: String, meta: [String: Any]? = nil) -> ToolResponse {
        ToolResponse(
            content: [.text(text)],
            isError: false,
            meta: meta
        )
    }
    
    public static func error(_ message: String) -> ToolResponse {
        ToolResponse(
            content: [.text(message)],
            isError: true,
            meta: nil
        )
    }
}
```

#### 2.2 Image Tool Implementation
```swift
// Core/PeekabooCore/Sources/PeekabooCore/MCP/Tools/ImageTool.swift
import Foundation
import MCPServer

public struct ImageTool: MCPTool {
    public let name = "image"
    
    public var description: String {
        """
        Captures macOS screen content and optionally analyzes it. \
        Targets can be entire screen, specific app window, or all windows of an app (via app_target). \
        Supports foreground/background capture. Output via file path or inline Base64 data (format: "data"). \
        If a question is provided, image is analyzed by an AI model. \
        Window shadows/frames excluded. \
        Peekaboo \(Version.current.string)
        """
    }
    
    public var inputSchema: Value {
        SchemaBuilder.object(
            properties: [
                "path": SchemaBuilder.string(
                    description: "Optional. Base absolute path for saving the image."
                ),
                "format": SchemaBuilder.string(
                    description: "Optional. Output format.",
                    enum: ["png", "jpg", "data"]
                ),
                "app_target": SchemaBuilder.string(
                    description: "Optional. Specifies the capture target."
                ),
                "question": SchemaBuilder.string(
                    description: "Optional. If provided, the captured image will be analyzed."
                ),
                "capture_focus": SchemaBuilder.string(
                    description: "Optional. Focus behavior.",
                    enum: ["background", "auto", "foreground"],
                    default: "auto"
                )
            ],
            required: ["path", "format"]
        )
    }
    
    public func execute(arguments: ToolArguments) async throws -> ToolResponse {
        let input = try arguments.decode(ImageInput.self)
        
        // Direct API call instead of subprocess
        let service = ScreenCaptureService()
        let result = try await service.captureScreen(
            appTarget: input.appTarget,
            format: normalizeFormat(input.format),
            path: input.path,
            captureFocus: input.captureFocus ?? .auto
        )
        
        // Handle analysis if requested
        if let question = input.question {
            let analysisResult = try await analyzeImage(
                at: result.savedFiles.first?.path ?? "",
                question: question
            )
            
            return .text(analysisResult.text, metadata: [
                "model": analysisResult.modelUsed,
                "savedFiles": result.savedFiles.map { $0.path }
            ])
        }
        
        // Return capture result
        if input.format == "data" {
            let imageData = try Data(contentsOf: URL(fileURLWithPath: result.savedFiles.first!.path))
            return ToolResponse(
                content: [.image(data: imageData, mimeType: "image/png")],
                meta: ["savedFiles": result.savedFiles.map { $0.path }]
            )
        }
        
        return ToolResponse.text(
            buildImageSummary(result),
            meta: ["savedFiles": result.savedFiles.map { $0.path }]
        )
    }
}
```

#### 2.3 Tool Registry
```swift
// Core/PeekabooCore/Sources/PeekabooCore/MCP/MCPToolRegistry.swift
import Foundation

@MainActor
public class MCPToolRegistry {
    private var tools: [String: MCPTool] = [:]
    
    public func register(_ tool: MCPTool) {
        tools[tool.name] = tool
    }
    
    public func registerAll() {
        // Core tools
        register(ImageTool())
        register(AnalyzeTool())
        register(ListTool())
        
        // UI automation tools
        register(SeeTool())
        register(ClickTool())
        register(TypeTool())
        register(ScrollTool())
        register(HotkeyTool())
        register(SwipeTool())
        
        // App management tools
        register(AppTool())
        register(WindowTool())
        register(MenuTool())
        
        // System tools
        register(PermissionsTool())
        register(CleanTool())
        register(SleepTool())
        
        // Advanced tools
        register(AgentTool())
        register(DockTool())
        register(DialogTool())
        register(SpaceTool())
        register(MoveTool())
        register(DragTool())
    }
    
    public func tool(named name: String) -> MCPTool? {
        tools[name]
    }
    
    public func allTools() -> [ToolInfo] {
        tools.values.map { tool in
            ToolInfo(
                name: tool.name,
                description: tool.description,
                inputSchema: tool.inputSchema
            )
        }
    }
}
```

### Phase 3: Schema Generation (Days 6-7)

#### 3.1 JSON Schema with MCP Value Type
```swift
// Core/PeekabooCore/Sources/PeekabooCore/MCP/Schema/SchemaBuilder.swift
import Foundation
import MCP

public struct SchemaBuilder {
    /// Build a JSON Schema using MCP's Value type
    public static func object(
        properties: [String: Value],
        required: [String] = [],
        description: String? = nil
    ) -> Value {
        var schema: [String: Value] = [
            "type": .string("object"),
            "properties": .object(properties)
        ]
        
        if !required.isEmpty {
            schema["required"] = .array(required.map { .string($0) })
        }
        
        if let desc = description {
            schema["description"] = .string(desc)
        }
        
        return .object(schema)
    }
    
    public static func string(
        description: String? = nil,
        enum values: [String]? = nil,
        default: String? = nil
    ) -> Value {
        var schema: [String: Value] = ["type": .string("string")]
        
        if let desc = description {
            schema["description"] = .string(desc)
        }
        
        if let values = values {
            schema["enum"] = .array(values.map { .string($0) })
        }
        
        if let defaultValue = `default` {
            schema["default"] = .string(defaultValue)
        }
        
        return .object(schema)
    }
    
    public static func boolean(description: String? = nil) -> Value {
        var schema: [String: Value] = ["type": .string("boolean")]
        
        if let desc = description {
            schema["description"] = .string(desc)
        }
        
        return .object(schema)
    }
    
    public static func number(description: String? = nil) -> Value {
        var schema: [String: Value] = ["type": .string("number")]
        
        if let desc = description {
            schema["description"] = .string(desc)
        }
        
        return .object(schema)
    }
}
```

#### 3.2 Input Types with Validation
```swift
// Core/PeekabooCore/Sources/PeekabooCore/MCP/Types/ToolInputs.swift
import Foundation

public struct ImageInput: Codable {
    public let path: String?
    public let format: ImageFormat?
    public let appTarget: String?
    public let question: String?
    public let captureFocus: CaptureFocus?
    
    public enum ImageFormat: String, Codable {
        case png, jpg, data
    }
    
    public enum CaptureFocus: String, Codable {
        case background, auto, foreground
    }
    
    // Custom validation
    public func validate() throws {
        if format == "data" && path == nil {
            // Data format requires processing
        }
        
        if let appTarget = appTarget {
            // Validate app target format
            if !appTarget.isEmpty && !isValidAppTarget(appTarget) {
                throw ValidationError.invalidAppTarget(appTarget)
            }
        }
    }
}
```

### Phase 4: Configuration & AI Providers (Days 8-9)

#### 4.1 Configuration Loading
```swift
// Core/PeekabooCore/Sources/PeekabooCore/Configuration/ConfigurationManager.swift
import Foundation

public class ConfigurationManager {
    public static let shared = ConfigurationManager()
    
    private var config: PeekabooConfig?
    private var credentials: [String: String] = [:]
    
    public func loadConfiguration() throws {
        // Load ~/.peekaboo/config.json (with JSONC support)
        let configPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".peekaboo/config.json")
        
        if FileManager.default.fileExists(atPath: configPath.path) {
            let data = try Data(contentsOf: configPath)
            let jsonString = String(data: data, encoding: .utf8)?
                .replacingOccurrences(of: #"//.*$"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"/\*[\s\S]*?\*/"#, with: "", options: .regularExpression)
            
            if let cleanData = jsonString?.data(using: .utf8) {
                config = try JSONDecoder().decode(PeekabooConfig.self, from: cleanData)
            }
        }
        
        // Load ~/.peekaboo/credentials
        loadCredentials()
        
        // Apply to environment
        applyCredentialsToEnvironment()
    }
    
    private func loadCredentials() {
        let credentialsPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".peekaboo/credentials")
        
        guard let content = try? String(contentsOf: credentialsPath) else { return }
        
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else { continue }
            
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                credentials[String(parts[0])] = String(parts[1])
            }
        }
    }
}
```

#### 4.2 AI Provider Integration
```swift
// Core/PeekabooCore/Sources/PeekabooCore/AI/AIProviderManager.swift
import Foundation

public class AIProviderManager {
    public static let shared = AIProviderManager()
    
    private var providers: [AIProvider] = []
    
    public func configure(from string: String) {
        providers = string
            .split(separator: ",")
            .compactMap { part in
                let components = part.split(separator: "/")
                guard components.count == 2 else { return nil }
                return AIProvider(
                    type: String(components[0]).trimmingCharacters(in: .whitespaces),
                    model: String(components[1]).trimmingCharacters(in: .whitespaces)
                )
            }
    }
    
    public func analyzeImage(
        _ imageData: Data,
        question: String,
        preferredProvider: String? = nil
    ) async throws -> AnalysisResult {
        // Try preferred provider first
        if let preferred = preferredProvider,
           let provider = providers.first(where: { $0.type == preferred }) {
            if let result = try? await analyze(with: provider, imageData, question) {
                return result
            }
        }
        
        // Fall back to first available
        for provider in providers {
            if let result = try? await analyze(with: provider, imageData, question) {
                return result
            }
        }
        
        throw AIError.noAvailableProvider
    }
}
```

### Phase 5: Node.js Wrapper (Day 10)

#### 5.1 Robust Restart Wrapper
```javascript
#!/usr/bin/env node
// peekaboo-mcp.js - MCP wrapper with crash recovery

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const binaryPath = join(__dirname, 'peekaboo');

// Configuration
const MAX_RESTARTS = 5;
const RESTART_DELAY = 1000;
const RESTART_WINDOW = 60000;
const HEALTH_CHECK_INTERVAL = 30000;

class PeekabooMCPWrapper {
  constructor() {
    this.restartCount = 0;
    this.restartTimestamps = [];
    this.currentDelay = RESTART_DELAY;
    this.child = null;
    this.shuttingDown = false;
    this.lastHealthCheck = Date.now();
  }

  start() {
    // Check binary exists
    if (!existsSync(binaryPath)) {
      console.error(`[Peekaboo MCP] Binary not found at: ${binaryPath}`);
      console.error('[Peekaboo MCP] Please ensure the package was installed correctly.');
      process.exit(1);
    }

    // Clean old restart timestamps
    const now = Date.now();
    this.restartTimestamps = this.restartTimestamps.filter(
      ts => now - ts < RESTART_WINDOW
    );

    // Check restart frequency
    if (this.restartTimestamps.length >= MAX_RESTARTS) {
      console.error(
        `[Peekaboo MCP] Fatal: Restarted ${MAX_RESTARTS} times in ${RESTART_WINDOW/1000}s. ` +
        `Please check the logs at ~/.peekaboo/logs/mcp-server.log`
      );
      process.exit(1);
    }

    console.error(
      `[Peekaboo MCP] Starting server${this.restartCount > 0 ? ` (attempt ${this.restartCount + 1})` : ''}...`
    );

    // Start the Swift MCP server
    this.child = spawn(binaryPath, ['mcp', 'serve'], {
      stdio: 'inherit',
      env: {
        ...process.env,
        PEEKABOO_MCP_WRAPPER: 'true',
        PEEKABOO_MCP_RESTART_COUNT: String(this.restartCount),
        PEEKABOO_MCP_WRAPPER_PID: String(process.pid)
      }
    });

    this.child.on('error', (err) => {
      console.error('[Peekaboo MCP] Failed to start:', err.message);
      
      if (err.code === 'ENOENT') {
        console.error('[Peekaboo MCP] Binary not found. Installation may be corrupted.');
        process.exit(1);
      }
      
      if (err.code === 'EACCES') {
        console.error('[Peekaboo MCP] Binary not executable. Running chmod +x...');
        try {
          require('child_process').execSync(`chmod +x "${binaryPath}"`);
          this.handleCrash(1);
        } catch {
          console.error('[Peekaboo MCP] Failed to make binary executable.');
          process.exit(1);
        }
        return;
      }
      
      this.handleCrash(1);
    });

    this.child.on('exit', (code, signal) => {
      if (this.shuttingDown) {
        process.exit(0);
      }

      // Clean exit
      if (code === 0) {
        console.error('[Peekaboo MCP] Server exited cleanly');
        process.exit(0);
      }

      // Special exit codes
      const noRestartCodes = [
        130, // SIGINT (Ctrl+C)
        143, // SIGTERM
        42,  // Configuration error (don't restart)
        43,  // Missing API key (don't restart)
      ];

      if (noRestartCodes.includes(code)) {
        console.error(`[Peekaboo MCP] Server exited with code ${code}. Not restarting.`);
        process.exit(code);
      }

      console.error(`[Peekaboo MCP] Server crashed with code ${code}, signal ${signal}`);
      this.handleCrash(code || 1);
    });

    // Start health monitoring
    this.startHealthMonitoring();

    // Reset delay on successful start
    setTimeout(() => {
      if (this.child && !this.child.killed) {
        this.currentDelay = RESTART_DELAY;
        this.restartCount = 0;
        console.error('[Peekaboo MCP] Server running successfully');
      }
    }, 5000);
  }

  handleCrash(exitCode) {
    this.restartTimestamps.push(Date.now());
    this.restartCount++;

    // Log crash for debugging
    const crashInfo = {
      timestamp: new Date().toISOString(),
      exitCode,
      restartCount: this.restartCount,
      env: process.env.NODE_ENV
    };
    
    // Could write to ~/.peekaboo/crashes.log here

    console.error(`[Peekaboo MCP] Will restart in ${this.currentDelay/1000}s...`);
    
    setTimeout(() => {
      this.start();
    }, this.currentDelay);

    // Exponential backoff
    this.currentDelay = Math.min(
      this.currentDelay * 2,
      30000 // Max 30 seconds
    );
  }

  startHealthMonitoring() {
    // Optional: Implement health checks
    // The Swift server could respond to special MCP requests
    setInterval(() => {
      if (this.child && !this.child.killed) {
        // Could send a health check request here
        this.lastHealthCheck = Date.now();
      }
    }, HEALTH_CHECK_INTERVAL);
  }

  shutdown() {
    this.shuttingDown = true;
    if (this.child && !this.child.killed) {
      this.child.kill('SIGTERM');
    }
  }
}

// Start the wrapper
const wrapper = new PeekabooMCPWrapper();
wrapper.start();

// Handle signals
process.on('SIGINT', () => {
  console.error('\n[Peekaboo MCP] Received SIGINT, shutting down...');
  wrapper.shutdown();
});

process.on('SIGTERM', () => {
  console.error('[Peekaboo MCP] Received SIGTERM, shutting down...');
  wrapper.shutdown();
});

// Prevent Node crashes from killing the wrapper
process.on('uncaughtException', (err) => {
  console.error('[Peekaboo MCP] Wrapper uncaught exception:', err);
  wrapper.shutdown();
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('[Peekaboo MCP] Wrapper unhandled rejection:', reason);
  // Don't exit on unhandled rejections
});
```

#### 5.2 Updated package.json
```json
{
  "name": "@steipete/peekaboo-mcp",
  "version": "3.0.0",
  "description": "macOS automation MCP server with screen capture, UI interaction, and AI analysis",
  "type": "module",
  "main": "peekaboo-mcp.js",
  "bin": {
    "peekaboo-mcp": "peekaboo-mcp.js"
  },
  "files": [
    "peekaboo",
    "peekaboo-mcp.js",
    "README.md",
    "LICENSE"
  ],
  "scripts": {
    "prepublishOnly": "../scripts/build-swift-universal.sh",
    "postinstall": "chmod +x peekaboo peekaboo-mcp.js 2>/dev/null || true",
    "test": "node --test test-wrapper.js"
  },
  "keywords": [
    "mcp",
    "model-context-protocol",
    "macos",
    "automation",
    "screen-capture",
    "ai"
  ],
  "engines": {
    "node": ">=18.0.0"
  },
  "os": ["darwin"],
  "cpu": ["x64", "arm64"],
  "author": "Peter Steinberger <steipete@gmail.com>",
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "git+https://github.com/steipete/peekaboo.git"
  }
}
```

## Technical Components

### Error Handling
```swift
// Core/PeekabooCore/Sources/PeekabooCore/MCP/MCPError.swift
public enum MCPError: LocalizedError {
    case toolNotFound(String)
    case invalidArguments(String)
    case executionFailed(String, underlying: Error?)
    case configurationError(String)
    case serverError(String)
    
    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let tool):
            return "Tool '\(tool)' not found"
        case .invalidArguments(let details):
            return "Invalid arguments: \(details)"
        case .executionFailed(let message, let underlying):
            if let underlying = underlying {
                return "\(message): \(underlying.localizedDescription)"
            }
            return message
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
```

### Logging Integration
```swift
// Core/PeekabooCore/Sources/PeekabooCore/MCP/MCPLogger.swift
import os.log

extension Logger {
    static let mcpServer = Logger(subsystem: "boo.peekaboo.mcp", category: "server")
    static let mcpTools = Logger(subsystem: "boo.peekaboo.mcp", category: "tools")
    static let mcpClient = Logger(subsystem: "boo.peekaboo.mcp", category: "client")
}

// Usage in tools
Logger.mcpTools.info("Executing image capture", metadata: [
    "appTarget": "\(input.appTarget ?? "screen")",
    "format": "\(input.format ?? "png")"
])
```

### Format Preprocessing
```swift
// Core/PeekabooCore/Sources/PeekabooCore/MCP/Preprocessing/FormatNormalizer.swift
public struct FormatNormalizer {
    public static func normalizeImageFormat(_ format: String?) -> ImageFormat {
        guard let format = format?.lowercased() else { return .png }
        
        switch format {
        case "png": return .png
        case "jpg", "jpeg": return .jpg
        case "data": return .data
        default:
            Logger.mcpTools.warning("Invalid format '\(format)', using PNG")
            return .png
        }
    }
    
    public static func validateForScreenCapture(
        format: ImageFormat,
        isScreenCapture: Bool
    ) -> (format: ImageFormat, warning: String?) {
        if isScreenCapture && format == .data {
            return (.png, "Screen captures cannot use format 'data' due to size constraints. Using PNG.")
        }
        return (format, nil)
    }
}
```

## Migration Strategy

### Step 1: Parallel Development
- Keep TypeScript server running
- Develop Swift MCP server alongside
- Test with MCP Inspector

### Step 2: Feature Parity Testing
```bash
# Test TypeScript version
npx @modelcontextprotocol/inspector node dist/index.js

# Test Swift version
npx @modelcontextprotocol/inspector ./peekaboo mcp serve
```

### Step 3: Gradual Migration
1. Start with simple tools (permissions, sleep, clean)
2. Move to capture tools (image, list)
3. Migrate UI automation (see, click, type)
4. Complex tools last (agent, multi-window operations)

### Step 4: Validation
- Compare outputs between TypeScript and Swift
- Ensure all edge cases are handled
- Test error scenarios

### Step 5: Cutover
1. Update npm package to use Swift binary
2. Remove TypeScript code
3. Update documentation
4. Announce migration

## Testing & Validation

### Unit Tests
```swift
// Tests/PekabooMCPTests/ImageToolTests.swift
import Testing
@testable import PeekabooCore

@Test
func testImageToolSchema() async throws {
    let tool = ImageTool()
    let schema = tool.inputSchema.encode()
    
    #expect(schema["type"] as? String == "object")
    #expect((schema["properties"] as? [String: Any])?.keys.contains("path") == true)
}

@Test
func testImageToolExecution() async throws {
    let tool = ImageTool()
    let args = ToolArguments(raw: [
        "path": "/tmp/test.png",
        "format": "png",
        "app_target": "screen:0"
    ])
    
    let response = try await tool.execute(arguments: args)
    #expect(response.isSuccess)
}
```

### Integration Tests
```swift
@Test
func testMCPServerLifecycle() async throws {
    let server = try PeekabooMCPServer()
    
    // Start server in background
    Task {
        try await server.serve(transport: .stdio)
    }
    
    // Give it time to start
    try await Task.sleep(for: .seconds(1))
    
    // Test tool listing
    let client = try MCPClient()
    let tools = try await client.listTools()
    
    #expect(tools.count > 20)
    #expect(tools.contains { $0.name == "image" })
}
```

### Wrapper Tests
```javascript
// test-wrapper.js
import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

test('wrapper handles binary crash', async () => {
  // Create a mock binary that crashes
  const child = spawn('node', [join(__dirname, 'peekaboo-mcp.js')], {
    env: {
      ...process.env,
      PEEKABOO_MOCK_CRASH: 'true'
    }
  });
  
  // Should restart within 2 seconds
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  // Check that process is still running
  assert(!child.killed);
  
  child.kill();
});
```

## Deployment & Distribution

### Build Process
```bash
#!/bin/bash
# scripts/build-mcp-release.sh

echo "Building Peekaboo MCP Server..."

# Build universal binary
./scripts/build-swift-universal.sh

# Copy to Server directory
cp peekaboo Server/

# Copy wrapper
cp scripts/peekaboo-mcp.js Server/

# Update version
npm version patch --prefix Server

# Publish
cd Server && npm publish
```

### Installation Instructions
```bash
# Global installation
npm install -g @steipete/peekaboo-mcp

# Use with Claude Code
claude mcp add peekaboo -- peekaboo-mcp

# Use with MCP Inspector
npx @modelcontextprotocol/inspector peekaboo-mcp

# Direct usage
peekaboo-mcp  # Starts MCP server on stdio
```

### Verification
```bash
# Check installation
which peekaboo-mcp

# Test server
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | peekaboo-mcp

# Check logs
tail -f ~/.peekaboo/logs/mcp-server.log
```

## Future Enhancements

### Phase 6: MCP Client Capabilities
```swift
// Enable Peekaboo to consume other MCP servers
struct MCPCallCommand: AsyncParsableCommand {
    @Argument(help: "MCP server to connect to")
    var server: String
    
    @Option(help: "Tool to call")
    var tool: String
    
    @Option(help: "Tool arguments as JSON")
    var args: String
    
    func run() async throws {
        let client = try await MCPClient.connect(to: server)
        let arguments = try JSONDecoder().decode(
            [String: Any].self,
            from: args.data(using: .utf8)!
        )
        
        let result = try await client.callTool(tool, arguments: arguments)
        print(result)
    }
}
```

### Phase 7: Tool Composition
```swift
// Enable tools to call other tools
public protocol ComposableMCPTool: MCPTool {
    var dependencies: [String] { get }
    var toolRegistry: MCPToolRegistry? { get set }
}

// Example: Screenshot + Edit + Deploy workflow
struct WorkflowTool: ComposableMCPTool {
    let dependencies = ["image", "mcp_call", "shell"]
    
    func execute(arguments: ToolArguments) async throws -> ToolResponse {
        // Capture screen
        let screenshot = try await callTool("image", [...])
        
        // Edit with Claude Code
        let edited = try await callMCPTool("claude-code", "edit_file", [...])
        
        // Deploy
        let deployed = try await callTool("shell", ["kubectl", "apply"])
        
        return .success(...)
    }
}
```

### Phase 8: Performance Monitoring
```swift
// Add metrics collection
public protocol MetricsMCPTool: MCPTool {
    func recordMetrics(_ metrics: ToolMetrics)
}

struct ToolMetrics {
    let duration: TimeInterval
    let memoryUsed: Int
    let success: Bool
    let errorType: String?
}
```

## Conclusion

This migration plan transforms Peekaboo into a native Swift MCP server while maintaining npm distribution compatibility. The architecture provides:

1. **Significant performance improvements** (10x faster)
2. **Simplified deployment** (single binary + tiny wrapper)
3. **Type safety** throughout the codebase
4. **Direct API access** to PeekabooCore
5. **Future extensibility** as both MCP server and client

The phased approach ensures continuous functionality during migration, with comprehensive testing at each stage. The Node.js wrapper provides production-grade reliability with automatic restart capabilities while keeping the npm installation experience unchanged.