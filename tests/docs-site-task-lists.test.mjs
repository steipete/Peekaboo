import assert from 'node:assert/strict';
import test from 'node:test';
import { articleFromHTML, buildDocsFixture } from './docs-site-fixture.mjs';

function render(t, markdown) {
  return articleFromHTML(buildDocsFixture(t, { 'index.md': `# Fixture\n\n${markdown}` }).readPage());
}

test('task markers render as disabled checkboxes', (t) => {
  const article = render(t, '- [x] Done\n- [ ] Open\n  - [X] Nested\n');
  assert.match(article, /<li class="task"><input type="checkbox" disabled checked> Done<\/li>/);
  assert.match(article, /<li class="task"><input type="checkbox" disabled> Open\n<ul>\n<li class="task"><input type="checkbox" disabled checked> Nested<\/li>/);
  assert.doesNotMatch(article, /\[(?:x|X| )\]/);
});

test('a wrapped task line stays one checkbox item', (t) => {
  const article = render(t, '- [ ] first line\n  wrapped with `code`\n');
  assert.match(article, /<li class="task"><input type="checkbox" disabled> first line wrapped with <code>code<\/code><\/li>/);
  assert.doesNotMatch(article, /\[ \]/);
});
