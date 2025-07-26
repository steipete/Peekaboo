import { describe, it, expect, vi, beforeAll, afterAll, beforeEach } from "vitest";
import { spawn, ChildProcess } from "child_process";
import * as path from "path";
import { rm } from "fs/promises";
import { homedir } from "os";
import { join } from "path";

const SERVER_PATH = path.resolve(process.cwd(), "dist/index.js");

// Simple JSON-RPC client for testing
class JSONRPCClient {
  private proc: ChildProcess;
  private messageId = 1;
  private responseHandlers = new Map<number, (response: any) => void>();
  private buffer = "";

  constructor() {
    this.proc = spawn("node", [SERVER_PATH], {
      stdio: ["pipe", "pipe", "inherit"],
    });

    this.proc.stdout?.on("data", (data) => {
      this.buffer += data.toString();
      this.processBuffer();
    });
  }

  private processBuffer() {
    const lines = this.buffer.split("\n");
    this.buffer = lines.pop() || "";

    for (const line of lines) {
      if (line.trim()) {
        try {
          const message = JSON.parse(line);
          if (message.id && this.responseHandlers.has(message.id)) {
            const handler = this.responseHandlers.get(message.id)!;
            this.responseHandlers.delete(message.id);
            handler(message);
          }
        } catch (e) {
          // Ignore non-JSON lines
        }
      }
    }
  }

  async request(method: string, params: any = {}): Promise<any> {
    const id = this.messageId++;
    const request = {
      jsonrpc: "2.0",
      id,
      method,
      params,
    };

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.responseHandlers.delete(id);
        reject(new Error(`Request timeout for method: ${method}`));
      }, 10000); // Increased timeout to 10 seconds

      this.responseHandlers.set(id, (response) => {
        clearTimeout(timeout);
        if (response.error) {
          reject(response.error);
        } else {
          resolve(response.result);
        }
      });

      this.proc.stdin?.write(JSON.stringify(request) + "\n");
    });
  }

  close() {
    this.proc.kill();
  }
}

