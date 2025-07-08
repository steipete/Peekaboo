import { describe, it, expect } from "vitest";
import { buildSwiftCliArgs } from "../../../Server/src/utils/image-cli-args";

describe("App Target Colon Parsing", () => {
  it("should correctly parse window title with URLs containing ports", () => {
    const input = {
      app_target: "Google Chrome:WINDOW_TITLE:http://example.com:8080",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    // Should contain the correct app name
    expect(args).toContain("--app");
    const appIndex = args.indexOf("--app");
    expect(args[appIndex + 1]).toBe("Google Chrome");
    
    // Should be in window mode
    expect(args).toContain("--mode");
    const modeIndex = args.indexOf("--mode");
    expect(args[modeIndex + 1]).toBe("window");
    
    // Should contain the window title argument with the full URL including port
    expect(args).toContain("--window-title");
    const titleIndex = args.indexOf("--window-title");
    expect(args[titleIndex + 1]).toBe("http://example.com:8080");
  });
  
  it("should handle URLs with multiple colons correctly", () => {
    const input = {
      app_target: "Safari:WINDOW_TITLE:https://user:pass@example.com:8443/path?param=value",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    expect(args).toContain("--window-title");
    const titleIndex = args.indexOf("--window-title");
    expect(args[titleIndex + 1]).toBe("https://user:pass@example.com:8443/path?param=value");
  });
  
  it("should handle window titles with colons in file paths", () => {
    const input = {
      app_target: "TextEdit:WINDOW_TITLE:C:\\Users\\test\\file.txt",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    expect(args).toContain("--window-title");
    const titleIndex = args.indexOf("--window-title");
    expect(args[titleIndex + 1]).toBe("C:\\Users\\test\\file.txt");
  });
  
  it("should handle simple window titles without additional colons", () => {
    const input = {
      app_target: "TextEdit:WINDOW_TITLE:My Document.txt",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    expect(args).toContain("--window-title");
    const titleIndex = args.indexOf("--window-title");
    expect(args[titleIndex + 1]).toBe("My Document.txt");
  });
  
  it("should handle window index correctly (no colons in value)", () => {
    const input = {
      app_target: "Google Chrome:WINDOW_INDEX:0",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    expect(args).toContain("--window-index");
    const indexIdx = args.indexOf("--window-index");
    expect(args[indexIdx + 1]).toBe("0");
  });
  
  it("should handle colons in app names gracefully", () => {
    // Edge case: what if app name itself contains colons?
    const input = {
      app_target: "App:Name:WINDOW_TITLE:Title",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    // This case is ambiguous - current logic takes first part as app name
    expect(args).toContain("--app");
    const appIndex = args.indexOf("--app");
    expect(args[appIndex + 1]).toBe("App");
    
    // "Name" is not a valid specifier, so no window-specific flags should be added
    // It should default to main window (no --window-title or --window-index flags)
    expect(args).not.toContain("--window-title");
    expect(args).not.toContain("--window-index");
    expect(args).toContain("--mode");
    const modeIndex = args.indexOf("--mode");
    expect(args[modeIndex + 1]).toBe("window");
  });
  
  it("should handle timestamp-like patterns in titles", () => {
    const input = {
      app_target: "Log Viewer:WINDOW_TITLE:2023-01-01 12:30:45",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    expect(args).toContain("--window-title");
    const titleIndex = args.indexOf("--window-title");
    expect(args[titleIndex + 1]).toBe("2023-01-01 12:30:45");
  });
});