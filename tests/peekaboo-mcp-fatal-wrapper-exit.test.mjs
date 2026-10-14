import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, copyFileSync, readFileSync, existsSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

for (const kind of ['exception', 'rejection']) test(`fatal ${kind} stops its child and exits without watchdog rescue`, t => {
  const root = mkdtempSync(join(tmpdir(), 'peekaboo-fatal-wrapper-'));
  const ready = join(root, 'child.pid');
  const stopped = join(root, 'child.stopped');
  t.after(() => {
    if (existsSync(ready) && !existsSync(stopped)) {
      try { process.kill(Number(readFileSync(ready, 'utf8')), 'SIGKILL'); } catch { /* Child already exited. */ }
    }
    rmSync(root, { recursive: true, force: true });
  });
  const wrapper = join(root, 'peekaboo-mcp.mjs');
  copyFileSync(new URL('../peekaboo-mcp.js', import.meta.url), wrapper);
  writeFileSync(join(root, 'peekaboo'), '#!/bin/sh\ntrap \'echo stopped > "$PEEKABOO_TEST_STOPPED"; exit 0\' TERM\necho $$ > "$PEEKABOO_TEST_READY"\nwhile :; do sleep 0.05; done\n', { mode: 0o755 });
  const preload = join(root, 'fatal-preload.mjs');
  writeFileSync(preload, `import {existsSync} from 'node:fs';
const poll = setInterval(() => {
  if (existsSync(process.env.PEEKABOO_TEST_READY)) {
    clearInterval(poll);
    if (process.env.PEEKABOO_TEST_FATAL_KIND === 'exception') throw new Error('fixture failure');
    Promise.reject(new Error('fixture failure'));
  }
}, 10);
setTimeout(() => {console.error('fatal watchdog fired'); process.exitCode=99; process.kill(process.pid,'SIGTERM');}, 2000);
`);
  const result = spawnSync(process.execPath, ['--import', preload, wrapper], {
    encoding: 'utf8', timeout: 5000, killSignal: 'SIGKILL',
    env: {...process.env, PEEKABOO_TEST_READY: ready, PEEKABOO_TEST_STOPPED: stopped, PEEKABOO_TEST_FATAL_KIND: kind},
  });
  assert.equal(result.error, undefined);
  assert.equal(result.signal, null);
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /fixture failure/);
  assert.doesNotMatch(result.stderr, /fatal watchdog fired/);
  assert.ok(existsSync(stopped), 'fatal event must terminate the actual child');
});

for (const kind of ['exception', 'rejection']) test(`fatal ${kind} during restart backoff exits despite a live handle`, t => {
  const root = mkdtempSync(join(tmpdir(), 'peekaboo-fatal-backoff-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const wrapper = join(root, 'peekaboo-mcp.mjs');
  copyFileSync(new URL('../peekaboo-mcp.js', import.meta.url), wrapper);
  writeFileSync(join(root, 'peekaboo'), '#!/bin/sh\nexit 1\n', { mode: 0o755 });
  const preload = join(root, 'fatal-preload.mjs');
  writeFileSync(preload, `setInterval(() => {}, 10000);
const write = process.stderr.write.bind(process.stderr);
let triggered = false;
process.stderr.write = (...args) => {
  const result = write(...args);
  if (!triggered && String(args[0]).includes('Server crashed')) {
    triggered = true;
    setTimeout(() => {
      if (process.env.PEEKABOO_TEST_FATAL_KIND === 'exception') throw new Error('backoff failure');
      Promise.reject(new Error('backoff failure'));
    }, 10);
  }
  return result;
};
`);
  const result = spawnSync(process.execPath, ['--import', preload, wrapper], {
    encoding: 'utf8', timeout: 5000, killSignal: 'SIGKILL',
    env: {...process.env, PEEKABOO_TEST_FATAL_KIND: kind},
  });
  assert.match(result.stderr, /Server crashed/);
  assert.match(result.stderr, /backoff failure/);
  assert.equal(result.error, undefined);
  assert.equal(result.signal, null);
  assert.equal(result.status, 1, result.stderr);
});
