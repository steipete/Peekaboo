import assert from 'node:assert/strict';
import test from 'node:test';
import { updateAppcastEntry } from '../scripts/update-appcast-entry.mjs';
const entry = { version:'1.2.3', releaseUrl:'https://example.invalid/release', assetUrl:'https://example.invalid/app.zip', buildNumber:'123', zipLength:'12', edSignature:'signature', minimumSystemVersion:'14.0', pubDate:'Sun, 11 Oct 2026 00:00:00 +0000' };
const feed = '<rss><channel><language>en</language>\n</channel></rss>';
test('a prior item without a readable build cannot be silently discarded', () => {
  const old = updateAppcastEntry(feed, entry).replace('sparkle:version="123"', 'sparkle:version="invalid"');
  assert.throws(() => updateAppcastEntry(old, {...entry, zipLength:'13'}), /build number/);
});
test('missing prior version prevents an unverified replacement', () => {
  const old = updateAppcastEntry(feed, entry).replace('sparkle:shortVersionString="1.2.3"', '');
  assert.throws(() => updateAppcastEntry(old, {...entry, version:'1.2.4', buildNumber:'124'}), /version/);
});
test('healthy same-build replacements remain supported', () => {
  const old = updateAppcastEntry(feed, entry);
  assert.match(updateAppcastEntry(old, {...entry, zipLength:'13'}), /length="13"/);
});
