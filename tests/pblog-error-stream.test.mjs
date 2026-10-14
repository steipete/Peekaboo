import assert from 'node:assert/strict';
import test from 'node:test';
import { logScriptFixture, success } from './fixtures/log-script.mjs';
import { fileURLToPath } from 'node:url';
test('error-only streams use a supported level and retain the error predicate', t => {
  const f = logScriptFixture(t, fileURLToPath(new URL('../scripts/pblog.sh', import.meta.url)));
  success(f.run(['--follow','--errors','--subsystem','fixture']));
  assert.deepEqual(f.args(), ['stream','--predicate','subsystem == "fixture" AND logType == "error"','--level','info']);
});
test('error filtering survives a later debug verbosity option', t => {
  const f = logScriptFixture(t, fileURLToPath(new URL('../scripts/pblog.sh', import.meta.url)));
  success(f.run(['--all','--errors','--debug','--subsystem','fixture']));
  assert.deepEqual(f.args(), ['show','--predicate','subsystem == "fixture" AND logType == "error"','--debug','--last','5m']);
});
