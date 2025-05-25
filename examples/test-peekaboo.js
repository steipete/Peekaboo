#!/usr/bin/env node

/**
 * Simple test script to verify Peekaboo MCP is working correctly
 * Run this after installing the package to test basic functionality
 */

import { spawn } from 'child_process';

console.log('🧪 Testing Peekaboo MCP Server...\n');

// Test 1: List available tools
console.log('📋 Test 1: Listing available tools...');
const listToolsRequest = {
  jsonrpc: "2.0",
  id: 1,
  method: "tools/list"
};

// Test 2: List running applications
console.log('📱 Test 2: Listing running applications...');
const listAppsRequest = {
  jsonrpc: "2.0",
  id: 2,
  method: "tools/call",
  params: {
    name: "list",
    arguments: {
      target: "apps"
    }
  }
};

// Test 3: Capture screen
console.log('📸 Test 3: Capturing screen...');
const captureScreenRequest = {
  jsonrpc: "2.0",
  id: 3,
  method: "tools/call",
  params: {
    name: "image",
    arguments: {
      app_target: "screen",
      format: "data"
    }
  }
};

// Start the server
const server = spawn('node', ['dist/index.js'], {
  stdio: ['pipe', 'pipe', 'pipe']
});

let responses = [];
let currentTest = 1;

server.stdout.on('data', (data) => {
  const lines = data.toString().split('\n').filter(line => line.trim());
  
  for (const line of lines) {
    try {
      const response = JSON.parse(line);
      responses.push(response);
      
      if (response.id === 1) {
        console.log('✅ Tools available:', response.result.tools.map(t => t.name).join(', '));
        
        // Send next test
        server.stdin.write(JSON.stringify(listAppsRequest) + '\n');
      } else if (response.id === 2) {
        const apps = response.result[0]?.content[0]?.text;
        if (apps) {
          const appData = JSON.parse(apps);
          console.log(`✅ Found ${appData.applications.length} running applications`);
        }
        
        // Send next test
        server.stdin.write(JSON.stringify(captureScreenRequest) + '\n');
      } else if (response.id === 3) {
        if (response.result && response.result[0]) {
          console.log('✅ Screen captured successfully');
          console.log('\n🎉 All tests passed!');
        } else if (response.error) {
          console.log('❌ Screen capture failed:', response.error.message);
        }
        
        // Exit
        server.kill();
        process.exit(0);
      }
    } catch (e) {
      // Ignore non-JSON lines
    }
  }
});

server.stderr.on('data', (data) => {
  console.error('Server error:', data.toString());
});

server.on('close', (code) => {
  if (code !== 0) {
    console.error(`\n❌ Server exited with code ${code}`);
    process.exit(1);
  }
});

// Send first test
setTimeout(() => {
  server.stdin.write(JSON.stringify(listToolsRequest) + '\n');
}, 100);

// Timeout after 10 seconds
setTimeout(() => {
  console.error('\n❌ Test timed out');
  server.kill();
  process.exit(1);
}, 10000);