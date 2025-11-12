// SearchCriteriaUtils.swift - Utility functions for handling search criteria

import AppKit // For NSRunningApplication access
import ApplicationServices
import Foundation

// GlobalAXLogger is assumed available

// MARK: - Functions using undefined types (SearchCriteria, ProcessMatcherProtocol)

// These functions are commented out until the required types are defined

/*
 @MainActor
 public func evaluateElementAgainstCriteria(
     _ element: Element,
     criteria: SearchCriteria,
     appIdentifier: String?,
     processMatcher: ProcessMatcherProtocol
 ) -> (isMatch: Bool, logs: [AXLogEntry]) {
     var logs: [AXLogEntry] = [] // Changed from axDebugLog to aggregated logs

     // Check if the app identifier matches, if provided and different from current app
     if let criteriaAppIdentifier = criteria.appIdentifier,
        let currentAppIdentifier = appIdentifier,
        criteriaAppIdentifier != currentAppIdentifier
     {
         logs.append(AXLogEntry(
             level: .debug,
             message: "SearchCriteriaUtils: Element \(element.briefDescription(option: ValueFormatOption.smart)) " +
                      "app mismatch. Criteria wants '\(criteriaAppIdentifier)', " +
                      "current is '\(currentAppIdentifier)'. No match."
         ))
         return (false, logs) // Early exit if app ID doesn't match
     }

     // Check basic properties first (role, subrole, identifier, title, value using direct attribute calls)
     if let criteriaRole = criteria.role, element.role() != criteriaRole { // role() is sync
         logs.append(AXLogEntry(
             level: .debug,
             message: "SearchCriteriaUtils: Element \(element.briefDescription(option: ValueFormatOption.smart)) " +
                      "role mismatch. Expected '\(criteriaRole)', got '\(element.role() ?? "nil")'."
         ))
         return (false, logs)
     }

     // If all checks passed
     logs.append(AXLogEntry(
         level: .debug,
         message: "SearchCriteriaUtils: Element \(element.briefDescription(option: ValueFormatOption.smart)) " +
                  "matches all criteria for app '\(appIdentifier ?? "any")'."
     ))
     return (true, logs)
 }

 @MainActor
 public func elementMatchesAnyCriteria(
     _ element: Element,
     criteriaList: [SearchCriteria],
     appIdentifier: String?,
     processMatcher: ProcessMatcherProtocol
 ) -> (isMatch: Bool, logs: [AXLogEntry]) {
     var overallLogs: [AXLogEntry] = []
     for criteria in criteriaList {
         let result = evaluateElementAgainstCriteria(element, criteria: criteria, appIdentifier: appIdentifier, processMatcher: processMatcher)
         overallLogs.append(contentsOf: result.logs)
         if result.isMatch {
             overallLogs.append(AXLogEntry(
                 level: .debug,
                 message: "SearchCriteriaUtils: Element \(element.briefDescription(option: ValueFormatOption.smart)) " +
                          "matched one of the criteria for app '\(appIdentifier ?? "any")'."
             ))
             return (true, overallLogs)
         }
     }
     overallLogs.append(AXLogEntry(
         level: .debug,
         message: "SearchCriteriaUtils: Element \(element.briefDescription(option: ValueFormatOption.smart)) " +
                  "did not match any of the criteria for app '\(appIdentifier ?? "any")'."
     ))
     return (false, overallLogs)
 }
 */
