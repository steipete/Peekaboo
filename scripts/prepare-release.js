#!/usr/bin/env node

/**
 * Release preparation script for @steipete/peekaboo-mcp
 * 
 * This script performs comprehensive checks before release:
 * 1. Git status checks (branch, uncommitted files, sync with origin)
 * 2. TypeScript/Node.js checks (lint, type check, tests)
 * 3. Swift checks (format, lint, tests)
 * 4. Build and package verification
 */

import { execSync } from 'child_process';
import { readFileSync, existsSync, rmSync } from 'fs';
import { join } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, '..');

// ANSI color codes
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m'
};

function log(message, color = '') {
  console.log(`${color}${message}${colors.reset}`);
}

function logStep(step) {
  console.log(`\n${colors.bright}${colors.blue}━━━ ${step} ━━━${colors.reset}\n`);
}

function logSuccess(message) {
  log(`✅ ${message}`, colors.green);
}

function logError(message) {
  log(`❌ ${message}`, colors.red);
}

function logWarning(message) {
  log(`⚠️  ${message}`, colors.yellow);
}

function exec(command, options = {}) {
  try {
    return execSync(command, {
      cwd: projectRoot,
      stdio: 'pipe',
      encoding: 'utf8',
      ...options
    }).trim();
  } catch (error) {
    if (options.allowFailure) {
      return null;
    }
    throw error;
  }
}

function execWithOutput(command, description) {
  try {
    log(`Running: ${description}...`, colors.cyan);
    execSync(command, {
      cwd: projectRoot,
      stdio: 'inherit'
    });
    return true;
  } catch (error) {
    return false;
  }
}

// Check functions
function checkGitStatus() {
  logStep('Git Status Checks');

  // Check current branch
  const currentBranch = exec('git branch --show-current');
  if (currentBranch !== 'main') {
    logWarning(`Currently on branch '${currentBranch}', not 'main'`);
    const proceed = process.argv.includes('--force');
    if (!proceed) {
      logError('Switch to main branch before releasing (use --force to override)');
      return false;
    }
  } else {
    logSuccess('On main branch');
  }

  // Check for uncommitted changes
  const gitStatus = exec('git status --porcelain');
  if (gitStatus) {
    logError('Uncommitted changes detected:');
    console.log(gitStatus);
    return false;
  }
  logSuccess('No uncommitted changes');

  // Check if up to date with origin
  exec('git fetch');
  const behind = exec('git rev-list HEAD..origin/main --count');
  const ahead = exec('git rev-list origin/main..HEAD --count');
  
  if (behind !== '0') {
    logError(`Branch is ${behind} commits behind origin/main`);
    return false;
  }
  if (ahead !== '0') {
    logWarning(`Branch is ${ahead} commits ahead of origin/main (remember to push after release)`);
  } else {
    logSuccess('Branch is up to date with origin/main');
  }

  return true;
}

function checkDependencies() {
  logStep('Dependency Checks');

  // Check if node_modules exists
  if (!existsSync(join(projectRoot, 'node_modules'))) {
    log('Installing dependencies...', colors.yellow);
    if (!execWithOutput('npm install', 'npm install')) {
      logError('Failed to install dependencies');
      return false;
    }
  }

  // Check for outdated dependencies
  const outdated = exec('npm outdated --json', { allowFailure: true });
  if (outdated) {
    try {
      const outdatedPkgs = JSON.parse(outdated);
      const count = Object.keys(outdatedPkgs).length;
      if (count > 0) {
        logWarning(`${count} outdated dependencies found (run 'npm outdated' for details)`);
      }
    } catch {
      // Ignore parse errors
    }
  }
  
  logSuccess('Dependencies checked');
  return true;
}

function checkTypeScript() {
  logStep('TypeScript Checks');

  // Clean build directory
  log('Cleaning build directory...', colors.cyan);
  rmSync(join(projectRoot, 'dist'), { recursive: true, force: true });

  // Type check
  if (!execWithOutput('npm run build', 'TypeScript compilation')) {
    logError('TypeScript compilation failed');
    return false;
  }
  logSuccess('TypeScript compilation successful');

  // Run TypeScript tests
  if (!execWithOutput('npm test', 'TypeScript tests')) {
    logError('TypeScript tests failed');
    return false;
  }
  logSuccess('TypeScript tests passed');

  return true;
}

