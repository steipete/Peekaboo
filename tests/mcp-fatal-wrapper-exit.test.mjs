import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { mkdtempSync,writeFileSync,copyFileSync,rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
for(const kind of ['exception','rejection']) test(`fatal ${kind} shuts down with a failure exit`,t=>{
  const root=mkdtempSync(join(tmpdir(),'peekaboo-fatal-wrapper-'));t.after(()=>rmSync(root,{recursive:true,force:true}));
  const wrapper=join(root,'peekaboo-mcp.mjs');copyFileSync(new URL('../peekaboo-mcp.js',import.meta.url),wrapper);
  writeFileSync(join(root,'peekaboo'),'#!/bin/sh\ntrap "exit 0" TERM\nwhile :; do sleep 0.05; done\n',{mode:0o755});
  const failure=kind==='exception'?'throw new Error("fixture failure")':'Promise.reject(new Error("fixture failure"))';
  const preload=`setTimeout(()=>{${failure}},50);setTimeout(()=>process.kill(process.pid,'SIGTERM'),400);`;
  const result=spawnSync(process.execPath,['--import','data:text/javascript,'+encodeURIComponent(preload),wrapper],{encoding:'utf8',timeout:5000});
  assert.equal(result.error,undefined);assert.equal(result.signal,null);assert.equal(result.status,1,result.stderr);
  assert.match(result.stderr,/fixture failure/);
});
