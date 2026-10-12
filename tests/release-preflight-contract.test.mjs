import assert from 'node:assert/strict';
import { execFileSync, execSync, spawnSync } from 'node:child_process';
import {
  chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync,
  rmSync, statSync, symlinkSync, writeFileSync
} from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { runInNewContext } from 'node:vm';

import {
  REMOVED_ROOT_COMMANDS,
  parseMigrationAdvisorForms,
  parseRegistryCommands,
  releaseFreshnessReference,
  validateChangelogContract,
  validateCommandDocsContract,
  validateMigrationGuideContract,
  validateNpmVersionAvailability,
  validateSourceDocumentationContracts,
  validateVersionConsistency,
  validateVersionValues
} from '../scripts/release-preflight-contract.mjs';

const projectRoot = fileURLToPath(new URL('..', import.meta.url));

test('CLI preflight covers all ten removed v4 root commands', () => {
  assert.deepEqual(REMOVED_ROOT_COMMANDS, [
    'image',
    'list',
    'hotkey',
    'inspect-ui',
    'perform-action',
    'swipe',
    'sleep',
    'open',
    'run',
    'commander'
  ]);
});

test('preparation accepts Unreleased while publication requires a dated heading', () => {
  const changelogSource = '# Changelog\n\n## [4.0.0] - Unreleased\n\n- Pending.\n';
  assert.deepEqual(validateChangelogContract({
    changelogSource,
    version: '4.0.0',
    requireDatedHeading: false
  }), []);
  assert.deepEqual(validateChangelogContract({
    changelogSource,
    version: '4.0.0',
    requireDatedHeading: true
  }), ["full publication preflight requires '## 4.0.0 - YYYY-MM-DD' (version brackets optional); found Unreleased"]);
});

test('publication accepts only an exact heading with a valid ISO calendar date', () => {
  assert.deepEqual(validateChangelogContract({
    changelogSource: '## [4.0.0] - 2026-08-10\n',
    version: '4.0.0',
    requireDatedHeading: true
  }), []);
  assert.match(validateChangelogContract({
    changelogSource: '### 4.0.0 (2026-08-10)\n',
    version: '4.0.0',
    requireDatedHeading: true
  })[0], /must contain exactly/);
  assert.match(validateChangelogContract({
    changelogSource: '## [4.0.0] - 2026-02-30\n',
    version: '4.0.0',
    requireDatedHeading: true
  })[0], /invalid release date/);
  assert.deepEqual(validateChangelogContract({
    changelogSource: '## [4.0.0] - Unreleased\n\n## [4.0.0] - 2026-08-10\n',
    version: '4.0.0',
    requireDatedHeading: false
  }), [
    "CHANGELOG.md must contain exactly one '## 4.0.0 - Unreleased' or dated ISO heading " +
      "(version brackets optional); found 2"
  ]);
});

test('publication accepts plain version headings while preserving date and uniqueness checks', () => {
  const validate = (changelogSource, requireDatedHeading = true) => validateChangelogContract({
    changelogSource,
    version: '4.3.1',
    requireDatedHeading
  });
  assert.deepEqual(validate('## 4.3.1 - 2026-09-05\n'), []);
  assert.deepEqual(validate('## 4.3.1 - Unreleased\n', false), []);
  assert.match(validate('## 4.3.1 - Unreleased\n')[0], /requires.*YYYY-MM-DD.*Unreleased/);
  assert.match(validate('## 4.3.1 - 2026-02-30\n')[0], /invalid release date/);
  assert.match(validate('## 4.3.1 - 2026-09-05\n\n## [4.3.1] - 2026-09-05\n')[0], /found 2/);
  for (const heading of ['## [4.3.1 - 2026-09-05', '## 4.3.1] - 2026-09-05', '## 4.3.10 - 2026-09-05']) {
    assert.match(validate(`${heading}\n`)[0], /found 0/);
  }
});

test('current root and CLI release headings pass the preparation gate', () => {
  const { version } = JSON.parse(readFileSync(join(projectRoot, 'package.json'), 'utf8'));
  for (const path of ['CHANGELOG.md', 'Apps/CLI/CHANGELOG.md']) {
    assert.deepEqual(validateChangelogContract({
      changelogSource: readFileSync(join(projectRoot, path), 'utf8'),
      version,
      requireDatedHeading: false
    }), [], path);
  }
});

