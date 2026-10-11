import assert from 'node:assert/strict';
import test from 'node:test';
import { spawnSync } from 'node:child_process';
import { mkdtempSync,writeFileSync,rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
test('bounded process waiting preserves an existing native observer',t=>{
  const root=mkdtempSync(join(tmpdir(),'peekaboo-process-handler-'));t.after(()=>rmSync(root,{recursive:true,force:true}));
  const harness=join(root,'Harness.swift'),binary=join(root,'contract');
  writeFileSync(harness,`import Foundation
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    func increment() { lock.lock(); defer { lock.unlock() }; count += 1 }
    func value() -> Int { lock.lock(); defer { lock.unlock() }; return count }
}
@main struct ContractHarness {
    static func main() throws {
        let counter = Counter()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["0.1"]
        process.terminationHandler = { _ in counter.increment() }
        try process.run()
        try waitForProcessExit(process, timeoutSeconds: 3)
        let deadline = Date().addingTimeInterval(2)
        while counter.value() == 0, Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
        print(counter.value())
    }
}
`);
  const build=spawnSync('/usr/bin/xcrun',['swiftc','-parse-as-library',fileURLToPath(new URL('../Apps/CLI/Sources/PeekabooCLI/Helpers/ProcessWait.swift',import.meta.url)),harness,'-o',binary],{encoding:'utf8',timeout:60000});
  assert.equal(build.status,0,build.stderr);
  const result=spawnSync(binary,[],{encoding:'utf8',timeout:10000});
  assert.equal(result.status,0,result.stderr);assert.equal(result.stdout,'1\n');
});
