#!/usr/bin/env node
// Peekaboo MCP wrapper that restarts the Swift server on crash

import { spawn, execSync } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const binaryPath = join(__dirname, 'peekaboo');

const MAX_RESTARTS = 5;
const RESTART_WINDOW_MS = 60_000;
const INITIAL_DELAY_MS = 1000;
const MAX_DELAY_MS = 30_000;

class PeekabooMCPWrapper {
  constructor() {
    this.restartTimestamps = [];
    this.delay = INITIAL_DELAY_MS;
    this.child = null;
    this.shuttingDown = false;
  }

  start() {
    if (!existsSync(binaryPath)) {
      console.error(`[Peekaboo MCP] Binary not found at ${binaryPath}`);
      process.exit(1);
    }

    const now = Date.now();
    this.restartTimestamps = this.restartTimestamps.filter(ts => now - ts < RESTART_WINDOW_MS);
    if (this.restartTimestamps.length >= MAX_RESTARTS) {
      console.error(`[Peekaboo MCP] Aborting: restarted ${MAX_RESTARTS} times within a minute.`);
      process.exit(1);
    }

    console.error('[Peekaboo MCP] Starting Swift server...');
    this.child = spawn(binaryPath, ['mcp', 'serve'], {
      stdio: 'inherit',
      env: {
        ...process.env,
        PEEKABOO_MCP_WRAPPER: 'true'
      }
    });

    this.child.on('exit', (code, signal) => {
      if (this.shuttingDown) return process.exit(code || 0);

      if (code === 0 || signal === 'SIGINT' || signal === 'SIGTERM') {
        console.error('[Peekaboo MCP] Server exited cleanly');
        process.exit(code || 0);
      }

      this.handleCrash(code, signal);
    });

    this.child.on('error', (err) => {
      console.error('[Peekaboo MCP] Failed to launch:', err.message);
      if (err.code === 'EACCES') {
        try {
          execSync(`chmod +x "${binaryPath}"`);
          console.error('[Peekaboo MCP] Fixed executable bit, retrying...');
          this.handleCrash(1);
          return;
        } catch (_) {
          console.error('[Peekaboo MCP] Could not make binary executable.');
        }
      }
      this.handleCrash(err.code || 1);
    });
  }

  handleCrash(code, signal) {
    console.error(`[Peekaboo MCP] Server crashed (code ${code}${signal ? `, signal ${signal}` : ''}).`);
    this.restartTimestamps.push(Date.now());
    setTimeout(() => {
      this.delay = Math.min(this.delay * 2, MAX_DELAY_MS);
      this.start();
    }, this.delay);
  }

  shutdown() {
    this.shuttingDown = true;
    if (this.child && !this.child.killed) {
      this.child.kill('SIGTERM');
    }
  }
}

const wrapper = new PeekabooMCPWrapper();
wrapper.start();

process.on('SIGINT', () => {
  console.error('\n[Peekaboo MCP] SIGINT received, shutting down...');
  wrapper.shutdown();
});

process.on('SIGTERM', () => {
  console.error('[Peekaboo MCP] SIGTERM received, shutting down...');
  wrapper.shutdown();
});

process.on('uncaughtException', (err) => {
  console.error('[Peekaboo MCP] Uncaught exception:', err);
  wrapper.shutdown();
});

process.on('unhandledRejection', (reason) => {
  console.error('[Peekaboo MCP] Unhandled rejection:', reason);
});