test('command registry roots must have exact page, index, and reference parity', () => {
  const registrySource = `
    .init(type: AlphaCommand.self, category: .core),
    .init(type: MenuBarCommand.self, category: .system),
    .init(type: SetValueCommand.self, category: .interaction),
  `;
  assert.deepEqual(parseRegistryCommands(registrySource), ['alpha', 'menubar', 'set-value']);

  const values = {
    registrySource,
    commandPages: ['README.md', 'alpha.md', 'menubar.md', 'set-value.md'],
    indexSource: '[`alpha`](alpha.md) [`menubar`](menubar.md) [`set-value`](set-value.md)',
    referenceSource: '[`alpha`](commands/alpha.md) [`menubar`](commands/menubar.md) ' +
      '[`set-value`](commands/set-value.md)',
    expectedCount: 3
  };
  assert.deepEqual(validateCommandDocsContract(values), []);

  const failures = validateCommandDocsContract({
    ...values,
    commandPages: ['README.md', 'alpha.md', 'menubar.md'],
    referenceSource: '[`alpha`](commands/alpha.md) [`menubar`](commands/menubar.md) ' +
      '[`wrong-label`](commands/set-value.md)'
  });
  assert.ok(failures.some((failure) => failure.includes('docs/commands pages missing: set-value')));
  assert.ok(failures.some((failure) => failure.includes("label 'wrong-label'")));
});

test('migration guide covers every mapping extracted from CommanderMigrationAdvisor', () => {
  const advisorSource = `
    private static let removedRootReplacements: [String: String] = ["hotkey": "press"]
    private static let removedPathReplacements: [String: String] = ["config add": "config credential set"]
    private static let removedOptionReplacements: [String: String] = ["--old": "--new"]
    private static let removedAgentModeReplacements: [String: String] = ["--chat": "agent chat"]
    private static let removedTypeKeyReplacements = Set(["--return"])
  `;
  assert.deepEqual(parseMigrationAdvisorForms(advisorSource), [
    'hotkey', 'config add', '--old', '--chat', '--return'
  ]);

  const removedRootRows = REMOVED_ROOT_COMMANDS.map((command) =>
    `| \`peekaboo ${command} example\` | \`replacement for ${command}\` |`
  );
  const guide = [
    '| Old | New |',
    '|---|---|',
    ...removedRootRows,
    '| `config add value` | `config credential set` |',
    '| `--old` | `--new` |',
    '| `--chat` | `agent chat` |',
    '| `--return` | `press Return` |'
  ].join('\n');
  assert.deepEqual(validateMigrationGuideContract({ advisorSource, migrationGuideSource: guide }), []);

  const failures = validateMigrationGuideContract({
    advisorSource,
    migrationGuideSource: guide.replace('| `--old` | `--new` |', '')
  });
  assert.deepEqual(failures, [
    'docs/v4-migration.md is missing CommanderMigrationAdvisor mappings for: --old'
  ]);
});

test('version parity reports missing and stale release surfaces', () => {
  const failures = validateVersionValues({
    expectedVersion: '4.0.0',
    values: {
      package: '4.0.0',
      CLI: '3.10.0',
      Playground: [],
      Inspector: ['4.0.0', '4.0.0']
    }
  });
  assert.deepEqual(failures, [
    'CLI version mismatch: expected 4.0.0, found 3.10.0',
    'Playground version field is missing'
  ]);
});

test('release freshness compares a forced release branch against its own pushed branch only', () => {
  assert.deepEqual(releaseFreshnessReference({ branch: 'release/4.9.0', version: '4.9.0', force: true }),
    { remoteRef: 'origin/release/4.9.0', releaseBranch: true });
  for (const request of [
    { branch: 'main', version: '4.9.0', force: false },
    { branch: 'main', version: '4.9.0', force: true },
    { branch: 'release/4.9.0', version: '4.9.0', force: false },
    { branch: 'release/4.8.0', version: '4.9.0', force: true },
    { branch: 'feature/x', version: '4.9.0', force: true },
    { branch: 'release/', version: '', force: true }
  ]) {
    assert.deepEqual(releaseFreshnessReference(request), { remoteRef: 'origin/main', releaseBranch: false },
      JSON.stringify(request));
  }
});

