//
//  ToolResultExtractor.swift
//  PeekabooCore
//

import Foundation

/// Utility for extracting values from tool results with support for wrapped values
public struct ToolResultExtractor {
    
    /// Extract a string value from result dictionary
    public static func string(_ key: String, from result: [String: Any]) -> String? {
        // Direct value
        if let value = result[key] as? String {
            return value
        }
        
        // Wrapped value {"type": "string", "value": "..."}
        if let wrapper = result[key] as? [String: Any],
           wrapper["type"] as? String == "string",
           let value = wrapper["value"] as? String {
            return value
        }
        
        return nil
    }
    
    /// Extract an integer value from result dictionary
    public static func int(_ key: String, from result: [String: Any]) -> Int? {
        // Direct value
        if let value = result[key] as? Int {
            return value
        }
        
        // Wrapped value {"type": "number", "value": 123}
        if let wrapper = result[key] as? [String: Any],
           wrapper["type"] as? String == "number",
           let value = wrapper["value"] as? Int {
            return value
        }
        
        // Try converting from Double
        if let doubleValue = double(key, from: result) {
            return Int(doubleValue)
        }
        
        return nil
    }
    
    /// Extract a double value from result dictionary
    public static func double(_ key: String, from result: [String: Any]) -> Double? {
        // Direct value
        if let value = result[key] as? Double {
            return value
        }
        
        if let value = result[key] as? Int {
            return Double(value)
        }
        
        // Wrapped value
        if let wrapper = result[key] as? [String: Any],
           wrapper["type"] as? String == "number" {
            if let value = wrapper["value"] as? Double {
                return value
            }
            if let value = wrapper["value"] as? Int {
                return Double(value)
            }
        }
        
        return nil
    }
    
    /// Extract a boolean value from result dictionary
    public static func bool(_ key: String, from result: [String: Any]) -> Bool? {
        // Direct value
        if let value = result[key] as? Bool {
            return value
        }
        
        // Wrapped value
        if let wrapper = result[key] as? [String: Any],
           wrapper["type"] as? String == "boolean",
           let value = wrapper["value"] as? Bool {
            return value
        }
        
        return nil
    }
    
    /// Extract an array value from result dictionary
    public static func array(_ key: String, from result: [String: Any]) -> [Any]? {
        // Direct value
        if let value = result[key] as? [Any] {
            return value
        }
        
        // Wrapped value
        if let wrapper = result[key] as? [String: Any],
           wrapper["type"] as? String == "array",
           let value = wrapper["value"] as? [Any] {
            return value
        }
        
        return nil
    }
    
    /// Extract a dictionary value from result dictionary
    public static func dictionary(_ key: String, from result: [String: Any]) -> [String: Any]? {
        // Direct value
        if let value = result[key] as? [String: Any] {
            return value
        }
        
        // Wrapped value
        if let wrapper = result[key] as? [String: Any],
           wrapper["type"] as? String == "object",
           let value = wrapper["value"] as? [String: Any] {
            return value
        }
        
        return nil
    }
    
    /// Unwrap a result that might be wrapped
    public static func unwrap(_ result: [String: Any]) -> [String: Any] {
        // Check if this is a wrapped result
        if result["type"] as? String == "object",
           let value = result["value"] as? [String: Any] {
            return value
        }
        
        // Already unwrapped
        return result
    }
    
    /// Get count from various result formats
    public static func extractCount(from result: [String: Any], arrayKey: String? = nil) -> Int? {
        // Direct count field
        if let count = int("count", from: result) {
            return count
        }
        
        // Count from specific array
        if let arrayKey = arrayKey,
           let array = array(arrayKey, from: result) {
            return array.count
        }
        
        // Try common array field names
        let commonArrayKeys = ["items", "elements", "windows", "apps", "applications", "menus", "spaces", "screens"]
        for key in commonArrayKeys {
            if let array = array(key, from: result) {
                return array.count
            }
        }
        
        return nil
    }
}