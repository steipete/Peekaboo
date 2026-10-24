import assert from 'node:assert/strict';
import test from 'node:test';
import { buildDocsFixture } from './docs-site-fixture.mjs';

function renderCode(t, language, source) {
  const html = buildDocsFixture(t, {
    'index.md': `# Fixture\n\n\`\`\`${language}\n${source}\n\`\`\`\n`,
  }).readPage();
  const code = html.match(/<pre><code[^>]*>([\s\S]*?)<\/code><\/pre>/)?.[1];
  assert.ok(code !== undefined, 'missing rendered code block');
  let text = code.replaceAll('</span>', '');
  for (const cls of ['hl-s', 'hl-c', 'hl-p', 'hl-f', 'hl-cmd', 'hl-n', 'hl-k', 'hl-m', 'hl-t']) {
    text = text.replaceAll(`<span class="${cls}">`, '');
  }
  const copyable = text.replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
  assert.equal(copyable, source);
  return code;
}

test('string URLs stay strings while real comments stay comments', (t) => {
  const js = renderCode(
    t,
    'js',
    'const url = "https://example.com/a"; // see https://example.com\n/* "quoted" */',
  );
  assert.match(js, /class="hl-s">&quot;https:\/\/example.com\/a&quot;/);
  assert.match(js, /class="hl-c">\/\/ see https:\/\/example.com/);
  assert.match(js, /class="hl-c">\/\* &quot;quoted&quot; \*\//);

  const swift = renderCode(t, 'swift', 'let baseURL = URL(string: "https://api.x.ai/v1")!');
  assert.match(swift, /class="hl-s">&quot;https:\/\/api\.x\.ai\/v1&quot;/);
  assert.doesNotMatch(swift, /class="hl-c"/);
});