function checkSwift() {
  logStep('Swift Checks');

  // Run SwiftFormat
  if (!execWithOutput('npm run format:swift', 'SwiftFormat')) {
    logError('SwiftFormat failed');
    return false;
  }
  logSuccess('SwiftFormat completed');

  // Check if SwiftFormat made any changes
  const formatChanges = exec('git status --porcelain');
  if (formatChanges) {
    logError('SwiftFormat made changes. Please commit them before releasing:');
    console.log(formatChanges);
    return false;
  }

  // Run SwiftLint
  if (!execWithOutput('npm run lint:swift', 'SwiftLint')) {
    logError('SwiftLint found violations');
    return false;
  }
  logSuccess('SwiftLint passed');

  // Run Swift tests
  if (!execWithOutput('npm run test:swift', 'Swift tests')) {
    logError('Swift tests failed');
    return false;
  }
  logSuccess('Swift tests passed');

  // Test Swift CLI commands directly
  log('Testing Swift CLI commands...', colors.cyan);
  
  // Test help command
  const helpOutput = exec('./peekaboo --help', { allowFailure: true });
  if (!helpOutput || !helpOutput.includes('USAGE:')) {
    logError('Swift CLI help command failed');
    return false;
  }
  
  // Test version command
  const versionOutput = exec('./peekaboo --version', { allowFailure: true });
  if (!versionOutput) {
    logError('Swift CLI version command failed');
    return false;
  }
  
  // Test list apps command
  const appsOutput = exec('./peekaboo list apps --json-output', { allowFailure: true });
  if (!appsOutput) {
    logError('Swift CLI list apps command failed');
    return false;
  }
  
  try {
    const response = JSON.parse(appsOutput);
    if (!response.success || !response.data || !response.data.applications || !Array.isArray(response.data.applications)) {
      logError('Apps list has invalid structure');
      return false;
    }
    // Should always have at least some apps running
    if (response.data.applications.length === 0) {
      logError('No running applications found');
      return false;
    }
  } catch (e) {
    logError('Swift CLI apps JSON output is invalid');
    return false;
  }
  
  // Test list windows command for Finder  
  const windowsOutput = exec('./peekaboo list windows --app Finder --json-output', { allowFailure: true });
  if (!windowsOutput) {
    logError('Swift CLI list windows command failed');
    return false;
  }
  
  try {
    const response = JSON.parse(windowsOutput);
    if (!response.success || !response.data || !response.data.windows || !Array.isArray(response.data.windows)) {
      logError('Windows list has invalid structure');
      return false;
    }
    // Finder might not have windows, so just check structure
    if (!response.data.target_application_info) {
      logError('Windows response missing target_application_info');
      return false;
    }
  } catch (e) {
    logError('Swift CLI windows JSON output is invalid');
    return false;
  }
  
  // Test error handling - non-existent app
  const errorOutput = exec('./peekaboo list windows --app NonExistentApp12345 --json-output 2>&1', { allowFailure: true });
  if (errorOutput) {
    try {
      const errorData = JSON.parse(errorOutput);
      if (!errorData.error) {
        logWarning('Error response missing error field');
      }
    } catch (e) {
      // If it's not JSON, that's OK - might be stderr output
    }
  }
  
  // Test image command help
  const imageHelpOutput = exec('./peekaboo image --help', { allowFailure: true });
  if (!imageHelpOutput || !imageHelpOutput.includes('mode')) {
    logError('Swift CLI image help command failed');
    return false;
  }
  
  logSuccess('Swift CLI commands working correctly');

  return true;
}

function checkVersionAvailability() {
  logStep('Version Availability Check');

  const packageJson = JSON.parse(readFileSync(join(projectRoot, 'package.json'), 'utf8'));
  const packageName = packageJson.name;
  const version = packageJson.version;

  log(`Checking if ${packageName}@${version} is already published...`, colors.cyan);

  // Check if version exists on npm
  const existingVersions = exec(`npm view ${packageName} versions --json`, { allowFailure: true });
  
  if (existingVersions) {
    try {
      const versions = JSON.parse(existingVersions);
      if (versions.includes(version)) {
        logError(`Version ${version} is already published on npm!`);
        logError('Please update the version in package.json before releasing.');
        return false;
      }
    } catch (e) {
      // If parsing fails, try to check if it's a single version
      if (existingVersions.includes(version)) {
        logError(`Version ${version} is already published on npm!`);
        logError('Please update the version in package.json before releasing.');
        return false;
      }
    }
  }

  logSuccess(`Version ${version} is available for publishing`);
  return true;
}

