import assert from 'node:assert/strict';
import test from 'node:test';
import { extractReleaseNotes } from '../scripts/release-driver-contract.mjs';
test('a release example heading cannot truncate the release body', () => {
  const notes='## 1.2.3 - 2026-10-11\n\nExample:\n```md\n## Example heading\n```\n\nRetained change.\n';
  assert.equal(extractReleaseNotes(notes+'\n## 1.2.2 - 2026-10-10\nOlder change.\n','1.2.3'),notes);
});
test('an example of the version heading cannot impersonate its actual section', () => {
  const text='~~~md\n## 1.2.3 - fake\n~~~\n\n## 1.2.3 - 2026-10-11\nActual change.\n';
  assert.equal(extractReleaseNotes(text,'1.2.3'),'## 1.2.3 - 2026-10-11\nActual change.\n');
});
