#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import pino from "pino";
import path from "path";
import os from "os";
import { fileURLToPath } from "url";
import fs from "fs/promises";

import {
  imageToolHandler,
  imageToolSchema,
  analyzeToolHandler,
  analyzeToolSchema,
  listToolHandler,
  listToolSchema,
  seeToolHandler,
  seeToolSchema,
  clickToolHandler,
  clickToolSchema,
  typeToolHandler,
  typeToolSchema,
  scrollToolHandler,
  scrollToolSchema,
  hotkeyToolHandler,
  hotkeyToolSchema,
  swipeToolHandler,
  swipeToolSchema,
  runToolHandler,
  runToolSchema,
  sleepToolHandler,
  sleepToolSchema,
  cleanToolHandler,
  cleanToolSchema,
  agentToolHandler,
  agentToolSchema,
  appToolHandler,
  appToolSchema,
  windowToolHandler,
  windowToolSchema,
  menuToolHandler,
  menuToolSchema,
  permissionsToolHandler,
  permissionsToolSchema,
  moveToolHandler,
  moveToolSchema,
  dragToolHandler,
  dragToolSchema,
  dockToolHandler,
  dockToolSchema,
  dialogToolHandler,
  dialogToolSchema,
  spaceToolHandler,
  spaceToolSchema,
} from "./tools/index.js";
import { generateServerStatusString } from "./utils/server-status.js";
import { initializeSwiftCliPath } from "./utils/peekaboo-cli.js";
import { zodToJsonSchema } from "./utils/zod-to-json-schema.js";
import { setupEnvironmentFromCredentials, getAIProvidersConfig } from "./utils/config-loader.js";
import { ToolResponse, ImageInput } from "./types/index.js";
import { z } from "zod";

// Get package version and determine package root
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename); // This will be dist/
const packageRootDir = path.resolve(__dirname, ".."); // Server root for package.json
const packageJsonPath = path.join(packageRootDir, "package.json");
const packageJson = JSON.parse(await fs.readFile(packageJsonPath, "utf-8"));
const SERVER_VERSION = packageJson.version;

// Initialize the Swift CLI Path once
// When installed via npm, the peekaboo binary is in the package root (Server/)
initializeSwiftCliPath(packageRootDir);

// No longer need to track initial status display

// Initialize logger with fallback support
const baseLogLevel = (process.env.PEEKABOO_LOG_LEVEL || "info").toLowerCase();
const defaultLogPath = path.join(os.homedir(), "Library/Logs/peekaboo-mcp.log");
const fallbackLogPath = path.join(os.tmpdir(), "peekaboo-mcp.log");
let logFile = process.env.PEEKABOO_LOG_FILE || defaultLogPath;

// Test if the log directory is writable
const logDir = path.dirname(logFile);
try {
  // Try to create the directory if it doesn't exist
  await fs.mkdir(logDir, { recursive: true });
  // Test write access by creating a temp file
  const testFile = path.join(logDir, `.peekaboo-test-${Date.now()}`);
  await fs.writeFile(testFile, "test");
  await fs.unlink(testFile);
} catch (_error) {
  // If we can't write to the configured/default location, fall back to temp directory
  if (logFile !== fallbackLogPath) {
    logFile = fallbackLogPath;
    // We'll log this error after the logger is initialized
  }
}

const transportTargets = [];

// Always add file transport
transportTargets.push({
  level: baseLogLevel, // Explicitly set level for this transport
  target: "pino/file",
  options: {
    destination: logFile,
    mkdir: true, // Ensure the directory exists
  },
});

// Conditional console logging for development
if (process.env.PEEKABOO_CONSOLE_LOGGING === "true") {
  transportTargets.push({
    level: baseLogLevel, // Explicitly set level for this transport
    target: "pino-pretty",
    options: {
      destination: 2, // stderr
      colorize: true,
      translateTime: "SYS:standard", // More standard time format
      ignore: "pid,hostname",
    },
  });
}

const logger = pino(
  {
    name: "peekaboo-mcp",
    level: baseLogLevel, // Overall minimum level
  },
  pino.transport({ targets: transportTargets }),
);

// Tool context for handlers
const toolContext = { logger };

// Create MCP server using the low-level API
const server = new Server(
  {
    name: "peekaboo-mcp",
    version: SERVER_VERSION,
  },
  {
    capabilities: {
      tools: {},
    },
  },
);

