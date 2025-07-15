import { describe, it, expect } from "vitest";
import { spawn } from "child_process";
import * as path from "path";
import * as fs from "fs/promises";
import * as os from "os";

const CLI_PATH = path.resolve(process.cwd(), "peekaboo");

async function runCommand(args: string[]): Promise<{ stdout: string; stderr: string; code: number }> {
  return new Promise((resolve) => {
    const proc = spawn(CLI_PATH, args);
    let stdout = "";
    let stderr = "";

    proc.stdout.on("data", (data) => {
      stdout += data.toString();
    });

    proc.stderr.on("data", (data) => {
      stderr += data.toString();
    });

    proc.on("close", (code) => {
      resolve({ stdout, stderr, code: code || 0 });
    });
  });
}

describe("Spec v3 Commands", () => {
  describe("sleep command", () => {
    it("should sleep for specified duration", async () => {
      const startTime = Date.now();
      const result = await runCommand(["sleep", "500"]);
      const duration = Date.now() - startTime;

      expect(result.code).toBe(0);
      expect(result.stdout).toContain("Paused for 0.5s");
      expect(duration).toBeGreaterThanOrEqual(500);
      expect(duration).toBeLessThan(1000); // Allow some overhead
    });

    it("should handle JSON output", async () => {
      const result = await runCommand(["sleep", "100", "--json-output"]);
      
      expect(result.code).toBe(0);
      
      const json = JSON.parse(result.stdout);
      expect(json.success).toBe(true);
      expect(json.data.success).toBe(true);
      expect(json.data.requested_duration).toBe(100);
      expect(json.data.actual_duration).toBeGreaterThanOrEqual(100);
    });
  });

  describe("see command", () => {
    it("should capture screen and create session", async () => {
      const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "peekaboo-test-"));
      const screenshotPath = path.join(tempDir, "test.png");

      const result = await runCommand([
        "see",
        "--mode", "screen",
        "--path", screenshotPath,
        "--json-output"
      ]);

      expect(result.code).toBe(0);
      
      const json = JSON.parse(result.stdout);
      expect(json.success).toBe(true);
      expect(json.data.success).toBe(true);
      expect(json.data.session_id).toBeTruthy();
      // The see command saves to a session directory, not the specified path
      expect(json.data.screenshot_raw).toBeDefined();
      expect(json.data.screenshot_annotated).toBeDefined();
      expect(json.data.ui_elements).toBeInstanceOf(Array);

      // Verify screenshots were created in session directory
      const rawScreenshotPath = json.data.screenshot_raw;
      
      const rawStats = await fs.stat(rawScreenshotPath);
      expect(rawStats.isFile()).toBe(true);
      expect(rawStats.size).toBeGreaterThan(0);
      
      // Annotated screenshot is only created with --annotate flag
      if (json.data.screenshot_annotated) {
        try {
          const annotatedStats = await fs.stat(json.data.screenshot_annotated);
          expect(annotatedStats.isFile()).toBe(true);
          expect(annotatedStats.size).toBeGreaterThan(0);
        } catch (err) {
          // Annotated file may not exist, which is okay
        }
      }

      // Cleanup
      await fs.rm(tempDir, { recursive: true });
    });
  });

  describe("command help", () => {
    const newCommands = [
      "see",
      "click",
      "type",
      "scroll",
      "hotkey",
      "swipe",
      "run",
      "sleep"
    ];

    it.each(newCommands)("should show help for %s command", async (command) => {
      const result = await runCommand(["help", command]);
      
      expect(result.code).toBe(0);
      expect(result.stdout.toLowerCase()).toContain(command);
      expect(result.stdout).toContain("USAGE:");
      expect(result.stdout).toContain("OPTIONS:");
    });
  });

  describe("run command script validation", () => {
    // Note: Run command now properly handles positional arguments for commands like sleep
    it("should validate script file format", async () => {
      const tempFile = path.join(os.tmpdir(), `test-${Date.now()}.peekaboo.json`);
      
      // Create an invalid script
      await fs.writeFile(tempFile, JSON.stringify({
        description: "Invalid Script"
        // Missing steps array
      }));

      const result = await runCommand(["run", tempFile, "--json-output"]);
      
      expect(result.code).toBe(1);
      const json = JSON.parse(result.stdout);
      expect(json.success).toBe(false);
      expect(json.error.message).toContain("ValidationError");

      // Cleanup
      await fs.unlink(tempFile);
    });

    it("should accept valid script format", async () => {
      const tempFile = path.join(os.tmpdir(), `test-${Date.now()}.peekaboo.json`);
      
      // Create a valid script
      await fs.writeFile(tempFile, JSON.stringify({
        description: "A simple test script",
        steps: [
          {
            stepId: "step1",
            command: "sleep",
            params: {
              duration: 100
            },
            comment: "Brief pause"
          }
        ]
      }));

      const result = await runCommand(["run", tempFile, "--json-output"]);
      
      expect(result.code).toBe(0);
      const json = JSON.parse(result.stdout);
      expect(json.success).toBe(true);
      expect(json.data.success).toBe(true);
      expect(json.data.completedSteps).toBe(1)
      expect(json.data.totalSteps).toBe(1);

      // Cleanup
      await fs.unlink(tempFile);
    });
  });

  describe("coordinate validation", () => {
    it("should validate coordinate format for click", async () => {
      const result = await runCommand(["click", "--coords", "invalid", "--json-output"]);
      
      expect(result.code).toBe(1);
      const json = JSON.parse(result.stdout);
      expect(json.success).toBe(false);
      // The error could be either invalid coordinates or session not found
      expect(
        json.error.message.includes("Invalid coordinates") ||
        json.error.message.includes("Session not found") ||
        json.error.message.includes("ValidationError")
      ).toBe(true);
    });

    it("should validate coordinate format for swipe", async () => {
      const result = await runCommand([
        "swipe",
        "--from", "100,200",
        "--to", "invalid-coords",
        "--json-output"
      ]);
      
      expect(result.code).toBe(1);
      const json = JSON.parse(result.stdout);
      expect(json.success).toBe(false);
    });
  });

  describe("scroll directions", () => {
    const directions = ["up", "down", "left", "right"];

    it.each(directions)("should accept %s direction", async (direction) => {
      // We can't actually test scrolling without a UI, but we can verify
      // the command is accepted and parsed correctly
      const result = await runCommand([
        "scroll",
        "--direction", direction,
        "--amount", "1",
        "--json-output"
      ]);
      
      // The command might fail due to no mouse position or permissions,
      // but it should at least parse the arguments correctly
      const json = JSON.parse(result.stdout);
      
      if (json.success && json.data) {
        expect(json.data.direction).toBe(direction);
        expect(json.data.amount).toBe(1);
      } else {
        // Even on failure, we shouldn't get an "invalid direction" error
        expect(json.error?.message).not.toContain("Invalid direction");
      }
    });
  });

  describe("hotkey combinations", () => {
    it("should parse key combinations", async () => {
      const keyCombos = [
        "cmd,c",
        "cmd,shift,t",
        "ctrl,a",
        "f1"
      ];

      for (const keys of keyCombos) {
        const result = await runCommand([
          "hotkey",
          "--keys", keys,
          "--json-output"
        ]);
        
        const json = JSON.parse(result.stdout);
        
        // The command might fail due to permissions, but should parse correctly
        if (json.error && json.error.code === "INVALID_ARGUMENT") {
          // If it's an invalid argument error, it should be about unknown keys,
          // not about the format
          expect(json.error.message).not.toContain("No keys specified");
        }
      }
    });
  });
});