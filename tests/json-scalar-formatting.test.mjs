import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

test('the native CLI formatter handles all JSON value kinds', t => {
  const root = mkdtempSync(join(tmpdir(), 'peekaboo-json-scalar-'));
  t.after(() => rmSync(root, {recursive: true, force: true}));
  const harness = join(root, 'Harness.swift');
  const binary = join(root, 'contract');
  writeFileSync(harness, String.raw`import Foundation
@main struct ContractHarness {
    static func main() {
        for value in ["true", "null", "42", "\"message\"", "[1,2]", "{\"b\":2,\"a\":1}", "invalid"] {
            print(formatJSON(value, indent: "")?.replacingOccurrences(of: "\n", with: "") ?? "<nil>")
        }
    }
}
`);
  const build = spawnSync('/usr/bin/xcrun', ['swiftc', '-parse-as-library',
    fileURLToPath(new URL('../Apps/CLI/Sources/PeekabooCLI/Helpers/JSONFormatting.swift', import.meta.url)),
    harness, '-o', binary], {encoding:'utf8', timeout:60000});
  assert.equal(build.status, 0, build.stderr);
  const result = spawnSync(binary, [], {encoding:'utf8', timeout:10000});
  assert.equal(result.status, 0, result.stderr);
  const lines = result.stdout.trimEnd().split('\n');
  assert.deepEqual(lines.slice(0,4), ['true', 'null', '42', '"message"']);
  assert.deepEqual(JSON.parse(lines[4]), [1,2]);
  assert.deepEqual(JSON.parse(lines[5]), {a:1,b:2});
  assert.equal(lines[6], '<nil>');
});
