import assert from 'node:assert/strict';
import test from 'node:test';
import { updateAppcastEntry } from '../scripts/update-appcast-entry.mjs';
const entry = { version:'1.2.3', releaseUrl:'https://example.invalid/release', assetUrl:'https://example.invalid/app.zip', buildNumber:'123', zipLength:'12', edSignature:'signature', minimumSystemVersion:'14.0', pubDate:'Sun, 11 Oct 2026 00:00:00 +0000' };
const feed = '<rss><channel><language>en</language>\n</channel></rss>';
test('invalid artifact lengths never become published enclosure lengths', () => {
  for (const zipLength of ['0', '-1', 'NaN', '1.5', '']) {
    assert.throws(() => updateAppcastEntry(feed, {...entry, zipLength}), /length|zipLength/);
  }
});
test('missing required artifact metadata cannot serialize as undefined', () => {
  for (const name of ['version','releaseUrl','assetUrl','edSignature','minimumSystemVersion','pubDate']) {
    const incomplete = {...entry}; delete incomplete[name];
    assert.throws(() => updateAppcastEntry(feed, incomplete), /required/);
  }
});
test('valid large archive lengths retain exact decimal text', () => {
  assert.match(updateAppcastEntry(feed, {...entry, zipLength:'9007199254740993'}), /length="9007199254740993"/);
});
