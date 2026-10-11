import assert from 'node:assert/strict';
import test from 'node:test';
import { validateGitHubRelease, githubReleaseAssetsNeedingUpload } from '../scripts/release-driver-contract.mjs';
const sha='a'.repeat(40);
const expectedAssets={'cli.tar.gz':{size:12,sha256:'b'.repeat(64)}};
const asset={name:'cli.tar.gz',size:12,digest:'sha256:'+'b'.repeat(64)};
const release={tag_name:'v1.2.3',draft:true,body:'notes',assets:[{...asset,state:'starter'}]};
const input={release,version:'1.2.3',sourceCommit:sha,tagCommit:sha,expectedAssets,expectedBody:'notes',expectDraft:true};
test('unfinished API assets require repair even when retained bytes match', () => {
  assert.throws(() => validateGitHubRelease(input), /upload is incomplete/);
  assert.deepEqual(githubReleaseAssetsNeedingUpload({assets:release.assets,expectedAssets}), ['cli.tar.gz']);
  assert.deepEqual(validateGitHubRelease({...input,allowAssetRepair:true}), ['cli.tar.gz']);
});
test('completed uploads and legacy inventories without state remain compatible', () => {
  for (const complete of [{...asset,state:'uploaded'},asset]) {
    assert.doesNotThrow(() => validateGitHubRelease({...input,release:{...release,assets:[complete]}}));
  }
});
