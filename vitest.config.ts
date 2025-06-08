import { defineConfig } from "vitest/config";

// Helper function to determine if Swift binary is available
const isSwiftBinaryAvailable = () => {
  // On macOS, we expect the Swift binary to be available
  // On other platforms (like Linux), we skip Swift-dependent tests
  return process.platform === "darwin";
};

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    include: [
      "**/tests/unit/**/*.test.ts",
      // Include all integration tests
      "**/tests/integration/**/*.test.ts",
      // Only include E2E tests if running on macOS and not in CI
      ...(process.platform === "darwin" && !process.env.CI 
        ? ["peekaboo-cli/tests/e2e/**/*.test.ts"] 
        : []
      ),
    ],
    exclude: [
      "**/node_modules/**", 
      "**/dist/**",
      // Exclude E2E tests in CI or non-macOS environments
      ...(process.platform !== "darwin" || process.env.CI 
        ? ["peekaboo-cli/tests/e2e/**/*.test.ts"] 
        : []
      ),
    ],
    // Set reasonable timeouts to prevent hanging
    testTimeout: 60000, // 60 seconds for individual tests
    hookTimeout: 30000, // 30 seconds for setup/teardown hooks
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov", "html"],
      reportsDirectory: "./coverage",
      include: ["src/**/*.ts"],
      exclude: [
        "src/**/*.d.ts",
        "src/index.ts", // Assuming this is the main entry point
      ],
    },
    // Global setup for platform-specific test skipping
    setupFiles: ["./tests/setup.ts"],
    // alias: {
    //   '^(\.{1,2}/.*)\.js$': '$1',
    // },
  },
  // resolve: {
  //   alias: [
  //     { find: /^(\..*)\.js$/, replacement: '$1' },
  //   ],
  // },
});
