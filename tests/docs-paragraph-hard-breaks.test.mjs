import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture, articleFromHTML } from './docs-site-fixture.mjs';
test('two spaces and a backslash create explicit paragraph breaks', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\nFirst  \nSecond\\\nThird\nsoft continuation\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<p>First<br>Second<br>Third soft continuation<\/p>/);
});
test('code spans keep code text and backslashes instead of breaks', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n`literal  \ncode` and `slash\\\ncode`\n'});
  const article = articleFromHTML(page.readPage());
  assert.doesNotMatch(article, /<br>/);
  assert.match(article, /<code>literal  [\n ]code<\/code>/);
});
