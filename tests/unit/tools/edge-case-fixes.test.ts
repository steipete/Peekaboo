import { describe, it, expect } from "vitest";
import { imageToolSchema } from "../../../src/types/index";

describe("Edge Case Fixes", () => {
  describe("JSON null string handling", () => {
    it("should treat string 'null' as undefined path", () => {
      const input = { 
        format: "png", 
        path: "null" // JSON string "null" should be treated as undefined
      };
      
      const result = imageToolSchema.parse(input);
      
      // String "null" should be preprocessed to undefined
      expect(result.path).toBeUndefined();
    });
    
    it("should handle actual null values correctly", () => {
      const input = { 
        format: "png", 
        path: null
      };
      
      const result = imageToolSchema.parse(input);
      
      // Actual null should also become undefined
      expect(result.path).toBeUndefined();
    });
    
    it("should handle empty string correctly", () => {
      const input = { 
        format: "png", 
        path: ""
      };
      
      const result = imageToolSchema.parse(input);
      
      // Empty string should also become undefined
      expect(result.path).toBeUndefined();
    });
    
    it("should preserve valid path strings", () => {
      const input = { 
        format: "png", 
        path: "/tmp/test.png"
      };
      
      const result = imageToolSchema.parse(input);
      
      // Valid path should be preserved
      expect(result.path).toBe("/tmp/test.png");
    });
  });
  
  describe("Invalid screen index edge cases", () => {
    it("should handle app_target with invalid screen index", () => {
      const input = { 
        format: "png", 
        app_target: "screen:99"
      };
      
      const result = imageToolSchema.parse(input);
      
      // Should parse correctly - invalid index handling is done in Swift CLI
      expect(result.app_target).toBe("screen:99");
      expect(result.format).toBe("png");
    });
    
    it("should handle app_target with negative screen index", () => {
      const input = { 
        format: "png", 
        app_target: "screen:-1"
      };
      
      const result = imageToolSchema.parse(input);
      
      expect(result.app_target).toBe("screen:-1");
      expect(result.format).toBe("png");
    });
    
    it("should handle app_target with non-numeric screen index", () => {
      const input = { 
        format: "png", 
        app_target: "screen:abc"
      };
      
      const result = imageToolSchema.parse(input);
      
      expect(result.app_target).toBe("screen:abc");
      expect(result.format).toBe("png");
    });
  });
  
  describe("Combined edge cases", () => {
    it("should handle both null path and invalid screen index", () => {
      const input = { 
        format: "png", 
        app_target: "screen:99",
        path: "null"
      };
      
      const result = imageToolSchema.parse(input);
      
      expect(result.app_target).toBe("screen:99");
      expect(result.path).toBeUndefined();
      expect(result.format).toBe("png");
    });
  });
});