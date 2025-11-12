// LoggingHelpers.swift - Global logging functions for convenience and potential async offload.
// AXorcist - Created by Sendhil Panchadsaram

// This file previously contained @autoclosure versions of logging functions (axDebugLog, axInfoLog, etc.)
// which wrapped calls to GlobalAXLogger.shared.log within a Task for potential async behavior.

// As part of a refactoring to make AXorcist fully synchronous and rely on main-thread execution
// for all accessibility and logging operations, GlobalAXLogger was made synchronous.
// The global logging functions (axDebugLog, axInfoLog, etc.) are now directly defined
// as synchronous functions in GlobalAXLogger.swift, taking simple String messages.

// To resolve ambiguity between those synchronous String-based log functions and the
// @autoclosure versions previously in this file, the contents of this file have been removed.
// All logging calls should now resolve to the synchronous global functions in GlobalAXLogger.swift.
