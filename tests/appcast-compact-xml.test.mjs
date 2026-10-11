import assert from 'node:assert/strict';
import test from 'node:test';
import { updateAppcastEntry } from '../scripts/update-appcast-entry.mjs';
const entry = { version:'1.2.3', releaseUrl:'https://example.invalid/release', assetUrl:'https://example.invalid/app.zip', buildNumber:'123', zipLength:'12', edSignature:'signature', minimumSystemVersion:'14.0', pubDate:'Sun, 11 Oct 2026 00:00:00 +0000' };
const feed = '<rss><channel><language>en</language>\n</channel></rss>';
test('compact XML remains replaceable without duplicate published versions', () => {
  const first = updateAppcastEntry(feed, entry);
  const compact = first.replace(/>\s+</g, '><');
  const replacement = updateAppcastEntry(compact, {...entry, zipLength:'13'});
  assert.equal((replacement.match(/<item>/g) || []).length, 1);
  assert.match(replacement, /length="13"/);
  assert.equal(updateAppcastEntry(replacement, {...entry, zipLength:'13'}), replacement);
});
test('empty compact feeds accept their first item', () => {
  assert.match(updateAppcastEntry(feed.replace('\n', ''), entry), /<item>/);
});
