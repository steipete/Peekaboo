import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture, articleFromHTML } from './docs-site-fixture.mjs';
test('unbordered Markdown tables retain columns and alignment', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\nName | Value\n--- | ---:\none | `two`\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<th>Name<\/th><th style="text-align:right">Value<\/th>/);
  assert.match(article, /<td>one<\/td><td style="text-align:right"><code>two<\/code><\/td>/);
});
test('single-column tables render while mismatched separators stay prose', t => {
  const page = buildDocsFixture(t, {'index.md':'# Fixture\n\n| Option |\n| --- |\n| --json |\n\nName | Value\n---\n'});
  const article = articleFromHTML(page.readPage());
  assert.equal((article.match(/<table>/g)||[]).length,1);
  assert.match(article, /<td>--json<\/td>/);
  assert.match(article, /<p>Name \| Value<\/p>/);
});

test('a pipeless thematic break does not become a one-column delimiter', t => {
  for (const header of ['| Header |', 'Left\\|Right', '`code|pipe`']) {
    const page = buildDocsFixture(t, {'index.md': `# Fixture\n\n${header}\n---\n`});
    const article = articleFromHTML(page.readPage());
    assert.doesNotMatch(article, /<table>/);
    assert.match(article, /<hr\s*\/?\s*>/);
  }
});

test('plain single-column rows are consumed while following block openers retain their structure', t => {
  const page = buildDocsFixture(t, {'index.md': '# Fixture\n\n| Option |\n| --- |\nverbose\n## Input | Output\n\n| Name | Value |\n| --- | --- |\n| one | two |\n- list | retained\n\n| Name | Value |\n| --- | --- |\n| one | two |\n> quote | retained\n'});
  const article = articleFromHTML(page.readPage());
  assert.match(article, /<td>verbose<\/td>/);
  assert.match(article, /<h2 id="input-output">/);
  assert.match(article, /<li>list \| retained<\/li>/);
  assert.match(article, /<blockquote>[\s\S]*quote \| retained/);
  assert.doesNotMatch(article, /<td>## Input|<td>- list|<td>&gt; quote/);
});