describe("MCP Spec v3 Tools", () => {
  let client: JSONRPCClient;

  beforeAll(() => {
    client = new JSONRPCClient();
  });

  afterAll(() => {
    client.close();
  });

  describe("tools/list", () => {
    it("should list all spec v3 tools", async () => {
      const result = await client.request("tools/list");
      
      expect(result.tools).toBeInstanceOf(Array);
      
      const toolNames = result.tools.map((t: any) => t.name);
      
      // Verify all new spec v3 tools are present
      expect(toolNames).toContain("see");
      expect(toolNames).toContain("click");
      expect(toolNames).toContain("type");
      expect(toolNames).toContain("scroll");
      expect(toolNames).toContain("hotkey");
      expect(toolNames).toContain("swipe");
      expect(toolNames).toContain("run");
      expect(toolNames).toContain("sleep");
      
      // Also verify existing tools are still there
      expect(toolNames).toContain("image");
      expect(toolNames).toContain("analyze");
      expect(toolNames).toContain("list");
    });

    it("should have proper descriptions for new tools", async () => {
      const result = await client.request("tools/list");
      const tools = result.tools;

      const seeToolInfo = tools.find((t: any) => t.name === "see");
      expect(seeToolInfo).toBeDefined();
      expect(seeToolInfo.title).toContain("UI");
      expect(seeToolInfo.description).toContain("screenshot");
      expect(seeToolInfo.description).toContain("element");

      const clickToolInfo = tools.find((t: any) => t.name === "click");
      expect(clickToolInfo).toBeDefined();
      expect(clickToolInfo.title).toContain("Click");
      expect(clickToolInfo.description).toContain("element");

      const typeToolInfo = tools.find((t: any) => t.name === "type");
      expect(typeToolInfo).toBeDefined();
      expect(typeToolInfo.title).toContain("Type");
      expect(typeToolInfo.description).toContain("text");
    });
  });

  describe("tool schemas", () => {
    it("should have valid schemas for all new tools", async () => {
      const result = await client.request("tools/list");
      const tools = result.tools;

      const expectedSchemas = {
        see: ["app_target", "path", "session", "annotate"],
        click: ["query", "on", "coords", "session", "wait_for", "double", "right"],
        type: ["text", "on", "session", "clear", "delay", "wait_for"],
        scroll: ["direction", "amount", "on", "session", "delay", "smooth"],
        hotkey: ["keys", "hold_duration"],
        swipe: ["from", "to", "duration", "steps"],
        run: ["script_path", "session", "stop_on_error", "timeout"],
        sleep: ["duration"]
      };

      for (const [toolName, expectedProps] of Object.entries(expectedSchemas)) {
        const toolInfo = tools.find((t: any) => t.name === toolName);
        expect(toolInfo).toBeDefined();
        expect(toolInfo.inputSchema).toBeDefined();
        expect(toolInfo.inputSchema.type).toBe("object");
        
        const properties = Object.keys(toolInfo.inputSchema.properties || {});
        for (const prop of expectedProps) {
          expect(properties).toContain(prop);
        }
      }
    });

    it("should have correct required fields", async () => {
      const result = await client.request("tools/list");
      const tools = result.tools;

      // Check required fields for key tools
      const typeToolInfo = tools.find((t: any) => t.name === "type");
      expect(typeToolInfo.inputSchema.required).toContain("text");

      const scrollToolInfo = tools.find((t: any) => t.name === "scroll");
      expect(scrollToolInfo.inputSchema.required).toContain("direction");

      const hotkeyToolInfo = tools.find((t: any) => t.name === "hotkey");
      expect(hotkeyToolInfo.inputSchema.required).toContain("keys");

      const sleepToolInfo = tools.find((t: any) => t.name === "sleep");
      expect(sleepToolInfo.inputSchema.required).toContain("duration");
    });
  });

  describe("tool execution", () => {
    it("should execute sleep tool", async () => {
      const startTime = Date.now();
      const result = await client.request("tools/call", {
        name: "sleep",
        arguments: { duration: 200 }
      });

      const duration = Date.now() - startTime;
      
      expect(result.content).toBeInstanceOf(Array);
      expect(result.content[0].type).toBe("text");
      expect(result.content[0].text).toContain("Paused");
      expect(duration).toBeGreaterThanOrEqual(200);
      expect(result.isError).toBeFalsy();
    });

    it("should validate tool arguments", async () => {
      // Test missing required argument
      const result = await client.request("tools/call", {
        name: "type",
        arguments: {} // Missing required 'text' field
      });

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Invalid arguments");
    });

    it("should handle see tool with minimal arguments", async () => {
      const result = await client.request("tools/call", {
        name: "see",
        arguments: {}
      });

      // The tool might fail due to permissions, but should at least be callable
      expect(result.content).toBeInstanceOf(Array);
      expect(result.content[0].type).toBe("text");
      
      // If it succeeds, verify the response format
      if (!result.isError) {
        expect(result._meta).toBeDefined();
        expect(result._meta.session_id).toBeTruthy();
      }
    });
  });

  describe("click tool validation", () => {
    beforeEach(async () => {
      // Clean up any existing sessions to ensure consistent test behavior
      const sessionDir = join(homedir(), ".peekaboo/session");
      try {
        await rm(sessionDir, { recursive: true, force: true });
      } catch (error) {
        // Directory might not exist, which is fine
      }
    });

    it("should require at least one target parameter", async () => {
      const result = await client.request("tools/call", {
        name: "click",
        arguments: {} // Missing query, on, or coords
      });

      expect(result.isError).toBe(true);
      expect(result.content[0].text).toContain("Must specify either");
    });

    it("should accept different target types", async () => {
      const targets = [
        { query: "Button", wait_for: 100 }, // Reduce wait time for tests
        { on: "B1", wait_for: 100 },
        { coords: "100,200", wait_for: 100 }
      ];

      for (const target of targets) {
        const result = await client.request("tools/call", {
          name: "click",
          arguments: target
        });

        // Should at least parse the arguments correctly
        expect(result.content).toBeInstanceOf(Array);
        // Will fail due to missing session or element, which is expected
        if (result.isError) {
          expect(result.content[0].text).toMatch(/session|Session|No actionable element found|UI element not found/);
        }
      }
    });
  });
});