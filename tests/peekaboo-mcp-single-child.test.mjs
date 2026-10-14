import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
test('repeated start keeps a single native server process', t => {
  const root = mkdtempSync(join(tmpdir(), 'peekaboo-single-child-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const binary = join(root, 'peekaboo');
  writeFileSync(binary, '#!/bin/sh\ntrap "exit 0" TERM\nwhile :; do sleep 0.05; done\n', { mode: 0o755 });
  const moduleURL = new URL('../peekaboo-mcp.js', import.meta.url).href;
  const result = spawnSync(process.execPath, ['--input-type=module', '--eval', `
    import { PeekabooMCPWrapper } from ${JSON.stringify(moduleURL)};
    const wrapper = new PeekabooMCPWrapper({binaryPath:${JSON.stringify(binary)}});
    wrapper.start();
    const first = wrapper.child;
    wrapper.start();
    console.log(wrapper.child === first ? 'single' : 'duplicate');
    // Stop both fixture processes even when the old implementation duplicates them.
    if (wrapper.child !== first) first.kill('SIGTERM');
    wrapper.shutdown();
  `], { encoding: 'utf8', timeout: 5000 });
  assert.equal(result.error, undefined);
  assert.match(result.stdout, /^single\n$/);
});
