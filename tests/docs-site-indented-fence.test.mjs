import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture } from './docs-site-fixture.mjs';

function codeBlocks(t, markdown) {
  const html = buildDocsFixture(t, { 'index.md': markdown }).readPage();
  return [...html.matchAll(/<pre><code[^>]*>([\s\S]*?)<\/code><\/pre>/g)].map((match) => match[1]);
}

test('an indented opening fence strips its indentation from the code lines', (t) => {
  const [code] = codeBlocks(t, '# Fixture\n\n3. Run it\n\n   ```text\n   first\n     nested\n   last\n   ```\n');
  assert.equal(code, 'first\n  nested\nlast');
});

test('only the fence indentation is removed from over-indented and shallower lines', (t) => {
  const [code] = codeBlocks(t, '# Fixture\n\n  ```text\n    deeper\nflush\n   ```\n');
  assert.equal(code, '  deeper\nflush');
});

test('an unindented fence keeps every code line as written', (t) => {
  const [code] = codeBlocks(t, '# Fixture\n\n```text\n  keep\n```\n');
  assert.equal(code, '  keep');
});
