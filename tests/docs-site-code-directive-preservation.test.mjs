import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture, articleFromHTML } from './docs-site-fixture.mjs';
test('code example lines survive legacy directive cleanup', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n```text\n{: .literal }\nvalue {: .suffix }\n```\n\nOutside {: .removed }\n{: .standalone }\n'});
  const article = articleFromHTML(page.readPage());
  const code = article.match(/<pre><code[^>]*>([\s\S]*?)<\/code>/)[1];
  assert.equal(code, '{: .literal }\nvalue {: .suffix }');
  assert.match(article, /<p>Outside<\/p>/);
  assert.doesNotMatch(article, /removed|standalone/);
});

test('opening fence attributes are normalized while code content and following prose retain their roles', t => {
  const page = buildDocsFixture(t, {'index.md': '# Fixture\n\n```text {: .example }\nvalue {: .suffix }\n```\n\nFollowing prose {: .cleanup }\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<pre><code class="language-text">value \{: \.suffix \}<\/code><\/pre>/);
  assert.match(article, /<p>Following prose<\/p>/);
  assert.equal((article.match(/<pre>/g) || []).length, 1);
});

test('closing fence attributes are normalized so following prose stays outside code', t => {
  const page = buildDocsFixture(t, {'index.md': '# Fixture\n\n```text\nvalue\n``` {: .example }\n\nFollowing prose {: .cleanup }\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<pre><code class="language-text">value<\/code><\/pre>/);
  assert.match(article, /<p>Following prose<\/p>/);
  assert.doesNotMatch(article, /example|cleanup/);
});

test('a longer fence retained by the renderer cannot end directive preservation', t => {
  const page = buildDocsFixture(t, {'index.md': '# Fixture\n\n```text\n````\n{: .literal }\nvalue {: .suffix }\n```\n\nFollowing prose {: .cleanup }\n'});
  const article = articleFromHTML(page.readPage());
  const code = article.match(/<pre><code[^>]*>([\s\S]*?)<\/code>/)[1];
  assert.equal(code, '````\n{: .literal }\nvalue {: .suffix }');
  assert.match(article, /<p>Following prose<\/p>/);
});
