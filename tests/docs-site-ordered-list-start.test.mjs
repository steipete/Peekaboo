import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture, articleFromHTML } from './docs-site-fixture.mjs';
test('continued instructions retain their original ordinal', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n4. Configure\n5. Build\n\nParagraph\n\n1. Default\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<ol start="4">\n<li>Configure<\/li>/);
  assert.match(article, /<ol>\n<li>Default<\/li>/);
});
