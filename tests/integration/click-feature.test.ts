import { describe, it, expect, beforeAll, afterEach } from 'vitest';
import { execSync } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';

const PEEKABOO_PATH = path.join(__dirname, '../../peekaboo');
const TEST_TIMEOUT = 30000; // 30 seconds

// Click integration tests disabled by default to prevent unintended UI interactions
// These tests actually click on UI elements and interact with TextEdit when run in full mode
describe.skipIf(globalThis.shouldSkipFullTests)('[full] Click Feature Integration Tests', () => {
  let sessionId: string;
  let textEditAvailable = false;

  beforeAll(() => {
    // Ensure peekaboo binary exists
    if (!fs.existsSync(PEEKABOO_PATH)) {
      throw new Error(`Peekaboo binary not found at ${PEEKABOO_PATH}. Run 'npm run build:all' first.`);
    }

    // Check if TextEdit is available
    try {
      const listOutput = execSync(`${PEEKABOO_PATH} list apps --json-output`, { encoding: 'utf-8' });
      const listResult = JSON.parse(listOutput);
      textEditAvailable = listResult.data.applications.some((app: any) => 
        app.name === 'TextEdit' || app.bundle_id === 'com.apple.TextEdit'
      );
    } catch (error) {
      textEditAvailable = false;
    }

    // Clean any old sessions
    try {
      execSync(`${PEEKABOO_PATH} clean --all --json-output`, { encoding: 'utf-8' });
    } catch (error) {
      // Ignore errors from clean command
    }
  });

  afterEach(() => {
    // Clean up after each test
    if (sessionId) {
      try {
        execSync(`${PEEKABOO_PATH} clean --session ${sessionId} --json-output`, { encoding: 'utf-8' });
      } catch (error) {
        // Ignore cleanup errors
      }
    }
  });

  describe('Basic Click Operations', () => {
    it('should click on element by ID', async () => {
      if (!textEditAvailable) {
        console.log('TextEdit not available, skipping test');
        return;
      }
      
      // Create a session with TextEdit
      if (!textEditAvailable) {
        console.log('TextEdit not available, skipping test');
        return;
      }
      
      const seeOutput = execSync(`${PEEKABOO_PATH} see --app TextEdit --json-output`, { encoding: 'utf-8' });
      const seeResult = JSON.parse(seeOutput);
      expect(seeResult.success).toBe(true);
      sessionId = seeResult.data.session_id;

      // Find the first text field element
      const textElement = seeResult.data.ui_elements.find(el => el.role === 'AXTextArea' || el.role === 'AXTextField');
      expect(textElement).toBeDefined();

      // Click on text area
      const clickOutput = execSync(`${PEEKABOO_PATH} click --on ${textElement.id} --json-output`, { encoding: 'utf-8' });
      const clickResult = JSON.parse(clickOutput);

      expect(clickResult.success).toBe(true);
      expect(clickResult.data.clickedElement).toContain('TextArea');
      expect(clickResult.data.clickLocation).toHaveProperty('x');
      expect(clickResult.data.clickLocation).toHaveProperty('y');
    }, TEST_TIMEOUT);

    it('should click using text query', async () => {
      if (!textEditAvailable) {
        console.log('TextEdit not available, skipping test');
        return;
      }
      
      // Create a session
      if (!textEditAvailable) {
        console.log('TextEdit not available, skipping test');
        return;
      }
      
      const seeOutput = execSync(`${PEEKABOO_PATH} see --app TextEdit --json-output`, { encoding: 'utf-8' });
      const seeResult = JSON.parse(seeOutput);
      sessionId = seeResult.data.session_id;

      // Click on Bold checkbox using text query
      const clickOutput = execSync(`${PEEKABOO_PATH} click "Bold" --json-output`, { encoding: 'utf-8' });
      const clickResult = JSON.parse(clickOutput);

      expect(clickResult.success).toBe(true);
      expect(clickResult.data.clickedElement).toBeDefined();
    }, TEST_TIMEOUT);

    it('should click at specific coordinates', async () => {
      // Create a session
      if (!textEditAvailable) {
        console.log('TextEdit not available, skipping test');
        return;
      }
      
      const seeOutput = execSync(`${PEEKABOO_PATH} see --app TextEdit --json-output`, { encoding: 'utf-8' });
      const seeResult = JSON.parse(seeOutput);
      sessionId = seeResult.data.session_id;

      // Click at center of window
      const windowBounds = seeResult.data.window_bounds;
      const centerX = Math.floor(windowBounds[0] + windowBounds[2] / 2);
      const centerY = Math.floor(windowBounds[1] + windowBounds[3] / 2);

      const clickOutput = execSync(`${PEEKABOO_PATH} click --coords "${centerX},${centerY}" --json-output`, { encoding: 'utf-8' });
      const clickResult = JSON.parse(clickOutput);

      expect(clickResult.success).toBe(true);
      expect(clickResult.data.clickLocation.x).toBe(centerX);
      expect(clickResult.data.clickLocation.y).toBe(centerY);
    }, TEST_TIMEOUT);
  });

  describe('Advanced Click Operations', () => {
    it('should perform double-click', async () => {
      if (!textEditAvailable) {
        console.log('TextEdit not available, skipping test');
        return;
      }
      
      const seeOutput = execSync(`${PEEKABOO_PATH} see --app TextEdit --json-output`, { encoding: 'utf-8' });
      const seeResult = JSON.parse(seeOutput);
      sessionId = seeResult.data.session_id;
      
      // Find text element
      const textElement = seeResult.data.ui_elements.find(el => el.role === 'AXTextArea' || el.role === 'AXTextField');
      expect(textElement).toBeDefined();

      // First type some text
      execSync(`${PEEKABOO_PATH} type "DoubleClickTest" --json-output`);

      // Double-click on text area
      const clickOutput = execSync(`${PEEKABOO_PATH} click --on ${textElement.id} --double --json-output`, { encoding: 'utf-8' });
      const clickResult = JSON.parse(clickOutput);

      expect(clickResult.success).toBe(true);
      expect(clickResult.data.clickedElement).toContain('TextArea');
    }, TEST_TIMEOUT);

    it('should perform right-click', async () => {
      if (!textEditAvailable) {
        console.log('TextEdit not available, skipping test');
        return;
      }
      
      const seeOutput = execSync(`${PEEKABOO_PATH} see --app TextEdit --json-output`, { encoding: 'utf-8' });
      const seeResult = JSON.parse(seeOutput);
      sessionId = seeResult.data.session_id;
      
      // Find text element
      const textElement = seeResult.data.ui_elements.find(el => el.role === 'AXTextArea' || el.role === 'AXTextField');
      expect(textElement).toBeDefined();

      // Right-click on text area
      const clickOutput = execSync(`${PEEKABOO_PATH} click --on ${textElement.id} --right --json-output`, { encoding: 'utf-8' });
      const clickResult = JSON.parse(clickOutput);

      expect(clickResult.success).toBe(true);

      // Close context menu
      execSync(`${PEEKABOO_PATH} hotkey --keys escape --json-output`);
    }, TEST_TIMEOUT);

    it('should click with explicit session ID', async () => {
      if (!textEditAvailable) {
        console.log('TextEdit not available, skipping test');
        return;
      }
      
      const seeOutput = execSync(`${PEEKABOO_PATH} see --app TextEdit --json-output`, { encoding: 'utf-8' });
      const seeResult = JSON.parse(seeOutput);
      sessionId = seeResult.data.session_id;
      const windowTitle = seeResult.data.window_title.replace(/ /g, '_');

      // Click with explicit session ID
      const clickOutput = execSync(`${PEEKABOO_PATH} click --on ${windowTitle}_T1 --session ${sessionId} --json-output`, { encoding: 'utf-8' });
      const clickResult = JSON.parse(clickOutput);

      expect(clickResult.success).toBe(true);
      expect(clickResult.data.clickedElement).toContain('TextArea');
    }, TEST_TIMEOUT);
  });

  describe('Error Handling', () => {
    it('should fail when clicking non-existent element', async () => {
      if (!textEditAvailable) {
        console.log('TextEdit not available, skipping test');
        return;
      }
      
      const seeOutput = execSync(`${PEEKABOO_PATH} see --app TextEdit --json-output`, { encoding: 'utf-8' });
      const seeResult = JSON.parse(seeOutput);
      sessionId = seeResult.data.session_id;

      try {
        execSync(`${PEEKABOO_PATH} click --on NONEXISTENT --json-output`, { encoding: 'utf-8' });
        fail('Should have thrown an error');
      } catch (error: any) {
        const result = JSON.parse(error.stdout);
        expect(result.success).toBe(false);
        expect(result.error).toBeDefined();
        expect(result.error.message).toContain('not found');
      }
    });

    it('should fail with invalid coordinates', async () => {
      try {
        execSync(`${PEEKABOO_PATH} click --coords "invalid,coords" --json-output`, { encoding: 'utf-8' });
        fail('Should have thrown an error');
      } catch (error: any) {
        const result = JSON.parse(error.stdout);
        expect(result.success).toBe(false);
        expect(result.error).toBeDefined();
      }
    });

    it('should fail without any click target', async () => {
      try {
        execSync(`${PEEKABOO_PATH} click --json-output`, { encoding: 'utf-8' });
        fail('Should have thrown an error');
      } catch (error: any) {
        // When using --json-output, errors are returned as JSON
        const output = error.stdout || error.stderr;
        if (output.includes('{')) {
          const result = JSON.parse(output);
          expect(result.success).toBe(false);
          expect(result.error).toBeDefined();
          // Click command validates session first, then arguments
          // If there's a session, it might fail with argument validation
          expect(result.error.message).toMatch(/No valid session found|Session not found|ValidationError|Specify an element query/);
        } else {
          // Fallback for non-JSON error output
          expect(output).toContain('Error');
        }
      }
    });

    it('should fail with expired session', async () => {
      try {
        // Use a non-existent session ID with an arbitrary element ID
        execSync(`${PEEKABOO_PATH} click --on SomeWindow_T1 --session 99999-9999 --json-output`, { encoding: 'utf-8' });
        fail('Should have thrown an error');
      } catch (error: any) {
        const result = JSON.parse(error.stdout);
        expect(result.success).toBe(false);
        expect(result.error).toBeDefined();
      }
    });
  });

  describe('Click Performance', () => {
    it('should complete clicks within reasonable time', async () => {
      if (!textEditAvailable) {
        console.log('TextEdit not available, skipping test');
        return;
      }
      
      const seeOutput = execSync(`${PEEKABOO_PATH} see --app TextEdit --json-output`, { encoding: 'utf-8' });
      const seeResult = JSON.parse(seeOutput);
      sessionId = seeResult.data.session_id;
      
      // Find clickable elements (buttons, checkboxes, etc.)
      const clickableElements = seeResult.data.ui_elements.filter(el => 
        el.is_actionable && (el.role === 'AXButton' || el.role === 'AXCheckBox' || el.role === 'AXRadioButton')
      );
      
      // Ensure we have at least one element to click
      const elementToClick = clickableElements[0] || seeResult.data.ui_elements.find(el => el.is_actionable);
      expect(elementToClick).toBeDefined();

      const startTime = Date.now();
      
      // Perform 5 clicks on the same element
      for (let i = 0; i < 5; i++) {
        const clickOutput = execSync(`${PEEKABOO_PATH} click --on ${elementToClick.id} --json-output`, { encoding: 'utf-8' });
        const clickResult = JSON.parse(clickOutput);
        expect(clickResult.success).toBe(true);
      }

      const totalTime = Date.now() - startTime;
      const averageTime = totalTime / 5;

      // Each click should take less than 500ms on average
      expect(averageTime).toBeLessThan(500);
    }, TEST_TIMEOUT);
  });

  describe('Multi-Element Clicking', () => {
    it('should click on different UI element types', async () => {
      if (!textEditAvailable) {
        console.log('TextEdit not available, skipping test');
        return;
      }
      
      const seeOutput = execSync(`${PEEKABOO_PATH} see --app TextEdit --json-output`, { encoding: 'utf-8' });
      const seeResult = JSON.parse(seeOutput);
      sessionId = seeResult.data.session_id;

      // Test clicking on different element types
      const elementTypes = [
        { role: 'AXCheckBox', expectedCount: 4 }, // Bold, Italic, Underline, Strikethrough
        { role: 'AXButton', expectedCount: 1 },    // At least one button
        { role: 'AXTextArea', expectedCount: 1 }   // Main text area
      ];

      for (const elementType of elementTypes) {
        const elements = seeResult.data.ui_elements.filter(
          (el: any) => el.role === elementType.role && el.is_actionable
        );

        // Click on first element of this type if found
        if (elements.length > 0) {
          const clickOutput = execSync(`${PEEKABOO_PATH} click --on ${elements[0].id} --json-output`, { encoding: 'utf-8' });
          const clickResult = JSON.parse(clickOutput);
          expect(clickResult.success).toBe(true);
          expect(clickResult.data.clickedElement).toContain(elementType.role.substring(2)); // Remove 'AX' prefix
        }
      }
    }, TEST_TIMEOUT);

    it('should handle rapid sequential clicks', async () => {
      if (!textEditAvailable) {
        console.log('TextEdit not available, skipping test');
        return;
      }
      
      const seeOutput = execSync(`${PEEKABOO_PATH} see --app TextEdit --json-output`, { encoding: 'utf-8' });
      const seeResult = JSON.parse(seeOutput);
      sessionId = seeResult.data.session_id;
      const windowTitle = seeResult.data.window_title.replace(/ /g, '_');

      // Rapid clicks on checkboxes
      const checkboxIds = ['C1', 'C2', 'C3', 'C4'];
      const results = [];

      for (const id of checkboxIds) {
        try {
          const clickOutput = execSync(`${PEEKABOO_PATH} click --on ${windowTitle}_${id} --json-output`, { encoding: 'utf-8' });
          const clickResult = JSON.parse(clickOutput);
          results.push(clickResult);
        } catch (error) {
          // Some checkboxes might not exist, that's okay
        }
      }

      // At least some clicks should succeed
      const successfulClicks = results.filter(r => r.success);
      expect(successfulClicks.length).toBeGreaterThan(0);
    }, TEST_TIMEOUT);
  });
});