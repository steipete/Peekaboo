import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture, articleFromHTML } from './docs-site-fixture.mjs';
test('underscores and asterisks in URLs remain literal destinations', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n[**API**](https://example.invalid/a_b_c?q=*literal*)&x\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<a href="https:\/\/example.invalid\/a_b_c\?q=\*literal\*"><strong>API<\/strong><\/a>/);
  assert.doesNotMatch(article, /href="[^"]*<(?:em|strong)>/);
});
test('code labels and literal entity query values survive destination protection', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n[`API`](https://example.invalid/?literal=&amp;)\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /href="https:\/\/example.invalid\/\?literal=&amp;amp;"/);
  assert.match(article, /<code>API<\/code><\/a>/);
});
test('literal link syntax inside inline code remains literal',t=>{
 const page=buildDocsFixture(t,{'index.md':'# Fixture\n\n`[link](https://example.invalid/a_b_c)`\n'});
 const article=articleFromHTML(page.readPage());
 assert.match(article,/<code>\[link\]\(https:\/\/example.invalid\/a_b_c\)<\/code>/);
 assert.doesNotMatch(article,/<a href="https:\/\/example.invalid/);
});

test('protected link labels keep literal punctuation and entities', t => {
 const page=buildDocsFixture(t, {'index.md':'# Fixture\n\n[`a_b * c & <tag>` **API**](https://example.invalid/a_b?q=*x*)\n'});
 const article=articleFromHTML(page.readPage());
 assert.match(article, /<a href="https:\/\/example.invalid\/a_b\?q=\*x\*"><code>a_b \* c &amp; &lt;tag&gt;<\/code> <strong>API<\/strong><\/a>/);
 assert.doesNotMatch(article, /undefined|\u0000/);
});

test('link destinations restore literal backticks and escaped pipes without HTML', t => {
  const page = buildDocsFixture(t, {'index.md': '# Fixture\n\n[API](https://example.invalid/`a_b`?q=x\\|y&literal=&amp;)\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /href="https:\/\/example.invalid\/`a_b`\?q=x\|y&amp;literal=&amp;amp;"/);
  assert.doesNotMatch(article, /\u0000|href="[^"\n]*<code>/);
});

test('autolinks preserve literal emphasis punctuation and escape URLs once', t => {
  const url = 'https://example.invalid/X_AI_docs?q=*literal*&other="quoted"&entity=&amp;';
  const escapedURL = 'https://example.invalid/X_AI_docs?q=*literal*&amp;other=&quot;quoted&quot;&amp;entity=&amp;amp;';
  const page = buildDocsFixture(t, {'index.md': `# Fixture\n\n<${url}> and **API**\n`});
  const article = articleFromHTML(page.readPage());
  assert.ok(article.includes(`<a href="${escapedURL}">${escapedURL}</a> and <strong>API</strong>`));
  assert.doesNotMatch(article, /<em>|\u0000/);
});

test('autolinks restore literal code punctuation while inline code stays literal', t => {
  const page = buildDocsFixture(t, {'index.md': '# Fixture\n\n<https://example.invalid/`a_b_c`?q=x\\|y>\n\n`<https://example.invalid/a_b_c>`\n'});
  const article = articleFromHTML(page.readPage());
  assert.ok(article.includes('<a href="https://example.invalid/`a_b_c`?q=x|y">https://example.invalid/`a_b_c`?q=x|y</a>'));
  assert.ok(article.includes('<code>&lt;https://example.invalid/a_b_c&gt;</code>'));
  assert.doesNotMatch(article, /<em>|\u0000/);
});