function checkChangelog() {
  logStep('Changelog Entry Check');

  const packageJson = JSON.parse(readFileSync(join(projectRoot, 'package.json'), 'utf8'));
  const version = packageJson.version;

  // Read CHANGELOG.md
  const changelogPath = join(projectRoot, 'CHANGELOG.md');
  if (!existsSync(changelogPath)) {
    logError('CHANGELOG.md not found');
    return false;
  }

  const changelog = readFileSync(changelogPath, 'utf8');
  
  // Check for version entry (handle both x.x.x and x.x.x-beta.x formats)
  const versionPattern = new RegExp(`^#+\\s*(?:\\[)?${version.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?:\\])?`, 'm');
  if (!changelog.match(versionPattern)) {
    logError(`No entry found for version ${version} in CHANGELOG.md`);
    logError('Please add a changelog entry before releasing');
    return false;
  }

  logSuccess(`CHANGELOG.md contains entry for version ${version}`);
  return true;
}

function checkSecurityAudit() {
  logStep('Security Audit');

  log('Running npm audit...', colors.cyan);
  
  const auditResult = exec('npm audit --json', { allowFailure: true });
  
  if (auditResult) {
    try {
      const audit = JSON.parse(auditResult);
      const vulnCount = audit.metadata?.vulnerabilities || {};
      const total = Object.values(vulnCount).reduce((sum, count) => sum + count, 0);
      
      if (total > 0) {
        logWarning(`Found ${total} vulnerabilities:`);
        if (vulnCount.critical > 0) logError(`  Critical: ${vulnCount.critical}`);
        if (vulnCount.high > 0) logError(`  High: ${vulnCount.high}`);
        if (vulnCount.moderate > 0) logWarning(`  Moderate: ${vulnCount.moderate}`);
        if (vulnCount.low > 0) log(`  Low: ${vulnCount.low}`, colors.yellow);
        
        if (vulnCount.critical > 0 || vulnCount.high > 0) {
          logError('Critical or high severity vulnerabilities found. Please fix before releasing.');
          return false;
        }
        
        logWarning('Non-critical vulnerabilities found. Consider fixing before release.');
      } else {
        logSuccess('No security vulnerabilities found');
      }
    } catch (e) {
      logWarning('Could not parse npm audit results');
    }
  } else {
    logSuccess('No security vulnerabilities found');
  }
  
  return true;
}

function checkPackageSize() {
  logStep('Package Size Check');

  // Create a temporary package to get accurate size
  log('Calculating package size...', colors.cyan);
  const packOutput = exec('npm pack --dry-run 2>&1');
  
  // Extract size information
  const unpackedMatch = packOutput.match(/unpacked size: ([^\n]+)/);
  
  if (unpackedMatch) {
    const sizeStr = unpackedMatch[1];
    
    // Convert to bytes for comparison
    let sizeInBytes = 0;
    if (sizeStr.includes('MB')) {
      sizeInBytes = parseFloat(sizeStr) * 1024 * 1024;
    } else if (sizeStr.includes('kB')) {
      sizeInBytes = parseFloat(sizeStr) * 1024;
    } else if (sizeStr.includes('B')) {
      sizeInBytes = parseFloat(sizeStr);
    }
    
    const maxSizeInBytes = 2 * 1024 * 1024; // 2MB
    
    if (sizeInBytes > maxSizeInBytes) {
      logWarning(`Package size (${sizeStr}) exceeds 2MB threshold`);
      logWarning('Consider reviewing included files to reduce package size');
    } else {
      logSuccess(`Package size (${sizeStr}) is within acceptable limits`);
    }
  } else {
    logWarning('Could not determine package size');
  }
  
  return true;
}

