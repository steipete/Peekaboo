import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture, articleFromHTML } from './docs-site-fixture.mjs';

test('balanced parentheses stay inside a link destination', t => {
  const page = buildDocsFixture(t, {'index.md': '# Fixture\n\n[`tags(_:)`](https://developer.apple.com/documentation/testing/trait/tags(_:)) trait\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<a href="https:\/\/developer\.apple\.com\/documentation\/testing\/trait\/tags\(_:\)"><code>tags\(_:\)<\/code><\/a> trait/);
});

test('parentheses in a link destination do not leak into the text', t => {
  const page = buildDocsFixture(t, {'index.md': '# Fixture\n\n[Test](https://example.invalid/test(_:_:)) and [other](https://example.invalid/plain)\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<a href="https:\/\/example\.invalid\/test\(_:_:\)">Test<\/a> and <a href="https:\/\/example\.invalid\/plain">other<\/a>/);
  assert.doesNotMatch(article, /<\/a>\)/);
});
