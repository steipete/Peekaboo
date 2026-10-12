import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture, articleFromHTML } from './docs-site-fixture.mjs';
test('a delimiter prefix inside metadata is not a closing delimiter', t => {
  const page = buildDocsFixture(t, {'index.md':'---\nsummary: Fixture\n---not-a-delimiter\ntitle: Exact title\n---\n# Body\n'});
  const html = page.readPage();
  assert.match(html, /<title>Exact title — Peekaboo<\/title>/);
  assert.doesNotMatch(articleFromHTML(html), /not-a-delimiter|title: Exact title/);
});
