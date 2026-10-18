import assert from 'node:assert/strict';
import test from 'node:test';
import { articleFromHTML, buildDocsFixture } from './docs-site-fixture.mjs';

function render(t, markdown) {
  return articleFromHTML(buildDocsFixture(t, { 'index.md': `# Fixture\n\n${markdown}` }).readPage());
}

test('underscores inside identifiers are not emphasis', (t) => {
  const article = render(t, 'Chrome returns WINDOW_NOT_FOUND and APP_NOT_FOUND.\n');
  assert.match(article, /<p>Chrome returns WINDOW_NOT_FOUND and APP_NOT_FOUND\.<\/p>/);
  assert.doesNotMatch(article, /<em>/);
});

test('underscore emphasis at word boundaries still renders', (t) => {
  const article = render(t, 'This is _emphasized_ text, (_wrapped_), and _a snake_case word_.\n');
  assert.match(article, /<em>emphasized<\/em> text, \(<em>wrapped<\/em>\), and <em>a snake_case word<\/em>\./);
});
