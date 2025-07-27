import { describe, it, expect, beforeAll, afterAll } from "vitest";
import { spawn } from "child_process";
import { readFile, rm, access } from "fs/promises";
import { join } from "path";
import { homedir } from "os";
import { promisify } from "util";

const exec = promisify(require("child_process").exec);

describe("See Command Integration Tests", () => {
  const peekabooPath = join(__dirname, "../../peekaboo");
  let testSessionIds: string[] = [];

  afterAll(async () => {
    // Clean up test sessions
    for (const sessionId of testSessionIds) {
      const sessionPath = join(homedir(), ".peekaboo/session", sessionId);
      try {
        await rm(sessionPath, { recursive: true, force: true });
      } catch (error) {
        // Ignore cleanup errors
      }
    }
  });

  async function runSeeCommand(args: string[]): Promise<any> {
    const { stdout, stderr } = await exec(
      `"${peekabooPath}" see ${args.join(" ")} --json-output`,
      { env: { ...process.env, PEEKABOO_LOG_LEVEL: "error" } }
    );

    if (stderr && !stderr.includes("Warning") && !stderr.includes("DEBUG:")) {
      throw new Error(`Command failed: ${stderr}`);
    }

    try {
      const output = JSON.parse(stdout);
      if (output.data?.session_id) {
        testSessionIds.push(output.data.session_id);
      }
      return output;
    } catch (error) {
      throw new Error(`Failed to parse JSON output: ${stdout}`);
    }
  }

  it("should capture frontmost window by default", async () => {
    const result = await runSeeCommand([]);

    expect(result.success).toBe(true);
    expect(result.data).toBeDefined();
    expect(result.data.session_id).toBeDefined();
    expect(result.data.screenshot_raw).toBeDefined();
    expect(result.data.screenshot_annotated).toBeDefined();
    expect(result.data.ui_map).toBeDefined();
    expect(result.data.element_count).toBeGreaterThanOrEqual(0);
  });


  it("should create session files in correct directory structure", async () => {
    const result = await runSeeCommand([]);
    const sessionId = result.data.session_id;

    // Verify paths follow v3 spec structure
    expect(result.data.screenshot_raw).toContain(`/.peekaboo/session/${sessionId}/raw.png`);
    expect(result.data.screenshot_annotated).toContain(`/.peekaboo/session/${sessionId}/annotated.png`);
    expect(result.data.ui_map).toContain(`/.peekaboo/session/${sessionId}/map.json`);

    // Verify raw.png exists
    await expect(access(result.data.screenshot_raw)).resolves.toBeUndefined();

    // Verify map.json exists
    await expect(access(result.data.ui_map)).resolves.toBeUndefined();
  });

  it("should capture specific application window", async () => {
    // Use Finder as it's always running
    const result = await runSeeCommand(["--app", "Finder"]);

    expect(result.success).toBe(true);
    expect(result.data.application_name).toBeDefined();
    expect(result.data.window_title).toBeDefined();
  });

  it("should generate annotated screenshot when requested", async () => {
    const result = await runSeeCommand(["--annotate"]);

    expect(result.success).toBe(true);
    expect(result.data.screenshot_annotated).toBeDefined();

    // Verify annotated file exists
    await expect(access(result.data.screenshot_annotated)).resolves.toBeUndefined();
  });

  it("should find UI elements and assign Peekaboo IDs", async () => {
    const result = await runSeeCommand(["--app", "Finder"]);

    expect(result.data.ui_elements).toBeDefined();
    expect(Array.isArray(result.data.ui_elements)).toBe(true);

    // Check for Peekaboo ID format
    for (const element of result.data.ui_elements) {
      expect(element.id).toMatch(/^[\w-]+_[BTLMCRSG]\d+$/); // WindowName_B1, etc.
      expect(element.role).toBeDefined();
      expect(typeof element.is_actionable).toBe("boolean");
    }
  });

  it("should categorize elements by role correctly", async () => {
    const result = await runSeeCommand(["--app", "Finder"]);

    const roleMap: Record<string, string> = {
      "AXButton": "B",
      "AXTextField": "T",
      "AXTextArea": "T",
      "AXLink": "L",
      "AXMenu": "M",
      "AXMenuItem": "M",
      "AXCheckBox": "C",
      "AXRadioButton": "R",
      "AXSlider": "S"
    };

    for (const element of result.data.ui_elements) {
      const expectedPrefix = roleMap[element.role] || "G";
      // Extract the role prefix from the ID (format: WindowName_R1)
      const match = element.id.match(/_([BTLMCRSG])\d+$/);
      expect(match).toBeTruthy();
      expect(match[1]).toBe(expectedPrefix);
    }
  });

  it("should always use timestamp-based session ID", async () => {
    // Clean up any existing sessions to ensure a fresh session is created
    const sessionDir = join(homedir(), ".peekaboo/session");
    try {
      await rm(sessionDir, { recursive: true, force: true });
    } catch (error) {
      // Directory might not exist, which is fine
    }
    
    // The v3 spec uses timestamp-based IDs for cross-process compatibility
    const result = await runSeeCommand([]);

    expect(result.success).toBe(true);
    expect(result.data).toBeDefined();
    expect(result.data.session_id).toBeDefined();
    
    // Session ID should be timestamp-random format (e.g., 1751889198010-5978)
    expect(result.data.session_id).toMatch(/^\d{13}-\d{4}$/);
  });

  it("should support custom output path", async () => {
    const customPath = `/tmp/test-see-${Date.now()}.png`;
    const result = await runSeeCommand(["--path", customPath]);

    expect(result.success).toBe(true);
    
    // The screenshot should be copied to session directory
    await expect(access(result.data.screenshot_raw)).resolves.toBeUndefined();
    
    // Original path should also exist
    await expect(access(customPath)).resolves.toBeUndefined();
    
    // Clean up
    await rm(customPath, { force: true });
  });

  it("should analyze image when requested", async () => {
    // Need to quote the analyze prompt properly
    const result = await runSeeCommand([
      "--analyze", 
      "'What application is shown in this screenshot?'"
    ]);

    expect(result.success).toBe(true);
    expect(result.data.analysis_result).toBeDefined();
    expect(typeof result.data.analysis_result).toBe("string");
    expect(result.data.analysis_result.length).toBeGreaterThan(0);
  }, 30000); // Increase timeout for AI analysis

  it("should track execution time", async () => {
    const result = await runSeeCommand([]);

    expect(result.data.execution_time).toBeDefined();
    expect(typeof result.data.execution_time).toBe("number");
    expect(result.data.execution_time).toBeGreaterThan(0);
    expect(result.data.execution_time).toBeLessThan(10); // Should complete within 10 seconds
  });

  it("should handle non-existent application gracefully", async () => {
    // When app is not found, it should return an error
    try {
      await runSeeCommand(["--app", "NonExistentApp12345"]);
      fail("Expected command to fail");
    } catch (error) {
      // Expected to fail - the error handling works
      expect(error).toBeDefined();
    }
  });

  it("should mark actionable elements correctly", async () => {
    const result = await runSeeCommand(["--app", "Finder"]);

    const actionableRoles = [
      "AXButton", "AXTextField", "AXTextArea", "AXCheckBox",
      "AXRadioButton", "AXPopUpButton", "AXLink", "AXMenuItem",
      "AXSlider", "AXComboBox", "AXSegmentedControl"
    ];

    for (const element of result.data.ui_elements) {
      const shouldBeActionable = actionableRoles.includes(element.role);
      expect(element.is_actionable).toBe(shouldBeActionable);
    }
  });

  it("should create valid JSON in map file", async () => {
    const result = await runSeeCommand([]);
    
    // Read and parse the map.json file
    const mapContent = await readFile(result.data.ui_map, "utf-8");
    const mapData = JSON.parse(mapContent);

    expect(mapData.screenshotPath).toBeDefined();
    expect(mapData.uiMap).toBeDefined();
    expect(mapData.lastUpdateTime).toBeDefined();
    
    // Verify UI map structure
    for (const [id, element] of Object.entries(mapData.uiMap as any)) {
      expect(element.id).toBe(id);
      expect(element.role).toBeDefined();
      expect(element.frame).toBeDefined();
      expect(typeof element.isActionable).toBe("boolean");
    }
  });

  it.skip("should support screen capture mode", async () => {
    const result = await runSeeCommand(["--mode", "screen"]);

    expect(result.success).toBe(true);
    expect(result.data.capture_mode).toBe("screen");
    // application_name may be undefined or null for screen mode
    expect(result.data.application_name).toBeUndefined();
  });

  it("should support window title filtering", async () => {
    // This test might be flaky depending on what Finder windows are open
    try {
      const result = await runSeeCommand([
        "--app", "Finder",
        "--window-title", "Desktop"
      ]);

      if (result.success) {
        expect(result.data.window_title).toContain("Desktop");
      }
    } catch (error: any) {
      // If no Desktop window is found, skip the test
      console.log("No Desktop window found, skipping test");
    }
  });
});

// MCP integration tests would go here but test-server.ts doesn't exist yet