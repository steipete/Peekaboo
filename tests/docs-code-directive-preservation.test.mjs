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
