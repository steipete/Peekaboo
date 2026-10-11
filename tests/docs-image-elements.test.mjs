import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture, articleFromHTML } from './docs-site-fixture.mjs';
test('Markdown screenshots render accessible lazy images', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n![Window & controls](https://example.invalid/screen.png?a=1&b=2)\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<img src="https:\/\/example.invalid\/screen.png\?a=1&amp;b=2" alt="Window &amp; controls" loading="lazy">/);
  assert.doesNotMatch(article, /!<a/);
});
test('decorative image alt text can remain empty', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n![](https://example.invalid/icon.png)\n'});
  assert.match(articleFromHTML(page.readPage()), /alt=""/);
});
test('literal image syntax inside code remains copyable Markdown',t=>{
 const page=buildDocsFixture(t,{'index.md':'# Fixture\n\n`![alt](https://example.invalid/image.png)`\n'});
 const article=articleFromHTML(page.readPage());
 assert.match(article,/<code>!\[alt\]\(https:\/\/example.invalid\/image.png\)<\/code>/);
 assert.doesNotMatch(article,/<img/);
});

test('code in image alt becomes literal accessible text once', t => {
 const page=buildDocsFixture(t, {'index.md':'# Fixture\n\n![`a_b * c & <tag>`](screen.png)\n'});
 const article=articleFromHTML(page.readPage());
 assert.match(article, /src="screen.png" alt="a_b \* c &amp; &lt;tag&gt;"/);
 assert.doesNotMatch(article, /undefined|\u0000|alt="[^"]*<code>/);
});
