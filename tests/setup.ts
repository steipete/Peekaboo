// Vitest setup file
// Configure global test environment

import { beforeEach, afterEach, vi } from 'vitest';

// Mock console methods to reduce noise during testing
const originalConsole = globalThis.console;

beforeEach(() => {
  // Reset console mocks before each test
  globalThis.console = {
    ...originalConsole,
    log: vi.fn(),
    error: vi.fn(),
    warn: vi.fn(),
    info: vi.fn(),
    debug: vi.fn(),
  };
});

afterEach(() => {
  // Restore original console after each test
  globalThis.console = originalConsole;
  vi.clearAllMocks();
});

// Mock environment variables for testing
process.env.NODE_ENV = "test";
process.env.PEEKABOO_AI_PROVIDERS = JSON.stringify([
  {
    type: "ollama",
    baseUrl: "http://localhost:11434",
    model: "llava",
    enabled: true,
  },
]);