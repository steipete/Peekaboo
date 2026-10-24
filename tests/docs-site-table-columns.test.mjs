import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { articleFromHTML, buildDocsFixture } from './docs-site-fixture.mjs';

test('smart-select metadata rows keep source, key, and purpose', (t) => {
  const markdown = readFileSync(new URL('../docs/window-screenshot-smart-select.md', import.meta.url), 'utf8');
  const article = articleFromHTML(buildDocsFixture(t, { 'index.md': markdown }).readPage());
  const table = article.match(/<table>[\s\S]*?<\/table>/)?.[0];
  assert.ok(table, 'metadata table missing');
  const rows = [...table.matchAll(/<tr>([\s\S]*?)<\/tr>/g)];
  assert.ok(rows.length >= 2);
  for (const row of rows) {
    const cells = row[1].match(/<t[dh]\b/g) ?? [];
    assert.equal(cells.length, 3, row[1]);
  }
  assert.match(table, /<td><code>kCGWindowLayer<\/code><\/td>/);
  assert.match(table, /<td><code>CGWindowListCopyWindowInfo<\/code><\/td>[\s\S]*<td><code>kCGWindowLayer<\/code><\/td>/);
  assert.match(table, /<td><code>isExcludedFromWindowsMenu<\/code><\/td>/);
});
