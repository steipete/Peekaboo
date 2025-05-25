import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    include: [
      "**/tests/unit/**/*.test.ts",
      "**/tests/integration/**/*.test.ts",
      "peekaboo-cli/tests/e2e/**/*.test.ts",
    ],
    exclude: ["**/node_modules/**", "**/dist/**"],
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
