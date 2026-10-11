import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture, articleFromHTML } from './docs-site-fixture.mjs';
test('matching inline delimiters retain literal backticks and markup', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\nUse `` `flag` & <literal> `` and `normal` here.\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<code>`flag` &amp; &lt;literal&gt;<\/code>/);
  assert.match(article, /<code>normal<\/code>/);
});
test('unmatched delimiter runs remain literal without stealing shorter spans', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\nBefore ``unclosed then `short` and after.\n'});
  assert.match(articleFromHTML(page.readPage()), /``unclosed then <code>short<\/code>/);
});