test('publication preflight routes its freshness comparison through the release policy', () => {
  assert.match(prepareSource, /releaseFreshnessReference\(\{ branch: currentBranch, version, force \}\)/);
  assert.match(prepareSource, /git rev-list HEAD\.\.\$\{remoteRef\} --count/);
  // A release branch is checked against the live remote, never a possibly stale tracking ref.
  assert.match(prepareSource, /\['ls-remote', '--exit-code', 'origin', `refs\/heads\/\$\{currentBranch\}`\]/);
  assert.match(prepareSource, /does not match the pushed \$\{remoteRef\}/);
  assert.doesNotMatch(prepareSource, /git rev-list HEAD\.\.origin\/main --count'\);\n\s*const ahead/);
});

test('npm version availability fails closed on failed, empty, and malformed registry responses', () => {
  const request = { packageName: '@steipete/peekaboo', version: '4.2.2' };

  for (const registryOutput of [null, undefined, '', '   ']) {
    assert.match(
      validateNpmVersionAvailability({ ...request, registryOutput })[0],
      /registry query failed or returned no data.*npm view @steipete\/peekaboo versions --json/
    );
  }

  assert.match(
    validateNpmVersionAvailability({ ...request, registryOutput: 'npm ERR! offline' })[0],
    /registry returned invalid JSON/
  );
  for (const registryOutput of ['{}', 'null', '["4.2.0", 422]', '[""]']) {
    assert.match(
      validateNpmVersionAvailability({ ...request, registryOutput })[0],
      /registry returned an invalid version list/
    );
  }
});

test('npm version availability accepts valid registry lists and rejects an already published version', () => {
  const request = { packageName: '@steipete/peekaboo', version: '4.2.2' };

  for (const registryOutput of ['[]', '["4.2.0", "4.2.1"]', '"4.2.0"']) {
    assert.deepEqual(validateNpmVersionAvailability({ ...request, registryOutput }), []);
  }

  for (const registryOutput of ['["4.2.0", "4.2.2"]', '"4.2.2"']) {
    assert.deepEqual(validateNpmVersionAvailability({ ...request, registryOutput }), [
      'Version 4.2.2 is already published on npm!',
      'Please update the version in package.json before releasing.'
    ]);
  }
});

const prepareSource = readFileSync(new URL('../scripts/prepare-release.js', import.meta.url), 'utf8');
const sanitizerPath = join(projectRoot, 'scripts/terminal-artifact-env.sh');
const safeTestsFunction = prepareSource.match(/^function runSafeTests\(\) \{[\s\S]*?^\}/m)?.[0];

function verifyBinaryFixture(t, {
  name = 'peekaboo',
  mode = 0o755,
  missing = false,
  symlink = false,
  statFailure = false,
  universal = false,
  architectures = 'arm64',
  lipoExit = 0,
  help = '  fixture help \u00e9\n',
  helpExit = 0
} = {}) {
  const root = realpathSync(mkdtempSync(join(tmpdir(), 'peekaboo-binary-contract-')));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const tools = join(root, 'tools');
  const binaryPath = join(root, name);
  const callLog = join(root, 'calls.jsonl');
  const messages = [];
  const shellCalls = [];
  mkdirSync(tools);
  writeFileSync(join(root, 'package.json'), '{"version":"1.2.3"}\n');
  const toolSource = (tool) => `#!${process.execPath}
const fs = require('node:fs');
fs.appendFileSync(process.env.FIXTURE_CALL_LOG, JSON.stringify({
  tool: ${JSON.stringify(tool)}, args: process.argv.slice(2), cwd: process.cwd()
}) + '\\n');
process.stdout.write(process.env.${tool.toUpperCase()}_OUTPUT);
process.exit(Number(process.env.${tool.toUpperCase()}_EXIT));
`;
  writeFileSync(join(tools, 'lipo'), toolSource('lipo'), { mode: 0o755 });
  if (!missing) {
    const target = symlink ? join(root, 'target-binary') : binaryPath;
    writeFileSync(target, toolSource('binary'));
    chmodSync(target, mode);
    if (symlink) symlinkSync(target, binaryPath);
  }
  const env = {
    PATH: `${tools}:/usr/bin:/bin`,
    HOME: root,
    TMPDIR: root,
    LANG: 'C',
    FIXTURE_CALL_LOG: callLog,
    LIPO_OUTPUT: architectures,
    LIPO_EXIT: String(lipoExit),
    BINARY_OUTPUT: help,
    BINARY_EXIT: String(helpExit),
    PEEKABOO_REQUIRE_UNIVERSAL: universal ? '1' : '0'
  };
  const execFunction = prepareSource.match(/^function exec\(command, options = \{\}\) \{[\s\S]*?^\}/m)?.[0];
  const verifyFunction = prepareSource.match(/^function buildAndVerifyPackage\(\) \{[\s\S]*?^\}/m)?.[0];
  assert.ok(execFunction && verifyFunction, 'inspect the actual checks without invoking main');
  const legacyCommands = new Set([
    `stat -f "%Lp" "${binaryPath}" 2>/dev/null || stat -c "%a" "${binaryPath}"`,
    `lipo -info "${binaryPath}"`,
    `"${binaryPath}" --help`
  ]);
  const verify = runInNewContext(`${execFunction}\n${verifyFunction}\nbuildAndVerifyPackage`, {
    projectRoot: root, binaryOverride: binaryPath, noBuild: true, colors: {},
    process: { env }, join, existsSync, readFileSync,
    statSync(path) {
      if (statFailure) throw new Error('fixture stat failure');
      return statSync(path);
    },
    execSync(command, options) {
      shellCalls.push(command);
      // Refuse hostile red-phase commands before any shell or marker can run.
      if (!legacyCommands.has(command) || /["$`]/.test(binaryPath)) {
        throw new Error('fixture refused shell interpretation of the binary path');
      }
      return execSync(command, { ...options, env, timeout: 5000 });
    },
    execFileSync(file, args, options) {
      assert.ok(file === 'lipo' || file === binaryPath, 'only fixture tools may execute');
      if (file === binaryPath) {
        assert.equal(options.timeout, 30_000);
        assert.equal(options.killSignal, 'SIGKILL');
      }
      return execFileSync(file, Array.from(args), { ...options, env, timeout: 5000 });
    },
    execNpm() { return 'peekaboo\npeekaboo-mcp.js\nREADME.md\nLICENSE\n'; },
    execWithOutput() { assert.fail('binary verification must not build a release'); },
    logStep() {},
    log(message) { messages.push(message); },
    logSuccess(message) { messages.push(message); },
    logWarning(message) { messages.push(message); },
    logError(message) { messages.push(message); }
  });
  const passed = verify();
  const calls = existsSync(callLog)
    ? readFileSync(callLog, 'utf8').trim().split('\n').map((line) => JSON.parse(line))
    : [];
  for (const marker of ['dollar-marker', 'backtick-marker']) {
    assert.equal(existsSync(join(root, marker)), false, 'path text must never run a marker command');
  }
  return { passed, calls, messages, shellCalls, root, binaryPath };
}

for (const name of [
  'peekaboo with spaces',
  "peekaboo 'single quotes'",
  'peekaboo "double quotes"',
  'peekaboo $(touch dollar-marker)',
  'peekaboo `touch backtick-marker`'
]) {
  test(`binary verification passes a literal filename: ${name}`, (t) => {
    const result = verifyBinaryFixture(t, { name });
    assert.equal(result.passed, true, `${name}: ${result.messages.join('\n')}`);
    assert.deepEqual(result.shellCalls, [], 'binary verification must not invoke a shell');
    assert.deepEqual(result.calls, [
      { tool: 'lipo', args: ['-info', result.binaryPath], cwd: result.root },
      { tool: 'binary', args: ['--help'], cwd: result.root }
    ]);
  });
}

test('binary verification follows symlinks and accepts owner-only executable permission', (t) => {
  for (const symlink of [false, true]) {
    const result = verifyBinaryFixture(t, { symlink, mode: 0o744 });
    assert.equal(result.passed, true, result.messages.join('\n'));
    assert.deepEqual(result.calls.map((call) => call.tool), ['lipo', 'binary']);
    assert.deepEqual(result.calls[0].args, ['-info', result.binaryPath]);
  }
});

test('binary verification preserves permission, architecture, and command failures', (t) => {
  const cases = [
    [{ missing: true }, 'peekaboo binary not found', []],
    [{ mode: 0o644 }, 'peekaboo binary is not executable', []],
    [{ statFailure: true }, 'Failed to check binary permissions', []],
    [{ architectures: ' \nx86_64 \n' }, 'peekaboo binary is missing arm64', ['lipo']],
    [{ universal: true }, 'peekaboo binary does not contain x86_64', ['lipo']],
    [{ lipoExit: 31 }, 'Failed to check binary architectures (lipo command failed)', ['lipo']],
    [{ help: '' }, 'peekaboo binary does not respond to --help command', ['lipo', 'binary']],
    [{ help: ' \t\n' }, 'peekaboo binary does not respond to --help command', ['lipo', 'binary']],
    [{ helpExit: 29 }, 'peekaboo binary failed to execute with --help', ['lipo', 'binary']],
    // Any executable bit passes the mode gate, even when this owner cannot execute.
    [{ mode: 0o654 }, 'peekaboo binary failed to execute with --help', ['lipo']]
  ];
  for (const [options, diagnostic, tools] of cases) {
    const result = verifyBinaryFixture(t, options);
    assert.equal(result.passed, false, JSON.stringify(options));
    assert.ok(result.messages.some((message) => message.includes(diagnostic)),
      `${JSON.stringify(options)}: ${result.messages.join('\n')}`);
    assert.deepEqual(result.calls.map((call) => call.tool), tools);
    if (options.architectures) assert.ok(result.messages.includes('Found: x86_64'));
    if (options.helpExit) assert.ok(result.messages.some((message) => message.startsWith('Error: ')));
  }
});

test('binary verification requires x86_64 only in universal mode', (t) => {
  for (const universal of [false, true]) {
    const result = verifyBinaryFixture(t, { universal, architectures: ' \narm64 x86_64 \n' });
    assert.equal(result.passed, true, result.messages.join('\n'));
    assert.ok(result.messages.includes('Binary contains both arm64 and x86_64 architectures'));
  }
  const arm = verifyBinaryFixture(t);
  assert.equal(arm.passed, true, arm.messages.join('\n'));
  assert.ok(arm.messages.includes('Binary is arm64-only (set PEEKABOO_REQUIRE_UNIVERSAL=1 to enforce universal)'));
});

function cliProbeFixture({ failArgs, errorCode = 'ETIMEDOUT' } = {}) {
  const messages = [];
  const calls = [];
  const replacements = new Map(REMOVED_ROOT_COMMANDS.map((command) => [command, `replacement ${command}`]));
  const source = prepareSource.match(/^function checkSwiftCLIIntegration\(binaryPath\) \{[\s\S]*?^\}/m)?.[0];
  assert.ok(source);
  const check = runInNewContext(`${source}; checkSwiftCLIIntegration`, {
    projectRoot, join, existsSync: () => true, readFileSync: () => '',
    MIGRATION_ADVISOR_PATH: 'fixture', REMOVED_ROOT_COMMANDS,
    parseRemovedRootReplacements: () => replacements,
    logStep() {}, logSuccess() {}, logError(message) { messages.push(message); },
    spawnSync(binary, args, options) {
      calls.push({ args: Array.from(args), options });
      let stdout;
      if (args[0] === 'invalid-command') stdout = "Unknown command 'invalid-command'";
      else if (replacements.has(args[0])) stdout = `Command 'peekaboo ${args[0]}' was removed in v4. Use '${replacements.get(args[0])}'.`;
      else if (args.includes('--json')) stdout = JSON.stringify({ success: true, data: { apps: [], windows: [], screens: [] } });
      else stdout = '--no-elements --tree --no-screenshot --at --wait-for --long-press --delay --hold cmd+shift+t AXPress --on --from --to --button --duration --foreground peekaboo app list --include-hidden peekaboo window list --group-by-space peekaboo screen list';
      const failed = JSON.stringify(Array.from(args)) === JSON.stringify(failArgs);
      return {
        stdout, status: failed ? null : (args[0] === 'invalid-command' || replacements.has(args[0]) ? 1 : 0),
        ...(failed ? { error: Object.assign(new Error('fixture process error'), { code: errorCode }) } : {})
      };
    }
  });
  return { passed: check('/fixture/peekaboo'), calls, messages };
}

test('CLI probe failures cannot pass on partial expected diagnostics or JSON', () => {
  for (const failArgs of [
    ['invalid-command'], ['image', '--help'], ['see', '--help'],
    ['app', 'list', '--json', '--no-remote']
  ]) {
    const result = cliProbeFixture({ failArgs });
    assert.equal(result.passed, false, JSON.stringify(failArgs));
    assert.ok(result.messages.some((message) => message.includes('timed out after 30 seconds')));
    assert.deepEqual(result.calls.at(-1).args, failArgs);
  }
  const unavailable = cliProbeFixture({ failArgs: ['invalid-command'], errorCode: 'ENOENT' });
  assert.equal(unavailable.passed, false);
  assert.ok(unavailable.messages.some((message) => message.includes('fixture process error')));
});

test('successful CLI contracts retain bounded probes and expected nonzero diagnostics', () => {
  const result = cliProbeFixture();
  assert.equal(result.passed, true, result.messages.join('\n'));
  assert.equal(result.calls.length, 23);
  for (const call of result.calls) {
    assert.equal(call.options.timeout, 30_000);
    assert.equal(call.options.killSignal, 'SIGKILL');
  }
});

function safeTestsLaunch() {
  assert.ok(safeTestsFunction, 'test launcher must be inspectable without executing preparation');
  let launch;
  const run = runInNewContext(`${safeTestsFunction}; runSafeTests`, {
    log() {}, colors: {}, join, __dirname: join(projectRoot, 'scripts'), projectRoot,
    spawnSync(command, args, options) {
      launch = { command, args: Array.from(args), options };
      return { status: 0 };
    }
  });
  assert.equal(run(), true);
  assert.equal(launch.command, '/bin/bash');
  assert.deepEqual(launch.args.slice(0, 4), ['--noprofile', '--norc', '-p', '-c']);
  assert.deepEqual(launch.args.slice(5), ['peekaboo-release-tests', sanitizerPath, 'pnpm', 'test']);
  assert.equal(launch.options.cwd, projectRoot);
  assert.equal(launch.options.stdio, 'inherit');
  return launch;
}

function environmentFixture(t) {
  const root = mkdtempSync('/tmp/peekaboo preflight env ');
  const rejectedTool = `peekaboo-rejected-${root.slice(-6)}`;
  const absentTool = `peekaboo-absent-${root.slice(-6)}`;
  t.after(() => rmSync(root, { recursive: true, force: true }));
  for (const dir of ['home', 'tmp', 'scripts', 'signing-shim']) mkdirSync(join(root, dir));
  const write = (path, text) => writeFileSync(join(root, path), text);
  write('startup', 'printf "unexpected startup\\n" > "$HOME/startup-ran"\n');
  for (const tool of ['node', 'pnpm', 'npm', 'python3', 'git', 'codesign', 'bash', rejectedTool]) {
    write(`signing-shim/${tool}`, '#!/bin/bash\nprintf "unexpected shim\\n" > "$HOME/shim-ran"\nexit 98\n');
    chmodSync(join(root, `signing-shim/${tool}`), 0o755);
  }
  write('signing-shim/codesign', `#!/bin/bash -p
set -euo pipefail
source "$FIXTURE_SANITIZER"
for name in "\${TERMINAL_ARTIFACT_SECRET_NAMES[@]}"; do
  case "$name" in
    DYLD_*) [[ -z "\${!name+x}" ]] ;;
    BASH_ENV|ENV) [[ "\${!name}" == "$PWD/startup" ]] ;;
    *) [[ "\${!name}" == sentinel ]] ;;
  esac
done
[[ "$MAC_RELEASE_CODESIGN_KEYCHAIN" == "$HOME/keychain" && "$CODESIGN_KEYCHAIN" == "$HOME/keychain" ]]
[[ "$CODESIGN_IDENTITY" == fixture ]]
[[ "$PEEKABOO_OP_SERVICE_TOKEN_FILE" == "$HOME/primary" && "$PEEKABOO_MOLTY_OP_SERVICE_TOKEN_FILE" == "$HOME/legacy" ]]
printf 'later-signing-child-authority-retained=true\\n'
`);
  write('probe', `#!/bin/bash
set -euo pipefail
source "$FIXTURE_SANITIZER"
assertion=protected-variables
trap 'printf "preflight-probe: assertion=%s tool=%s exit=%s\\n" "$assertion" "\${tool:-none}" "$?" >&2' ERR
terminal_artifact_assert_build_env_is_clean
for name in MAC_RELEASE_CODESIGN_KEYCHAIN CODESIGN_KEYCHAIN CODESIGN_IDENTITY \\
  PEEKABOO_OP_SERVICE_TOKEN_FILE PEEKABOO_MOLTY_OP_SERVICE_TOKEN_FILE CDPATH GLOBIGNORE BASH_FUNC_fixture; do
  assertion="unset-$name"
  [[ -z "\${!name+x}" ]]
done
assertion=exact-trusted-path
[[ "$PATH" == /opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin ]]
assertion=allowed-values
[[ "$SWIFTPM_MIRROR_CONFIG" == "$HOME/verified-source-mapping.json" ]]
[[ "$DEVELOPER_DIR" == "$HOME/developer" && "$PEEKABOO_USE_RESOLVED_VERSIONS" == 1 ]]
assertion=tool-resolution
for tool in node pnpm npm python3 git codesign bash ${rejectedTool} ${absentTool}; do
  # Safe refusal is not evidence that a required build command is installed.
  if resolved="$(command -v "$tool")"; then
    case "$resolved" in
      /opt/homebrew/bin/*|/usr/local/bin/*|/usr/bin/*|/bin/*) ;;
      *) printf 'preflight-probe: tool=%s unsafe-resolution\\n' "$tool" >&2; exit 92 ;;
    esac
    [[ "$tool" != peekaboo-rejected-* && "$tool" != peekaboo-absent-* ]]
    printf 'tool=%s resolution=trusted\\n' "$tool"
  else
    lookup_exit=$?
    [[ "$lookup_exit" == 1 && "$tool" != bash ]]
    printf 'tool=%s resolution=unavailable safe-refusal=true\\n' "$tool"
  fi
done
assertion=arguments
[[ "$#" == 4 && "$1" == 'argument one' && "$2" == 'quote" and $literal' && -z "$3" && "$4" == $'line one\\nline two' ]]
printf 'test-child-clean=true tool-boundary-safe=true arguments-preserved=true\\n'
exit "$FIXTURE_CHILD_EXIT"
`);
  chmodSync(join(root, 'probe'), 0o755);
  // Seed only synthetic values, after Bash has started. The protected-name list
  // comes from its owner; no copied JavaScript credential list or operator env.
  const prelude = `set -euo pipefail
source "$FIXTURE_SANITIZER"
export RELEASE_PREFLIGHT_COMPLETED=false RELEASE_PUBLICATION_ELIGIBLE=false
export MAC_RELEASE_CODESIGN_KEYCHAIN="$HOME/keychain" CODESIGN_KEYCHAIN="$HOME/keychain" CODESIGN_IDENTITY=fixture
export SWIFTPM_MIRROR_CONFIG="$HOME/verified-source-mapping.json" DEVELOPER_DIR="$HOME/developer"
export PEEKABOO_USE_RESOLVED_VERSIONS=1
export PEEKABOO_OP_SERVICE_TOKEN_FILE="$HOME/primary" PEEKABOO_MOLTY_OP_SERVICE_TOKEN_FILE="$HOME/legacy"
export CDPATH=sentinel GLOBIGNORE=sentinel BASH_FUNC_fixture=sentinel
for name in "\${TERMINAL_ARTIFACT_SECRET_NAMES[@]}"; do
  printf -v "$name" sentinel
  export "$name"
done
export BASH_ENV="$PWD/startup" ENV="$PWD/startup"
export PATH="$PWD/signing-shim:$PATH"
parent_path="$PATH"
[[ "$(command -v codesign)" == "$PWD/signing-shim/codesign" ]]
[[ "$(command -v ${rejectedTool})" == "$PWD/signing-shim/${rejectedTool}" ]]
if command -v ${absentTool} >/dev/null; then exit 94; fi
check_parent() {
  local result=$? name
  for name in "\${TERMINAL_ARTIFACT_SECRET_NAMES[@]}"; do
    case "$name" in
      BASH_ENV|ENV) [[ "\${!name}" == "$PWD/startup" ]] || exit 93 ;;
      *) [[ "\${!name}" == sentinel ]] || exit 93 ;;
    esac
  done
  [[ "$PATH" == "$parent_path" && "$(command -v codesign)" == "$PWD/signing-shim/codesign" ]]
  [[ "$MAC_RELEASE_CODESIGN_KEYCHAIN" == "$HOME/keychain" && "$CODESIGN_KEYCHAIN" == "$HOME/keychain" && "$CODESIGN_IDENTITY" == fixture ]]
  [[ "$PEEKABOO_OP_SERVICE_TOKEN_FILE" == "$HOME/primary" && "$PEEKABOO_MOLTY_OP_SERVICE_TOKEN_FILE" == "$HOME/legacy" ]]
  (
    trap - EXIT
    # Only this fake signing child sheds loader poison; the parent retains it.
    for name in "\${TERMINAL_ARTIFACT_SECRET_NAMES[@]}"; do
      case "$name" in DYLD_*) builtin unset "$name" ;; esac
    done
    for name in "\${TERMINAL_ARTIFACT_SECRET_NAMES[@]}"; do
      case "$name" in
        DYLD_*) [[ -z "\${!name+x}" ]] || { printf 'signing pre-native variable remains: %s\\n' "$name" >&2; exit 91; } ;;
      esac
    done
    codesign # Only the asserted fixture shim; it checks synthetic authority.
  )
  for name in "\${TERMINAL_ARTIFACT_SECRET_NAMES[@]}"; do
    case "$name" in DYLD_*) [[ "\${!name}" == sentinel ]] || exit 93 ;; esac
  done
  [[ ! -e "$HOME/startup-ran" ]]
  [[ ! -e "$HOME/shim-ran" ]]
  printf 'parent-retained=true preflight=%s eligible=%s exit=%s\\n' "$RELEASE_PREFLIGHT_COMPLETED" "$RELEASE_PUBLICATION_ELIGIBLE" "$result"
  exit "$result"
}
trap check_parent EXIT
`;
  return {
    root, write, prelude, rejectedTool, absentTool,
    env: {
      PATH: '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin',
      HOME: join(root, 'home'), TMPDIR: join(root, 'tmp'), LANG: 'C',
      // Harmless hooks exercise the protected startup prefix; DYLD is seeded later.
      BASH_ENV: join(root, 'startup'), ENV: join(root, 'startup'),
      FIXTURE_SANITIZER: sanitizerPath, FIXTURE_PROBE: join(root, 'probe')
    },
    probeArgs: ['argument one', 'quote" and $literal', '', 'line one\nline two']
  };
}

test('direct preparation test launcher preserves child exits and refuses unavailable commands', (t) => {
  const launch = safeTestsLaunch();
  const fixture = environmentFixture(t);
  // Run the captured body after interpreter startup, retaining its $0/$1... argv.
  // A shell subshell isolates body cleanup without another poisoned native entry.
  const directBody = `${fixture.prelude}
/usr/bin/env() {
  local name
  for name in "\${TERMINAL_ARTIFACT_SECRET_NAMES[@]}" CDPATH GLOBIGNORE BASH_FUNC_fixture \\
    MAC_RELEASE_CODESIGN_KEYCHAIN CODESIGN_KEYCHAIN CODESIGN_IDENTITY \\
    PEEKABOO_OP_SERVICE_TOKEN_FILE PEEKABOO_MOLTY_OP_SERVICE_TOKEN_FILE; do
    [[ -z "\${!name+x}" ]] || { printf 'direct pre-native variable remains: %s\\n' "$name" >&2; return 91; }
  done
  printf 'direct-pre-native-clean=true\\n'
  command /usr/bin/env "$@"
}
(
  # The parent's EXIT trap must not inspect the body's scrubbed BASH_ENV/ENV.
  trap - EXIT
${launch.args[4]}
)
`;
  const args = [...launch.args.slice(0, 4), directBody, ...launch.args.slice(5, -2)];
  for (const childExit of [0, 37]) {
    const result = spawnSync(launch.command, [...args, fixture.env.FIXTURE_PROBE, ...fixture.probeArgs], {
      cwd: fixture.root, env: { ...fixture.env, FIXTURE_CHILD_EXIT: String(childExit) }, encoding: 'utf8'
    });
    t.diagnostic(JSON.stringify({ lane: 'direct', childExit, status: result.status,
      stdout: result.stdout, stderr: result.stderr }));
    assert.equal(result.status, childExit, result.stdout + result.stderr);
    assert.equal(result.stderr, '');
    assert.match(result.stdout, /direct-pre-native-clean=true/);
    assert.match(result.stdout, /test-child-clean=true tool-boundary-safe=true arguments-preserved=true/);
    assert.match(result.stdout, /tool=bash resolution=trusted/);
    for (const tool of [fixture.rejectedTool, fixture.absentTool]) {
      assert.ok(result.stdout.includes(`tool=${tool} resolution=unavailable safe-refusal=true`));
    }
    assert.match(result.stdout, /later-signing-child-authority-retained=true/);
    assert.match(result.stdout, new RegExp(`parent-retained=true preflight=false eligible=false exit=${childExit}`));
  }
  for (const command of [fixture.rejectedTool, fixture.absentTool]) {
    const result = spawnSync(launch.command, [...args, command, 'test'], {
      cwd: fixture.root, env: fixture.env, encoding: 'utf8'
    });
    t.diagnostic(JSON.stringify({ lane: 'direct', command, status: result.status,
      stdout: result.stdout, stderr: result.stderr }));
    assert.equal(result.status, 127, result.stdout + result.stderr);
    assert.ok(result.stderr.includes(command), 'missing-command diagnostic names the tool');
    assert.match(result.stdout, /direct-pre-native-clean=true/);
    assert.doesNotMatch(result.stdout, /test-child-clean=true/);
    assert.match(result.stdout, /later-signing-child-authority-retained=true/);
    assert.match(result.stdout, /parent-retained=true preflight=false eligible=false exit=127/);
    assert.equal(existsSync(join(fixture.root, 'home/shim-ran')), false);
  }
  t.diagnostic('direct scenarios completed: 4');
});

test('repository release source surfaces remain internally consistent', () => {
  const packageVersion = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8')).version;
  const versionResult = validateVersionConsistency(projectRoot);
  assert.equal(versionResult.version, packageVersion);
  assert.deepEqual(versionResult.failures, []);
  assert.deepEqual(validateSourceDocumentationContracts(projectRoot), []);
});
