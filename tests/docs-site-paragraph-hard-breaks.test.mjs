import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture, articleFromHTML } from './docs-site-fixture.mjs';
test('two spaces and a backslash create explicit paragraph breaks', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\nFirst  \nSecond\\\nThird\nsoft continuation\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<p>First<br>Second<br>Third soft continuation<\/p>/);
});
test('code spans keep code text and backslashes instead of breaks', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n`literal  \ncode` and `slash\\\ncode`\n'});
  const article = articleFromHTML(page.readPage());
  assert.doesNotMatch(article, /<br>/);
  assert.match(article, /<code>literal  [\n ]code<\/code>/);
});

test('escaped trailing backslashes remain soft wraps, while odd runs retain a hard break', t => {
  const even = buildDocsFixture(t, {'index.md': '# Fixture\n\nPair' + '\\'.repeat(2) + '\ncontinuation\n'});
  const evenArticle = articleFromHTML(even.readPage());
  assert.doesNotMatch(evenArticle, /<br>/);
  assert.ok(evenArticle.includes('Pair' + '\\' + ' continuation'));
  assert.ok(!evenArticle.includes('Pair' + '\\'.repeat(2)));
  const odd = buildDocsFixture(t, {'index.md': '# Fixture\n\nTriple' + '\\'.repeat(3) + '\ncontinuation\n'});
  const oddArticle = articleFromHTML(odd.readPage());
  assert.ok(oddArticle.includes('Triple' + '\\' + '<br>continuation'));
  assert.ok(!oddArticle.includes('Triple' + '\\'.repeat(2)));
  const four = buildDocsFixture(t, {'index.md': '# Fixture\n\nFour' + '\\'.repeat(4) + '\ncontinuation\n'});
  assert.ok(articleFromHTML(four.readPage()).includes('Four' + '\\'.repeat(2) + ' continuation'));
});
