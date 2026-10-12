import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture, articleFromHTML } from './docs-site-fixture.mjs';
test('escaped Swift parameter labels and glob markers remain literal', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\nCall bug(\\_:\\_:) and match \\*glob\\*.\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /bug\(_:_:\) and match \*glob\*/);
  assert.doesNotMatch(article, /<em>|\\_/);
});
test('escapes inside code remain copyable and ordinary emphasis still renders', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n`\\*literal\\*` and *emphasis* and path \\q.\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<code>\\\*literal\\\*<\/code>/);
  assert.match(article, /<em>emphasis<\/em>/);
  assert.match(article, /path \\q/);
});

test('escaped backticks and link brackets remain literal punctuation', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n\\`literal\\` and \\[label\\](target.md)\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /`literal` and \[label\]\(target.md\)/);
  assert.doesNotMatch(article, /<code>|<a href="target.html"/);
});
