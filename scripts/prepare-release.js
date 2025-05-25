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
    checkDependencies,
    checkVersionAvailability,
    checkTypeScript,
    checkSwift,
    buildAndVerifyPackage
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