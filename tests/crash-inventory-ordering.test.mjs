import assert from 'node:assert/strict';
import test from 'node:test';
import { compareCrashInventories } from '../scripts/final-qualification/crash-inventory.mjs';
const entry = {name:'Peekaboo.ips',size:12,modified_at_milliseconds:10,sha256:'a'.repeat(64)};
const baseline = {version:1,directory:'/fixture',prefixes:['Peekaboo','Inspector'],entries:[entry],captured_at_milliseconds:100};
test('JSON key order and prefix ordering do not manufacture crash changes', () => {
  const final = {...baseline,prefixes:['Inspector','Peekaboo'],captured_at_milliseconds:101,
    entries:[{sha256:entry.sha256,modified_at_milliseconds:10,size:12,name:entry.name}]};
  assert.deepEqual(compareCrashInventories(baseline,final), {version:1,passed:true,added:[],changed:[],removed:[]});
});
test('content and timestamp changes still invalidate an inventory', () => {
  for (const change of [{sha256:'b'.repeat(64)},{size:13},{modified_at_milliseconds:11}]) {
    const final={...baseline,captured_at_milliseconds:101,entries:[{...entry,...change}]};
    assert.equal(compareCrashInventories(baseline,final).passed,false);
  }
});