function checkTypeScriptDeclarations() {
  logStep('TypeScript Declarations Check');

  // Check if .d.ts files are generated
  const distPath = join(projectRoot, 'dist');
  
  if (!existsSync(distPath)) {
    logError('dist/ directory not found. Please build the project first.');
    return false;
  }
  
  // Look for .d.ts files
  const dtsFiles = exec(`find "${distPath}" -name "*.d.ts" -type f`, { allowFailure: true });
  
  if (!dtsFiles || dtsFiles.trim() === '') {
    logError('No TypeScript declaration files (.d.ts) found in dist/');
    logError('Ensure TypeScript is configured to generate declarations');
    return false;
  }
  
  const declarationFiles = dtsFiles.split('\n').filter(f => f.trim());
  log(`Found ${declarationFiles.length} TypeScript declaration files`, colors.cyan);
  
  // Check for main declaration file
  const mainDtsPath = join(distPath, 'index.d.ts');
  if (!existsSync(mainDtsPath)) {
    logError('Missing main declaration file: dist/index.d.ts');
    return false;
  }
  
  logSuccess('TypeScript declarations are properly generated');
  return true;
}

function checkMCPServerSmoke() {
  logStep('MCP Server Smoke Test');

  const serverPath = join(projectRoot, 'dist', 'index.js');
  
  if (!existsSync(serverPath)) {
    logError('Server not built. Please run build first.');
    return false;
  }
  
  log('Testing MCP server with simple JSON-RPC request...', colors.cyan);
  
  try {
    // Test with a simple tools/list request
    const testRequest = '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}';
    const result = exec(`echo '${testRequest}' | node "${serverPath}"`, { allowFailure: true });
    
    if (!result) {
      logError('MCP server failed to respond');
      return false;
    }
    
    // Parse and validate response
    const lines = result.split('\n').filter(line => line.trim());
    const response = lines[lines.length - 1]; // Get last line (the actual response)
    
    try {
      const parsed = JSON.parse(response);
      
      if (parsed.error) {
        logError(`MCP server returned error: ${parsed.error.message}`);
        return false;
      }
      
      if (!parsed.result || !parsed.result.tools) {
        logError('MCP server response missing expected tools array');
        return false;
      }
      
      const toolCount = parsed.result.tools.length;
      log(`MCP server responded successfully with ${toolCount} tools`, colors.cyan);
      
    } catch (e) {
      logError('Failed to parse MCP server response');
      logError(`Response: ${response}`);
      return false;
    }
    
  } catch (error) {
    logError(`MCP server smoke test failed: ${error.message}`);
    return false;
  }
  
  logSuccess('MCP server smoke test passed');
  return true;
}

function checkSwiftCLIIntegration() {
  logStep('Swift CLI Integration Tests');
  
  log('Testing Swift CLI error handling and edge cases...', colors.cyan);
  
  // Test 1: Invalid command (since image is default, this gets interpreted as image subcommand argument)
  const invalidCmd = exec('./peekaboo invalid-command 2>&1', { allowFailure: true });
  if (!invalidCmd || !invalidCmd.includes('Unexpected argument')) {
    logError('Swift CLI should show error for invalid command');
    return false;
  }
  
  // Test 2: Missing required arguments
  const missingArgs = exec('./peekaboo image --mode app --json-output 2>&1', { allowFailure: true });
  if (!missingArgs || (!missingArgs.includes('error') && !missingArgs.includes('Error'))) {
    logError('Swift CLI should show error for missing --app with app mode');
    return false;
  }
  
  // Test 3: Invalid window ID
  const invalidWindowId = exec('./peekaboo image --mode window --window-id abc --json-output 2>&1', { allowFailure: true });
  if (!invalidWindowId || !invalidWindowId.includes('Error')) {
    logError('Swift CLI should show error for invalid window ID');
    return false;
  }
  
  // Test 4: Test all subcommands are available
  const subcommands = ['list', 'image'];
  for (const cmd of subcommands) {
    const helpOutput = exec(`./peekaboo ${cmd} --help`, { allowFailure: true });
    if (!helpOutput || !helpOutput.includes('USAGE')) {
      logError(`Swift CLI ${cmd} command help not available`);
      return false;
    }
  }
  
  // Test 5: JSON output format validation
  const formats = [
    { cmd: './peekaboo list server_status --json-output', required: ['has_screen_recording_permission'] },
    { cmd: './peekaboo list running_applications --json-output', required: ['applications'] }
  ];
  
  for (const { cmd, required } of formats) {
    const output = exec(cmd, { allowFailure: true });
    if (!output) {
      logError(`Command failed: ${cmd}`);
      return false;
    }
    
    try {
      const data = JSON.parse(output);
      for (const field of required) {
        if (!(field in data)) {
          logError(`Missing required field '${field}' in: ${cmd}`);
          return false;
        }
      }
    } catch (e) {
      logError(`Invalid JSON from: ${cmd}`);
      return false;
    }
  }
  
  // Test 6: Permission handling
  const permissionTest = exec('./peekaboo list server_status --json-output', { allowFailure: true });
  if (permissionTest) {
    try {
      const status = JSON.parse(permissionTest);
      log(`Permissions - Screen Recording: ${status.has_screen_recording_permission}, Accessibility: ${status.has_accessibility_permission}`, colors.cyan);
    } catch (e) {
      // Ignore, already tested above
    }
  }
  
  logSuccess('Swift CLI integration tests passed');
  return true;
}

