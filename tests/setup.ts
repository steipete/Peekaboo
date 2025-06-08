/**
 * Global test setup for platform-specific test skipping
 * This file is loaded before all tests run
 */

// Make platform information available globally for tests
declare global {
  var isSwiftBinaryAvailable: boolean;
  var shouldSkipSwiftTests: boolean;
}

// Helper function to determine if Swift binary is available
const isSwiftBinaryAvailable = () => {
  // On macOS, we expect the Swift binary to be available
  // On other platforms (like Linux), we skip Swift-dependent tests
  return process.platform === "darwin";
};

// Helper function to determine if we should skip Swift-dependent tests
const shouldSkipSwiftTests = () => {
  // Skip Swift tests if:
  // 1. Not on macOS (Swift binary not available)
  // 2. In CI environment (to avoid flaky tests)
  // 3. SKIP_SWIFT_TESTS environment variable is set
  return (
    process.platform !== "darwin" ||
    process.env.CI === "true" ||
    process.env.SKIP_SWIFT_TESTS === "true"
  );
};

// Make these available globally
globalThis.isSwiftBinaryAvailable = isSwiftBinaryAvailable();
globalThis.shouldSkipSwiftTests = shouldSkipSwiftTests();

// Log platform information for debugging
console.log(`Test setup: Platform=${process.platform}, Swift available=${globalThis.isSwiftBinaryAvailable}, Skip Swift tests=${globalThis.shouldSkipSwiftTests}`);

