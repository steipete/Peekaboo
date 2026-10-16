import assert from 'node:assert/strict';
import test from 'node:test';
import { articleFromHTML, buildDocsFixture } from './docs-site-fixture.mjs';

function render(t, markdown) {
  return articleFromHTML(buildDocsFixture(t, { 'index.md': `# Fixture\n\n${markdown}` }).readPage());
}

test('indented items nest inside their parent item', (t) => {
  const article = render(t, '- top\n  - child one\n  - child two\n- next\n');
  assert.match(article, /<ul>\n<li>top\n<ul>\n<li>child one<\/li>\n<li>child two<\/li>\n<\/ul>\n<\/li>\n<li>next<\/li>\n<\/ul>/);
});

test('blank lines between numbered items keep one list and its numbering', (t) => {
  const article = render(t, '1. **First**\n   - a\n   - b\n\n2. **Second**\n   - c\n\n3. Third\n');
  assert.equal((article.match(/<ol/g) || []).length, 1);
  assert.doesNotMatch(article, /<ol start=/);
  assert.equal((article.match(/<li><strong>/g) || []).length, 2);
  assert.match(article, /<li>Third<\/li>/);
});

test('a wrapped item line continues the item text instead of becoming a stray paragraph', (t) => {
  const article = render(t, '- first line\n  wrapped with `code`\n- second\n');
  assert.match(article, /<li>first line wrapped with <code>code<\/code><\/li>/);
  assert.doesNotMatch(article, /<p>wrapped/);
});

test('a list still ends at a blank line followed by unindented prose', (t) => {
  const article = render(t, '- only\n\nAfter the list.\n');
  assert.match(article, /<\/ul>\n<p>After the list\.<\/p>/);
});

test('switching marker type at the same indentation starts a new list', (t) => {
  const article = render(t, '- bullet\n1. numbered\n');
  assert.match(article, /<ul>\n<li>bullet<\/li>\n<\/ul>\n<ol>\n<li>numbered<\/li>\n<\/ol>/);
});