function checkVersionConsistency() {
  logStep('Version Consistency Check');

  const packageJsonPath = join(projectRoot, 'package.json');
  const packageLockPath = join(projectRoot, 'package-lock.json');
  
  const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf8'));
  const packageVersion = packageJson.version;
  
  // Check package-lock.json
  if (!existsSync(packageLockPath)) {
    logError('package-lock.json not found');
    return false;
  }
  
  const packageLock = JSON.parse(readFileSync(packageLockPath, 'utf8'));
  const lockVersion = packageLock.version;
  
  if (packageVersion !== lockVersion) {
    logError(`Version mismatch: package.json has ${packageVersion}, package-lock.json has ${lockVersion}`);
    logError('Run "npm install" to update package-lock.json');
    return false;
  }
  
  // Also check that the package name matches in package-lock
  if (packageLock.packages && packageLock.packages[''] && packageLock.packages[''].version !== packageVersion) {
    logError(`Version mismatch in package-lock.json packages section`);
    return false;
  }
  
  logSuccess(`Version ${packageVersion} is consistent across package.json and package-lock.json`);
  return true;
}

function checkRequiredFields() {
  logStep('Required Fields Validation');

  const packageJson = JSON.parse(readFileSync(join(projectRoot, 'package.json'), 'utf8'));
  
  const requiredFields = {
    'name': 'Package name',
    'version': 'Package version',
    'description': 'Package description',
    'main': 'Main entry point',
    'type': 'Module type',
    'scripts': 'Scripts section',
    'repository': 'Repository information',
    'keywords': 'Keywords for npm search',
    'author': 'Author information',
    'license': 'License',
    'engines': 'Node.js engine requirements',
    'files': 'Files to include in package'
  };
  
  const missingFields = [];
  
  for (const [field, description] of Object.entries(requiredFields)) {
    if (!packageJson[field]) {
      missingFields.push(`${field} (${description})`);
    }
  }
  
  if (missingFields.length > 0) {
    logError('Missing required fields in package.json:');
    missingFields.forEach(field => logError(`  - ${field}`));
    return false;
  }
  
  // Additional validations
  if (!packageJson.repository || typeof packageJson.repository !== 'object' || !packageJson.repository.url) {
    logError('Repository field must be an object with a url property');
    return false;
  }
  
  if (!Array.isArray(packageJson.keywords) || packageJson.keywords.length === 0) {
    logWarning('Keywords array is empty. Consider adding keywords for better discoverability');
  }
  
  if (!packageJson.engines || !packageJson.engines.node) {
    logError('Missing engines.node field to specify Node.js version requirements');
    return false;
  }
  
  logSuccess('All required fields are present in package.json');
  return true;
}

