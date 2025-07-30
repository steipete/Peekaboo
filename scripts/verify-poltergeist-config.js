#!/usr/bin/env node
// Script to verify Peekaboo's config is ready for new Poltergeist

const fs = require('fs');
const path = require('path');

console.log('🔍 Verifying Peekaboo config for new Poltergeist...\n');

// Read the config
const configPath = path.join(__dirname, '..', 'poltergeist.config.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

// Check for new format
if ('cli' in config || 'macApp' in config) {
  console.error('❌ ERROR: Config still uses old format!');
  console.error('   Found "cli" or "macApp" sections');
  process.exit(1);
}

if (!config.targets || !Array.isArray(config.targets)) {
  console.error('❌ ERROR: Config missing "targets" array!');
  process.exit(1);
}

console.log('✅ Config uses new format with targets array');
console.log(`✅ Found ${config.targets.length} targets:\n`);

// Validate each target
let hasErrors = false;
config.targets.forEach((target, index) => {
  console.log(`Target ${index + 1}: ${target.name}`);
  
  // Check required fields
  const required = ['name', 'type', 'buildCommand', 'watchPaths'];
  const missing = required.filter(field => !target[field]);
  
  if (missing.length > 0) {
    console.error(`  ❌ Missing required fields: ${missing.join(', ')}`);
    hasErrors = true;
  } else {
    console.log(`  ✅ Type: ${target.type}`);
    console.log(`  ✅ Enabled: ${target.enabled}`);
    console.log(`  ✅ Build: ${target.buildCommand}`);
    console.log(`  ✅ Watch: ${target.watchPaths.length} patterns`);
  }
  
  // Type-specific validation
  if (target.type === 'executable' && !target.outputPath) {
    console.error('  ❌ Executable target missing outputPath');
    hasErrors = true;
  }
  
  if (target.type === 'app-bundle' && !target.bundleId) {
    console.error('  ❌ App bundle target missing bundleId');
    hasErrors = true;
  }
  
  console.log('');
});

// Check optional sections
if (config.notifications) {
  console.log('✅ Notifications configured');
}

if (config.logging) {
  console.log('✅ Logging configured');
}

if (hasErrors) {
  console.error('\n❌ Config validation failed!');
  process.exit(1);
} else {
  console.log('\n✅ Config is ready for new Poltergeist!');
  console.log('\nExample commands with new Poltergeist:');
  console.log('  poltergeist haunt --target peekaboo-cli');
  console.log('  poltergeist haunt --target peekaboo-mac');
  console.log('  poltergeist haunt  # builds all enabled targets');
  console.log('  poltergeist list   # shows all configured targets');
}