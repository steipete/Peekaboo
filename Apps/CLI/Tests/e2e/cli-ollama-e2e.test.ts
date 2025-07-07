import * as child_process from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { describe, test, expect, beforeAll, afterAll } from 'vitest';

// Helper function to run AppleScript
const runAppleScript = (script: string): Promise<string> => {
  return new Promise((resolve, reject) => {
    const osaScript = child_process.spawn('osascript', ['-e', script]);
    let stdout = '';
    let stderr = '';
    osaScript.stdout.on('data', (data) => (stdout += data.toString()));
    osaScript.stderr.on('data', (data) => (stderr += data.toString()));
    osaScript.on('close', (code) => {
      if (code === 0) {
        resolve(stdout.trim());
      } else {
        reject(new Error(`AppleScript failed with code ${code}: ${stderr}`));
      }
    });
  });
};

// Helper function to run Peekaboo CLI commands
const runPeekabooCli = (args: string[]): Promise<{ stdout: string; stderr: string; code: number | null }> => {
  return new Promise((resolve) => {
    const peekabooPath = path.resolve(__dirname, '../../../../peekaboo'); // Assuming CLI is in project root
    const process = child_process.spawn(peekabooPath, args);
    let stdout = '';
    let stderr = '';
    process.stdout.on('data', (data) => (stdout += data.toString()));
    process.stderr.on('data', (data) => (stderr += data.toString()));
    process.on('close', (code) => {
      resolve({ stdout, stderr, code });
    });
    process.on('error', (err) => {
      resolve({ stdout: '', stderr: `Failed to start Peekaboo CLI: ${err.message}`, code: -1 });
    });
  });
};

const describeAppImageCaptureTest = (appName: string) => {
  describe(`${appName} CLI Image Capture E2E Test`, () => {
    let tempImagePath = '';
    const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'peekaboo-e2e-'));

    beforeAll(async () => {
      try {
        console.log(`Ensuring ${appName} is running and active...`);
        await runAppleScript(`
          tell application "${appName}"
            if not running then
              launch
            end if
            activate
          end tell
        `);
        await new Promise(resolve => setTimeout(resolve, 3000)); // Wait for app to be visible
      } catch (error) {
        console.error(`Error setting up ${appName}:`, error);
        throw error;
      }
    }, 10000); // Increased timeout for app launching

    afterAll(async () => {
      try {
        console.log(`Quitting ${appName}...`);
        await runAppleScript(`
          tell application "${appName}"
            if running then
              quit
            end if
          end tell
        `);
      } catch (error) {
        // Non-critical if quit fails, might be closed already or stuck
        console.warn(`Could not quit ${appName} gracefully:`, error.message);
      }
      if (tempImagePath && fs.existsSync(tempImagePath)) {
        try {
          fs.unlinkSync(tempImagePath);
        } catch (e) {
          console.warn(`Could not delete temp image ${tempImagePath}: ${e.message}`);
        }
      }
      if (fs.existsSync(tempDir)) {
        try {
          fs.rmSync(tempDir, { recursive: true, force: true });
        } catch (e) {
          console.warn(`Could not delete temp dir ${tempDir}: ${e.message}`);
        }
      }
    }, 10000); // Increased timeout for app quitting and cleanup

    test(`should take a screenshot of ${appName} using the CLI`, async () => {
      tempImagePath = path.join(tempDir, `${appName.replace(/\\s+/g, '-')}-screenshot-${Date.now()}.png`);
      console.log(`Taking screenshot of ${appName} to ${tempImagePath} using CLI...`);

      const imageResult = await runPeekabooCli(['image', '--app', appName, '--path', tempImagePath]);
      console.log(`${appName} 'image' CLI stdout: ${imageResult.stdout}`);
      console.error(`${appName} 'image' CLI stderr: ${imageResult.stderr}`);

      // Check for successful exit code
      expect(imageResult.code).toBe(0);
      // Verify stderr is empty or does not contain error indicators (more robust than exact empty string)
      // Specific error messages from peekaboo CLI can be checked here if known
      expect(imageResult.stderr.toLowerCase()).not.toContain('error');
      expect(imageResult.stderr.toLowerCase()).not.toContain('failed');

      // Verify the image file was created
      expect(fs.existsSync(tempImagePath)).toBe(true);
      // Verify the image file has a size greater than 0 bytes
      expect(fs.statSync(tempImagePath).size).toBeGreaterThan(0);

      // Optional: Check stdout for confirmation message if peekaboo CLI provides one
      // expect(imageResult.stdout).toContain(`Successfully saved screenshot to ${tempImagePath}`);
    }, 20000); // Timeout for app interaction and CLI execution

    // test(`should analyze the screenshot of ${appName} using the CLI`, async () => {
    //   // This test depends on tempImagePath being set by the previous test
    //   expect(fs.existsSync(tempImagePath)).toBe(true); // Ensure image exists before analyzing
      
    //   console.log(`Analyzing screenshot of ${appName} from ${tempImagePath} using CLI...`);
    //   const question = "Describe this application window in detail.";
    //   const analyzeResult = await runPeekabooCli(['analyze', '--image-path', tempImagePath, '--question', question]);
      
    //   console.log(`${appName} 'analyze' CLI stdout: ${analyzeResult.stdout}`);
    //   console.error(`${appName} 'analyze' CLI stderr: ${analyzeResult.stderr}`);

    //   expect(analyzeResult.code).toBe(0);
    //   expect(analyzeResult.stderr.toLowerCase()).not.toContain('error');
    //   expect(analyzeResult.stderr.toLowerCase()).not.toContain('failed');
      
    //   // Check for a non-empty stdout, which should contain the analysis
    //   expect(analyzeResult.stdout.trim()).not.toBe('');
    //   // A more specific check could be to ensure some keywords related to analysis are present,
    //   // but that might make the test brittle depending on the AI model's output.
    //   // For now, a non-empty response is a good indicator.
    // }, 30000); // Increased timeout for potential AI model processing time
  });
};

// --- Test Suites ---
describeAppImageCaptureTest('Calculator');
describeAppImageCaptureTest('TextEdit');
describeAppImageCaptureTest('System Settings');
describeAppImageCaptureTest('Safari');
describeAppImageCaptureTest('Finder');
describeAppImageCaptureTest('Mail');
describeAppImageCaptureTest('Notes');
describeAppImageCaptureTest('Terminal');

// To run these tests, ensure:
// 1. Peekaboo CLI (the Swift executable) is built and accessible at the root of the project.
// 2. Screen Recording and Accessibility permissions are granted for the terminal running the tests.
// 3. An Ollama server is running locally with a vision model (e.g., llava) available. 