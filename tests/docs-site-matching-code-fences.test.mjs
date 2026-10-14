import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture, articleFromHTML } from './docs-site-fixture.mjs';
test('long backtick fences retain shorter literal fences in code', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n````text\n```swift\nlet value = 1\n```\n````\n'});
  const article = articleFromHTML(page.readPage());
  assert.equal((article.match(/<pre>/g)||[]).length, 1);
  assert.match(article, /```swift/);
  assert.match(article, /let value = 1/);
});
test('tilde fences and matching closers produce code blocks', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n~~~text\nhello <world>\n~~~~\n'});
  assert.match(articleFromHTML(page.readPage()), /<pre><code class="language-text">hello &lt;world&gt;<\/code><\/pre>/);
});