function buildAndVerifyPackage() {
  logStep('Build and Package Verification');

  // Build everything
  if (!execWithOutput('npm run build:all', 'Full build (TypeScript + Swift)')) {
    logError('Build failed');
    return false;
  }
  logSuccess('Build completed successfully');

  // Create package
  log('Creating npm package...', colors.cyan);
  const packOutput = exec('npm pack --dry-run 2>&1');
  
  // Parse package details
  const sizeMatch = packOutput.match(/package size: ([^\n]+)/);
  const unpackedMatch = packOutput.match(/unpacked size: ([^\n]+)/);
  const filesMatch = packOutput.match(/total files: (\d+)/);
  
  if (sizeMatch && unpackedMatch && filesMatch) {
    log(`Package size: ${sizeMatch[1]}`, colors.cyan);
    log(`Unpacked size: ${unpackedMatch[1]}`, colors.cyan);
    log(`Total files: ${filesMatch[1]}`, colors.cyan);
  }

  // Verify critical files are included
  const requiredFiles = [
    'dist/index.js',
    'peekaboo',
    'README.md',
    'LICENSE'
  ];

  let allFilesPresent = true;
  for (const file of requiredFiles) {
    if (!packOutput.includes(file)) {
      logError(`Missing required file in package: ${file}`);
      allFilesPresent = false;
    }
  }

  if (!allFilesPresent) {
    return false;
  }
  logSuccess('All required files included in package');

  // Verify peekaboo binary
  log('Verifying peekaboo binary...', colors.cyan);
  const binaryPath = join(projectRoot, 'peekaboo');
  
  // Check if binary exists
  if (!existsSync(binaryPath)) {
    logError('peekaboo binary not found');
    return false;
  }
  
  // Check if binary is executable
  try {
    const stats = exec(`stat -f "%Lp" "${binaryPath}" 2>/dev/null || stat -c "%a" "${binaryPath}"`);
    const perms = parseInt(stats, 8);
    if ((perms & 0o111) === 0) {
      logError('peekaboo binary is not executable');
      return false;
    }
  } catch (error) {
    logError('Failed to check binary permissions');
    return false;
  }
  
  // Check binary architectures
  try {
    const lipoOutput = exec(`lipo -info "${binaryPath}"`);
    if (!lipoOutput.includes('arm64') || !lipoOutput.includes('x86_64')) {
      logError('peekaboo binary does not contain both architectures (arm64 and x86_64)');
      logError(`Found: ${lipoOutput}`);
      return false;
    }
    logSuccess('Binary contains both arm64 and x86_64 architectures');
  } catch (error) {
    logError('Failed to check binary architectures (lipo command failed)');
    return false;
  }
  
  // Check if binary responds to --help
  try {
    const helpOutput = exec(`"${binaryPath}" --help`);
    if (!helpOutput || helpOutput.length === 0) {
      logError('peekaboo binary does not respond to --help command');
      return false;
    }
    logSuccess('Binary responds correctly to --help command');
  } catch (error) {
    logError('peekaboo binary failed to execute with --help');
    logError(`Error: ${error.message}`);
    return false;
  }
  
  logSuccess('peekaboo binary verification passed');

  // Check package.json version
  const packageJson = JSON.parse(readFileSync(join(projectRoot, 'package.json'), 'utf8'));
  const version = packageJson.version;
  
  if (!version.match(/^\d+\.\d+\.\d+(-\w+\.\d+)?$/)) {
    logError(`Invalid version format: ${version}`);
    return false;
  }
  log(`Package version: ${version}`, colors.cyan);

  // Integration tests
  if (!execWithOutput('npm run test:integration', 'Integration tests')) {
    logError('Integration tests failed');
    return false;
  }
  logSuccess('Integration tests passed');

  return true;
}

// Main execution
async function main() {
  console.log(`\n${colors.bright}🚀 Peekaboo MCP Release Preparation${colors.reset}\n`);

  const checks = [
    checkGitStatus,
    checkRequiredFields,
    checkDependencies,
    checkSecurityAudit,
    checkVersionAvailability,
    checkVersionConsistency,
    checkChangelog,
    checkTypeScript,
    checkTypeScriptDeclarations,
    checkSwift,
    buildAndVerifyPackage,
    checkSwiftCLIIntegration,
    checkPackageSize,
    checkMCPServerSmoke
  ];

  for (const check of checks) {
    if (!check()) {
      console.log(`\n${colors.red}${colors.bright}❌ Release preparation failed!${colors.reset}\n`);
      process.exit(1);
    }
  }

  console.log(`\n${colors.green}${colors.bright}✅ All checks passed! Ready to release! 🎉${colors.reset}\n`);
  
  const packageJson = JSON.parse(readFileSync(join(projectRoot, 'package.json'), 'utf8'));
  console.log(`${colors.cyan}Next steps:${colors.reset}`);
  console.log(`1. Update version in package.json (current: ${packageJson.version})`);
  console.log(`2. Update CHANGELOG.md`);
  console.log(`3. Commit version bump: git commit -am "Release v<version>"`);
  console.log(`4. Create tag: git tag v<version>`);
  console.log(`5. Push changes: git push origin main --tags`);
  console.log(`6. Publish to npm: npm publish [--tag beta]`);
  console.log(`7. Create GitHub release\n`);
}

// Run the script
main().catch(error => {
  logError(`Unexpected error: ${error.message}`);
  process.exit(1);
});