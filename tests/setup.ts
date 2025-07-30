/**
 * Global test setup for platform-specific test skipping and test categorization
 * This file is loaded before all tests run
 */

// Make platform information available globally for tests
declare global {
  var isSwiftBinaryAvailable: boolean;
  var shouldSkipSwiftTests: boolean;
  var testMode: 'safe' | 'full';
  var shouldSkipFullTests: boolean;
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

// Determine test mode from environment
const getTestMode = (): 'safe' | 'full' => {
  const mode = process.env.PEEKABOO_TEST_MODE?.toLowerCase();
  return mode === 'full' ? 'full' : 'safe';
};

// Helper to determine if full tests should be skipped
const shouldSkipFullTests = () => {
  return getTestMode() !== 'full';
};

// Make these available globally
globalThis.isSwiftBinaryAvailable = isSwiftBinaryAvailable();
globalThis.shouldSkipSwiftTests = shouldSkipSwiftTests();
globalThis.testMode = getTestMode();
globalThis.shouldSkipFullTests = shouldSkipFullTests();

// Log platform and test mode information
console.log(`Test setup: Platform=${process.platform}, Swift available=${globalThis.isSwiftBinaryAvailable}, Skip Swift tests=${globalThis.shouldSkipSwiftTests}`);
console.log(`Test mode: ${globalThis.testMode} (set PEEKABOO_TEST_MODE=full to run all tests)`);

if (globalThis.shouldSkipFullTests) {
  console.log('⚠️  Running in SAFE mode - interactive/system-modifying tests will be skipped');
  console.log('   To run full test suite: npm run test:full');
}

