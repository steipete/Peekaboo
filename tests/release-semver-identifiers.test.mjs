import assert from 'node:assert/strict';
import test from 'node:test';
import { canonicalReleasePlan, canonicalPublicationReceipt } from '../scripts/release-driver-contract.mjs';
const sha='a'.repeat(40),hash='b'.repeat(64);
function plan(version) { return canonicalReleasePlan({sourceCommit:sha,version,helperCommit:sha,helperExecutableSHA256:hash,helperLibrarySHA256:hash}); }
function receipt(version) { return canonicalPublicationReceipt({sourceCommit:sha,version,checksumsSHA256:hash,githubBodySHA256:hash,assets:{'cli.tar.gz':{size:12,sha256:hash}}}); }
test('noncanonical numeric versions are refused before artifact planning',()=>{
  for(const version of ['01.2.3','1.02.3','1.2.03','1.2.3-beta.01']) {
    assert.throws(()=>plan(version),/version is invalid/);
    assert.throws(()=>receipt(version),/version is invalid/);
  }
});
test('valid zero and hyphenated prerelease identifiers remain valid',()=>{
  for(const version of ['0.2.3','1.2.3-beta.0','1.2.3-beta-test.1']) {
    assert.equal(plan(version).version,version);assert.equal(receipt(version).version,version);
  }
});
