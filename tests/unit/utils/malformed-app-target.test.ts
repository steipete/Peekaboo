import { describe, it, expect } from "vitest";
import { buildSwiftCliArgs } from "../../../src/utils/image-cli-args";

describe("Malformed App Target Parsing", () => {
  it("should handle multiple leading colons correctly", () => {
    const input = {
      app_target: "::::::::::::::::Finder",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    // Should not result in empty app name
    expect(args).toContain("--app");
    const appIndex = args.indexOf("--app");
    expect(args[appIndex + 1]).not.toBe("");
    
    // Should either treat as malformed and use multi mode, or properly extract "Finder"
    expect(args).toContain("--mode");
    const modeIndex = args.indexOf("--mode");
    const mode = args[modeIndex + 1];
    expect(["multi", "window"]).toContain(mode);
  });
  
  it("should handle empty parts between colons", () => {
    const input = {
      app_target: "::Chrome::WINDOW_TITLE::google.com",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    // Should not result in empty app name
    expect(args).toContain("--app");
    const appIndex = args.indexOf("--app");
    expect(args[appIndex + 1]).not.toBe("");
  });
  
  it("should handle app target that starts with colon", () => {
    const input = {
      app_target: ":Chrome",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    // Should handle gracefully, not create empty app name
    expect(args).toContain("--app");
    const appIndex = args.indexOf("--app");
    expect(args[appIndex + 1]).not.toBe("");
  });
  
  it("should handle app target that ends with colon", () => {
    const input = {
      app_target: "Chrome:",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    // Should treat as simple app name
    expect(args).toContain("--app");
    const appIndex = args.indexOf("--app");
    expect(args[appIndex + 1]).toBe("Chrome");
    
    expect(args).toContain("--mode");
    const modeIndex = args.indexOf("--mode");
    expect(args[modeIndex + 1]).toBe("multi");
  });
  
  it("should handle multiple consecutive colons in middle", () => {
    const input = {
      app_target: "Chrome:::WINDOW_TITLE:::google.com",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    expect(args).toContain("--app");
    const appIndex = args.indexOf("--app");
    expect(args[appIndex + 1]).toBe("Chrome");
    
    // Should handle the malformed specifier type gracefully
    expect(args).toContain("--mode");
  });
  
  it("should reject completely empty app target", () => {
    const input = {
      app_target: "",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    // Should default to screen mode for empty target
    expect(args).toContain("--mode");
    const modeIndex = args.indexOf("--mode");
    expect(args[modeIndex + 1]).toBe("screen");
    
    // Should not contain app argument
    expect(args).not.toContain("--app");
  });
  
  it("should handle only colons", () => {
    const input = {
      app_target: ":::::",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    // Should not result in empty app name being passed
    if (args.includes("--app")) {
      const appIndex = args.indexOf("--app");
      expect(args[appIndex + 1]).not.toBe("");
    }
  });
  
  it("should handle whitespace-only app names", () => {
    const input = {
      app_target: "   :WINDOW_TITLE:test",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    // Should handle whitespace-only app names
    if (args.includes("--app")) {
      const appIndex = args.indexOf("--app");
      const appName = args[appIndex + 1];
      expect(appName.trim()).not.toBe("");
    }
  });
  
  it("should demonstrate current behavior for debugging", () => {
    // This test documents what currently happens with the problematic input
    const input = {
      app_target: "::::::::::::::::Finder",
      format: "png" as const
    };
    
    const args = buildSwiftCliArgs(input, "/tmp/test.png");
    
    console.log("Args for '::::::::::::::::Finder':", args);
    
    // Document current behavior - this will help us verify the fix
    expect(args).toContain("--mode");
  });
});