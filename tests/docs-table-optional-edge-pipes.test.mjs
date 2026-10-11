import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture, articleFromHTML } from './docs-site-fixture.mjs';
test('unbordered Markdown tables retain columns and alignment', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\nName | Value\n--- | ---:\none | `two`\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<th>Name<\/th><th style="text-align:right">Value<\/th>/);
  assert.match(article, /<td>one<\/td><td style="text-align:right"><code>two<\/code><\/td>/);
});
test('single-column tables render while mismatched separators stay prose', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n| Option |\n| --- |\n| --json |\n\nName | Value\n---\n'});
  const article = articleFromHTML(page.readPage());
  assert.equal((article.match(/<table>/g)||[]).length,1);
  assert.match(article, /<td>--json<\/td>/);
  assert.match(article, /<p>Name \| Value<\/p>/);
});
