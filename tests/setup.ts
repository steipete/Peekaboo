// Jest setup file
// Configure global test environment

// Mock console methods to reduce noise during testing
const originalConsole = global.console;

beforeEach(() => {
  // Reset console mocks before each test
  global.console = {
    ...originalConsole,
    log: jest.fn(),
    error: jest.fn(),
    warn: jest.fn(),
    info: jest.fn(),
    debug: jest.fn(),
  };
});

afterEach(() => {
  // Restore original console after each test
  global.console = originalConsole;
  jest.clearAllMocks();
});

// Global test timeout
jest.setTimeout(10000);

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