// Set up request handlers
server.setRequestHandler(ListToolsRequestSchema, async () => {
  // Generate server status string to append to tool descriptions
  const serverStatus = generateServerStatusString(SERVER_VERSION);
  const statusSuffix = `\n${serverStatus}`;

  return {
    tools: [
      {
        name: "image",
        title: "Capture and Analyze Screen Content",
        description: `Captures macOS screen content and optionally analyzes it. \
Targets can be entire screen, specific app window, or all windows of an app (via app_target). \
Supports foreground/background capture. Output via file path or inline Base64 data (format: "data"). \
If a question is provided, image is analyzed by an AI model (auto-selected from PEEKABOO_AI_PROVIDERS). \
Window shadows/frames excluded. ${serverStatus}`,
        inputSchema: zodToJsonSchema(imageToolSchema),
      },
      {
        name: "analyze",
        title: "Analyze Image with AI",
        description:
`Analyzes a pre-existing image file from the local filesystem using a configured AI model.

This tool is useful when an image already exists (e.g., previously captured, downloaded, or generated) and you 
need to understand its content, extract text, or answer specific questions about it.

Capabilities:
- Image Understanding: Provide any question about the image (e.g., "What objects are in this picture?", 
  "Describe the scene.", "Is there a red car?").
- Text Extraction (OCR): Ask the AI to extract text from the image (e.g., "What text is visible in this screenshot?").
- Flexible AI Configuration: Can use server-default AI providers/models or specify a particular one per call 
  via 'provider_config'.

Example:
If you have an image '/tmp/chart.png' showing a bar chart, you could ask:
{ "image_path": "/tmp/chart.png", "question": "Which category has the highest value in this bar chart?" }
The AI will analyze the image and attempt to answer your question based on its visual content.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(analyzeToolSchema),
      },
      {
        name: "list",
        title: "List System Items",
        description:
`Lists various system items on macOS, providing situational awareness.

Capabilities:
- Running Applications: Get a list of all currently running applications (names and bundle IDs).
- Application Windows: For a specific application (identified by name or bundle ID), list its open windows.
  - Details: Optionally include window IDs, bounds (position and size), and whether a window is off-screen.
  - Multi-window apps: Clearly lists each window of the target app.
- Server Status: Provides information about the Peekaboo MCP server itself (version, configured AI providers).

Use Cases:
- Agent needs to know if 'Photoshop' is running before attempting to automate it.
  { "item_type": "running_applications" } // Agent checks if 'Photoshop' is in the list.
- Agent wants to find a specific 'Notes' window to capture.
  { "item_type": "application_windows", "app": "Notes", "include_window_details": ["ids", "bounds"] }
  The agent can then use the window title or ID with the 'image' tool.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(listToolSchema),
      },
      {
        name: "see",
        title: "See UI Elements",
        description:
`Captures a screenshot and analyzes UI elements for automation.
Returns UI element map with Peekaboo IDs (B1 for buttons, T1 for text fields, etc.) 
that can be used with interaction commands.
Creates or updates a session for tracking UI state across multiple commands.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(seeToolSchema),
      },
      {
        name: "click",
        title: "Click UI Elements",
        description:
`Clicks on UI elements or coordinates.
Supports element queries, specific IDs from see command, or raw coordinates.
Includes smart waiting for elements to become actionable.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(clickToolSchema),
      },
      {
        name: "type",
        title: "Type Text",
        description:
`Types text into UI elements or at current focus.
Supports special keys ({return}, {tab}, etc.) and configurable typing speed.
Can target specific elements or type at current keyboard focus.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(typeToolSchema),
      },
      {
        name: "scroll",
        title: "Scroll Content",
        description:
`Scrolls the mouse wheel in any direction.
Can target specific elements or scroll at current mouse position.
Supports smooth scrolling and configurable speed.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(scrollToolSchema),
      },
      {
        name: "hotkey",
        title: "Press Keyboard Shortcuts",
        description:
`Presses keyboard shortcuts and key combinations.
Simulates pressing multiple keys simultaneously like Cmd+C or Ctrl+Shift+T.
Keys are pressed in order and released in reverse order.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(hotkeyToolSchema),
      },
      {
        name: "swipe",
        title: "Swipe/Drag Gesture",
        description:
`Performs a swipe/drag gesture from one point to another.
Useful for dragging elements, swiping through content, or gesture-based interactions.
Creates smooth movement with configurable duration.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(swipeToolSchema),
      },
      {
        name: "run",
        title: "Run Automation Script",
        description:
`Runs a batch script of Peekaboo commands from a .peekaboo.json file.
Scripts can automate complex UI workflows by chaining commands.
Each command runs sequentially with shared session state.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(runToolSchema),
      },
      {
        name: "sleep",
        title: "Pause Execution",
        description:
`Pauses execution for a specified duration.
Useful for waiting between UI actions or allowing animations to complete.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(sleepToolSchema),
      },
      {
        name: "clean",
        title: "Clean Session Cache",
        description:
`Cleans up session cache and temporary files.
Sessions are stored in ~/.peekaboo/session/<PID>/ directories.
Use this to free up disk space and remove orphaned session data.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(cleanToolSchema),
      },
      {
        name: "app",
        title: "Application Control",
        description:
`Control applications - launch, quit, relaunch, focus, hide, unhide, and switch between apps.

Actions:
- launch: Start an application
- quit: Quit an application (with optional force flag)
- relaunch: Quit and restart an application (with configurable wait time)
- focus/switch: Bring an application to the foreground
- hide: Hide an application
- unhide: Show a hidden application

Target applications by name (e.g., "Safari"), bundle ID (e.g., "com.apple.Safari"), 
or process ID (e.g., "PID:663"). Fuzzy matching is supported for application names.

Examples:
- Launch Safari: { "action": "launch", "name": "Safari" }
- Quit TextEdit: { "action": "quit", "name": "TextEdit" }
- Relaunch Chrome: { "action": "relaunch", "name": "Google Chrome", "wait": 3 }
- Focus Terminal: { "action": "focus", "name": "Terminal" }` +
          statusSuffix,
        inputSchema: zodToJsonSchema(appToolSchema),
      },
      {
        name: "window",
        title: "Window Management",
        description:
`Manipulate application windows - close, minimize, maximize, move, resize, and focus.

Actions:
- close: Close a window
- minimize: Minimize a window
- maximize: Maximize a window  
- move: Move a window to specific coordinates (requires x, y)
- resize: Resize a window to specific dimensions (requires width, height)
- focus: Bring a window to the foreground

Target windows by application name and optionally by window title or index.
Supports partial title matching for convenience.

Examples:
- Close Safari window: { "action": "close", "app": "Safari" }
- Move window: { "action": "move", "app": "TextEdit", "x": 100, "y": 100 }
- Resize window: { "action": "resize", "app": "Terminal", "width": 800, "height": 600 }` +
          statusSuffix,
        inputSchema: zodToJsonSchema(windowToolSchema),
      },
      {
        name: "menu",
        title: "Menu Interaction",
        description:
`Interact with application menu bars - list available menus or click menu items.

Actions:
- list: Discover all available menus and menu items for an application
- click: Click on a specific menu item using path notation

Menu paths use ">" separator (e.g., "File > Save As..." or "Edit > Copy").
Use plain ellipsis "..." instead of Unicode "…" in menu paths.

Examples:
- List Chrome menus: { "action": "list", "app": "Google Chrome" }
- Save document: { "action": "click", "app": "TextEdit", "path": "File > Save" }
- Copy selection: { "action": "click", "app": "Safari", "path": "Edit > Copy" }` +
          statusSuffix,
        inputSchema: zodToJsonSchema(menuToolSchema),
      },
      {
        name: "agent",
        title: "AI Agent Task Execution",
        description:
`Execute complex automation tasks using an AI agent powered by OpenAI's Assistants API.
The agent can understand natural language instructions and break them down into specific 
Peekaboo commands to accomplish complex workflows.

Capabilities:
- Natural Language Processing: Understands tasks described in plain English
- Multi-step Automation: Breaks complex tasks into sequential steps
- Visual Feedback: Can take screenshots to verify results
- Context Awareness: Maintains session state across multiple actions
- Error Recovery: Can adapt and retry when actions fail

The agent has access to all Peekaboo automation tools including:
- Screen capture and analysis
- UI element interaction (click, type, scroll)
- Application control (launch, quit, focus)
- Window management (move, resize, close)
- System interaction (hotkeys, shell commands)

Example tasks:
- "Open Safari and navigate to apple.com"
- "Take a screenshot of the current window and save it to Desktop"
- "Find the login button and click it, then type my credentials"
- "Open TextEdit, write 'Hello World', and save the document"

Requires OPENAI_API_KEY environment variable to be set.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(agentToolSchema),
      },
      {
        name: "permissions",
        title: "Check System Permissions",
        description:
`Check macOS system permissions required for automation.
Verifies both Screen Recording and Accessibility permissions.
Returns the current permission status for each required permission.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(permissionsToolSchema),
      },
      {
        name: "move",
        title: "Move Mouse Cursor",
        description:
`Move the mouse cursor to a specific position or UI element.
Supports absolute coordinates, UI element targeting, or centering on screen.
Can animate movement smoothly over a specified duration.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(moveToolSchema),
      },
      {
        name: "drag",
        title: "Drag and Drop",
        description:
`Perform drag and drop operations between UI elements or coordinates.
Supports element queries, specific IDs, or raw coordinates for both start and end points.
Includes focus options for handling windows in different spaces.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(dragToolSchema),
      },
      {
        name: "dock",
        title: "Dock Interaction",
        description:
`Interact with the macOS Dock - launch apps, show context menus, hide/show dock.
Actions: launch, right-click (with menu selection), hide, show, list
Can list all dock items including persistent and running applications.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(dockToolSchema),
      },
      {
        name: "dialog",
        title: "System Dialog Interaction",
        description:
`Interact with system dialogs and alerts.
Actions: click buttons, input text, select files, dismiss dialogs, list open dialogs.
Handles save/open dialogs, alerts, and other system prompts.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(dialogToolSchema),
      },
      {
        name: "space",
        title: "macOS Spaces Management",
        description:
`Manage macOS Spaces (virtual desktops).
Actions: list spaces, switch to a specific space, move windows between spaces.
Supports moving windows with optional follow behavior to switch along with the window.` +
          statusSuffix,
        inputSchema: zodToJsonSchema(spaceToolSchema),
      },
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  logger.debug({ toolName: name, args }, "Tool call received");

  let response: ToolResponse; // To store the raw response from tool handlers

  try {
    switch (name) {
      case "image": {
        // Store original format before validation
        const originalFormat = (args as Record<string, unknown>)?.format;
        const validatedArgs = imageToolSchema.parse(args || {});

        // Check if format was corrected
        if (originalFormat && typeof originalFormat === "string") {
          const normalizedOriginal = originalFormat.toLowerCase();
          const validFormats = ["png", "jpg", "jpeg", "data"];
          if (!validFormats.includes(normalizedOriginal) && validatedArgs.format === "png") {
            // Format was corrected, add the original format to the validated args
            (validatedArgs as ImageInput & { _originalFormat?: string })._originalFormat = originalFormat;
          }
        }

        response = await imageToolHandler(validatedArgs, toolContext);
        break;
      }
      case "analyze": {
        const validatedArgs = analyzeToolSchema.parse(args || {});
        response = await analyzeToolHandler(validatedArgs, toolContext);
        break;
      }
      case "list": {
        const validatedArgs = listToolSchema.parse(args || {});
        response = await listToolHandler(validatedArgs, toolContext);
        break;
      }
      case "see": {
        const validatedArgs = seeToolSchema.parse(args || {});
        response = await seeToolHandler(validatedArgs, toolContext);
        break;
      }
      case "click": {
        const validatedArgs = clickToolSchema.parse(args || {});
        response = await clickToolHandler(validatedArgs, toolContext);
        break;
      }
      case "type": {
        const validatedArgs = typeToolSchema.parse(args || {});
        response = await typeToolHandler(validatedArgs, toolContext);
        break;
      }
      case "scroll": {
        const validatedArgs = scrollToolSchema.parse(args || {});
        response = await scrollToolHandler(validatedArgs, toolContext);
        break;
      }
      case "hotkey": {
        const validatedArgs = hotkeyToolSchema.parse(args || {});
        response = await hotkeyToolHandler(validatedArgs, toolContext);
        break;
      }
      case "swipe": {
        const validatedArgs = swipeToolSchema.parse(args || {});
        response = await swipeToolHandler(validatedArgs, toolContext);
        break;
      }
      case "run": {
        const validatedArgs = runToolSchema.parse(args || {});
        response = await runToolHandler(validatedArgs, toolContext);
        break;
      }
      case "sleep": {
        const validatedArgs = sleepToolSchema.parse(args || {});
        response = await sleepToolHandler(validatedArgs, toolContext);
        break;
      }
      case "clean": {
        const validatedArgs = cleanToolSchema.parse(args || {});
        response = await cleanToolHandler(validatedArgs, toolContext);
        break;
      }
      case "agent": {
        const validatedArgs = agentToolSchema.parse(args || {});
        response = await agentToolHandler(validatedArgs, toolContext);
        break;
      }
      case "app": {
        const validatedArgs = appToolSchema.parse(args || {});
        response = await appToolHandler(validatedArgs, toolContext);
        break;
      }
      case "window": {
        const validatedArgs = windowToolSchema.parse(args || {});
        response = await windowToolHandler(validatedArgs, toolContext);
        break;
      }
      case "menu": {
        const validatedArgs = menuToolSchema.parse(args || {});
        response = await menuToolHandler(validatedArgs, toolContext);
        break;
      }
      case "permissions": {
        const validatedArgs = permissionsToolSchema.parse(args || {});
        response = await permissionsToolHandler(validatedArgs, toolContext);
        break;
      }
      case "move": {
        const validatedArgs = moveToolSchema.parse(args || {});
        response = await moveToolHandler(validatedArgs, toolContext);
        break;
      }
      case "drag": {
        const validatedArgs = dragToolSchema.parse(args || {});
        response = await dragToolHandler(validatedArgs, toolContext);
        break;
      }
      case "dock": {
        const validatedArgs = dockToolSchema.parse(args || {});
        response = await dockToolHandler(validatedArgs, toolContext);
        break;
      }
      case "dialog": {
        const validatedArgs = dialogToolSchema.parse(args || {});
        response = await dialogToolHandler(validatedArgs, toolContext);
        break;
      }
      case "space": {
        const validatedArgs = spaceToolSchema.parse(args || {});
        response = await spaceToolHandler(validatedArgs, toolContext);
        break;
      }
      default:
        response = {
          content: [{ type: "text", text: `Unknown tool: ${name}` }],
          isError: true,
        };
        logger.error(`Unknown tool: ${name}`);
    }

    return response;
  } catch (error) {
    logger.error({ error, toolName: name }, "Tool execution failed");

    // If it's a Zod validation error, return a more helpful message
    if (error && typeof error === "object" && "issues" in error) {
      return {
        content: [
          {
            type: "text" as const,
            text: `Invalid arguments: ${(error as z.ZodError).issues.map((issue) => issue.message).join(", ")}`,
          },
        ],
        isError: true,
      } as ToolResponse;
    }

    // For any other error, return a proper error response instead of throwing
    return {
      content: [
        {
          type: "text" as const,
          text: `Tool execution failed: ${error instanceof Error ? error.message : String(error)}`,
        },
      ],
      isError: true,
    } as ToolResponse;
  }
});

async function main() {
  try {
    // Load credentials and config before starting the server
    await setupEnvironmentFromCredentials(logger);
    
    // Set up AI providers from config if not already in environment
    const aiProviders = await getAIProvidersConfig(logger);
    if (aiProviders && !process.env.PEEKABOO_AI_PROVIDERS) {
      process.env.PEEKABOO_AI_PROVIDERS = aiProviders;
      logger.info({ providers: aiProviders }, "Loaded AI providers from config file");
    }
    
    // Create transport and connect
    const transport = new StdioServerTransport();
    await server.connect(transport);

    logger.info("Peekaboo MCP Server started successfully");
    logger.info("🔥 Hot-reload test: Server restarted at " + new Date().toISOString());
  } catch (error) {
    logger.error({ error }, "Failed to start server");
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on("SIGTERM", async () => {
  logger.info("SIGTERM received, shutting down gracefully");
  try {
    await server.close();
    logger.flush();
  } catch (e) {
    logger.error({ error: e }, "Error during server close on SIGTERM");
  }
  process.exit(0);
});

process.on("SIGINT", async () => {
  logger.info("SIGINT received, shutting down gracefully");
  try {
    await server.close();
    logger.flush();
  } catch (e) {
    logger.error({ error: e }, "Error during server close on SIGINT");
  }
  process.exit(0);
});

main().catch((error) => {
  logger.error({ error }, "Fatal error in main");
  process.exit(1);
});
