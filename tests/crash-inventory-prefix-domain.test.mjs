import assert from 'node:assert/strict';
import test from 'node:test';
import {compareCrashInventories} from '../scripts/final-qualification/crash-inventory.mjs';
const entry = name => ({name,size:7,modified_at_milliseconds:1,sha256:'a'.repeat(64)});
const inventory = entries => ({version:1,directory:'/fixture/DiagnosticReports',prefixes:['Peekaboo'],entries,captured_at_milliseconds:1000});
test('crash evidence rejects files outside its claimed monitored domain', () => {
  for (const name of ['Unrelated.ips', 1234]) {
    const value = inventory([entry(name)]);
    assert.throws(() => compareCrashInventories(value,value), /entries\[0\].*malformed/);
  }
});
test('matching prefixes retain unchanged and newly added crash detection', () => {
  const before = inventory([entry('Peekaboo-1.ips')]);
  assert.equal(compareCrashInventories(before,before).passed,true);
  const after = inventory([...before.entries,entry('PeekabooInspector-2.ips')]);
  const result = compareCrashInventories(before,after);
  assert.equal(result.passed,false);
  assert.deepEqual(result.added.map(value=>value.name),['PeekabooInspector-2.ips']);
});
