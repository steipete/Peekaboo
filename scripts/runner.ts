#!/usr/bin/env bun
/**
 * Sweetistics runner wrapper: enforces timeouts, git policy, and trash-safe deletes before dispatching any repo command.
 * When you tweak its behavior, add a short note to AGENTS.md via `./scripts/committer "docs: update AGENTS for runner" "AGENTS.md"` so other agents know the new expectations.
 */

import { type ChildProcess, spawn } from 'node:child_process';
import { cpSync, existsSync, renameSync, rmSync } from 'node:fs';
import { constants as osConstants } from 'node:os';
import { basename, isAbsolute, join, normalize, resolve } from 'node:path';
import process from 'node:process';

import {
  analyzeGitExecution,
  evaluateGitPolicies,
  type GitCommandInfo,
  type GitExecutionContext,
  type GitInvocation,
} from './git-policy';

const DEFAULT_TIMEOUT_MS = 5 * 60 * 1000;
const EXTENDED_TIMEOUT_MS = 20 * 60 * 1000;
const LONG_TIMEOUT_MS = 25 * 60 * 1000; // Build + full-suite commands (Next.js build, test:all) routinely spike past 20 minutes—give them explicit headroom before tmux escalation.
const LINT_TIMEOUT_MS = 30 * 60 * 1000;
const LONG_RUN_REPORT_THRESHOLD_MS = 60 * 1000;
const ENABLE_DEBUG_LOGS = process.env.RUNNER_DEBUG === '1';
const MAX_SLEEP_SECONDS = 30;

const WRAPPER_COMMANDS = new Set([
  'sudo',
  '/usr/bin/sudo',
  'env',
  '/usr/bin/env',
  'command',
  '/bin/command',
  'nohup',
  '/usr/bin/nohup',
]);

const ENV_ASSIGNMENT_PATTERN = /^[A-Za-z_][A-Za-z0-9_]*=.*/;
type SummaryStyle = 'compact' | 'minimal' | 'verbose';
const SUMMARY_STYLE = resolveSummaryStyle(process.env.RUNNER_SUMMARY_STYLE);
// biome-ignore format: keep each keyword on its own line for grep-friendly diffs.
const LONG_SCRIPT_KEYWORDS = [
  'build',
  'test:all',
  'test:browser',
  'test:e2e',
  'test:e2e:headed',
  'vitest.browser',
  'vitest.browser.config.ts',
];
const EXTENDED_SCRIPT_KEYWORDS = ['lint', 'test', 'playwright', 'check', 'docker'];
const SINGLE_TEST_SCRIPTS = new Set(['test:file']);
const SINGLE_TEST_FLAGS = new Set(['--run', '--filter']);
const TEST_BINARIES = new Set(['vitest', 'playwright', 'jest']);
const LINT_BINARIES = new Set(['eslint', 'biome', 'oxlint', 'knip']);

type RunnerExecutionContext = {
  commandArgs: string[];
  workspaceDir: string;
  timeoutMs: number;
};

type CommandInterceptionResult = { handled: true } | { handled: false; gitContext: GitExecutionContext };

type GitRmPlan = {
  paths: string[];
  stagingOptions: string[];
  allowMissing: boolean;
  shouldIntercept: boolean;
};

type MoveResult = {
  missing: string[];
  errors: string[];
};

let cachedTrashCliCommand: string | null | undefined;

(async () => {
  const commandArgs = parseArgs(process.argv.slice(2));

  if (commandArgs.length === 0) {
    printUsage('Missing command to execute.');
    process.exit(1);
  }

  const workspaceDir = process.cwd();
  const timeoutMs = determineEffectiveTimeoutMs(commandArgs);
  const context: RunnerExecutionContext = {
    commandArgs,
    workspaceDir,
    timeoutMs,
  };

  enforcePolterArgumentSeparator(commandArgs);

  const interception = await resolveCommandInterception(context);
  if (interception.handled) {
    return;
  }

  enforceGitPolicies(interception.gitContext);

  await runCommand(context);
})().catch((error) => {
  console.error('[runner] Unexpected failure:', error instanceof Error ? error.message : String(error));
  process.exit(1);
});

// Parses the runner CLI args and rejects unsupported flags early.
function parseArgs(argv: string[]): string[] {
  const commandArgs: string[] = [];
  let parsingOptions = true;

  for (const token of argv) {
    if (!parsingOptions) {
      commandArgs.push(token);
      continue;
    }

    if (token === '--') {
      parsingOptions = false;
      continue;
    }

    if (token === '--help' || token === '-h') {
      printUsage();
      process.exit(0);
    }

    if (token === '--timeout' || token.startsWith('--timeout=')) {
      console.error('[runner] --timeout is no longer supported; rely on the automatic timeouts.');
      process.exit(1);
    }

    parsingOptions = false;
    commandArgs.push(token);
  }

  return commandArgs;
}

function enforcePolterArgumentSeparator(commandArgs: string[]): void {
  const invocation = findPolterPeekabooInvocation(commandArgs);
  if (!invocation) {
    return;
  }

  const afterPeekaboo = commandArgs.slice(invocation.peekabooIndex + 1);
  if (afterPeekaboo.length === 0) {
    return;
  }

  const separatorPos = afterPeekaboo.indexOf('--');
  const toInspect = separatorPos === -1 ? afterPeekaboo : afterPeekaboo.slice(0, separatorPos);
  const flagToken = toInspect.find((token) => token.startsWith('-'));
  const passthroughFlags = new Set(['--version', '-V', '--help', '-h']);

  if (flagToken && passthroughFlags.has(flagToken)) {
    // Allow common single-shot flags without requiring an explicit separator.
    return;
  }
  if (flagToken) {
    console.error(
      `[runner] polter peekaboo commands must insert '--' before CLI flags so Poltergeist does not consume them. Example: polter peekaboo -- dialog dismiss --force`,
    );
    console.error(`[runner] Offending flag: ${flagToken}`);
    process.exit(1);
  }
}

function findPolterPeekabooInvocation(commandArgs: string[]): { polterIndex: number; peekabooIndex: number } | null {
  for (let i = 0; i < commandArgs.length; i += 1) {
    const token = commandArgs[i];
    if (WRAPPER_COMMANDS.has(token) || ENV_ASSIGNMENT_PATTERN.test(token)) {
      continue;
    }
    if (token === 'polter' && i + 1 < commandArgs.length && commandArgs[i + 1] === 'peekaboo') {
      return { polterIndex: i, peekabooIndex: i + 1 };
    }
    break;
  }
  return null;
}

// Computes the timeout tier for the provided command tokens.
function determineEffectiveTimeoutMs(commandArgs: string[]): number {
  const strippedTokens = stripWrappersAndAssignments(commandArgs);
  if (isTestRunnerSuiteInvocation(strippedTokens, 'integration')) {
    return EXTENDED_TIMEOUT_MS;
  }
  if (referencesIntegrationSpec(strippedTokens)) {
    return EXTENDED_TIMEOUT_MS;
  }
  if (shouldUseLintTimeout(commandArgs)) {
    return LINT_TIMEOUT_MS;
  }
  if (shouldUseLongTimeout(commandArgs)) {
    return LONG_TIMEOUT_MS;
  }
  if (shouldExtendTimeout(commandArgs) && !isSingleTestInvocation(commandArgs)) {
    return EXTENDED_TIMEOUT_MS;
  }
  return DEFAULT_TIMEOUT_MS;
}

// Determines whether the command matches any keyword requiring extra time.
function shouldExtendTimeout(commandArgs: string[]): boolean {
  const tokens = stripWrappersAndAssignments(commandArgs);
  if (tokens.length === 0) {
    return false;
  }

  const [first, ...rest] = tokens;
  if (!first) {
    return false;
  }

  if (first === 'pnpm') {
    return shouldExtendViaPnpm(rest);
  }
  if (first === 'bun') {
    return shouldExtendViaBun(rest);
  }

  if (shouldExtendForScript(first) || TEST_BINARIES.has(first.toLowerCase())) {
    return true;
  }

  return rest.some((token) => shouldExtendForScript(token) || TEST_BINARIES.has(token.toLowerCase()));
}

function shouldExtendViaPnpm(rest: string[]): boolean {
  if (rest.length === 0) {
    return false;
  }
  const subcommand = rest[0];
  if (!subcommand) {
    return false;
  }
  if (subcommand === 'run') {
    const script = rest[1];
    return typeof script === 'string' && shouldExtendForScript(script);
  }
  if (subcommand === 'exec') {
    const execTarget = rest[1];
    if (execTarget && (shouldExtendForScript(execTarget) || TEST_BINARIES.has(execTarget.toLowerCase()))) {
      return true;
    }
    return rest.slice(1).some((token) => shouldExtendForScript(token) || TEST_BINARIES.has(token.toLowerCase()));
  }
  return shouldExtendForScript(subcommand);
}

function shouldExtendViaBun(rest: string[]): boolean {
  if (rest.length === 0) {
    return false;
  }
  const subcommand = rest[0];
  if (!subcommand) {
    return false;
  }
  if (subcommand === 'run') {
    const script = rest[1];
    return typeof script === 'string' && shouldExtendForScript(script);
  }
  if (subcommand === 'test') {
    return true;
  }
  if (subcommand === 'x' || subcommand === 'bunx') {
    const execTarget = rest[1];
    if (execTarget && TEST_BINARIES.has(execTarget.toLowerCase())) {
      return true;
    }
  }
  return shouldExtendForScript(subcommand);
}

// Checks script names for long-running markers (lint/test/build/etc.).
function shouldExtendForScript(script: string): boolean {
  if (SINGLE_TEST_SCRIPTS.has(script)) {
    return false;
  }
  return matchesScriptKeyword(script, EXTENDED_SCRIPT_KEYWORDS);
}

// Gives lint invocations the dedicated timeout bucket.
function shouldUseLintTimeout(commandArgs: string[]): boolean {
  const tokens = stripWrappersAndAssignments(commandArgs);
  if (tokens.length === 0) {
    return false;
  }

  const [first, ...rest] = tokens;
  if (!first) {
    return false;
  }

  if (first === 'pnpm') {
    return shouldUseLintTimeoutViaPnpm(rest);
  }
  if (first === 'bun') {
    return shouldUseLintTimeoutViaBun(rest);
  }

  return LINT_BINARIES.has(first.toLowerCase());
}

function shouldUseLintTimeoutViaPnpm(rest: string[]): boolean {
  if (rest.length === 0) {
    return false;
  }
  const subcommand = rest[0];
  if (!subcommand) {
    return false;
  }
  if (subcommand === 'run') {
    const script = rest[1];
    return typeof script === 'string' && script.startsWith('lint');
  }
  if (subcommand === 'exec') {
    const execTarget = rest[1];
    if (execTarget && LINT_BINARIES.has(execTarget.toLowerCase())) {
      return true;
    }
    return rest.slice(1).some((token) => LINT_BINARIES.has(token.toLowerCase()));
  }
  return LINT_BINARIES.has(subcommand.toLowerCase());
}

function shouldUseLintTimeoutViaBun(rest: string[]): boolean {
  if (rest.length === 0) {
    return false;
  }
  const subcommand = rest[0];
  if (!subcommand) {
    return false;
  }
  if (subcommand === 'run') {
    const script = rest[1];
    return typeof script === 'string' && script.startsWith('lint');
  }
  if (subcommand === 'x' || subcommand === 'bunx') {
    return rest.slice(1).some((token) => LINT_BINARIES.has(token.toLowerCase()));
  }
  return LINT_BINARIES.has(subcommand.toLowerCase());
}

// Detects when a user is running a single spec so we can keep the shorter timeout.
function isSingleTestInvocation(commandArgs: string[]): boolean {
  const tokens = stripWrappersAndAssignments(commandArgs);
  if (tokens.length === 0) {
    return false;
  }

  if (tokens.some((token) => SINGLE_TEST_FLAGS.has(token))) {
    return true;
  }

  const [first, ...rest] = tokens;
  if (!first) {
    return false;
  }

  if (first === 'pnpm') {
    return isSingleTestViaPnpm(rest);
  }
  if (first === 'bun') {
    return isSingleTestViaBun(rest);
  }
  if (first === 'vitest') {
    return rest.some((token) => SINGLE_TEST_FLAGS.has(token));
  }

  return SINGLE_TEST_SCRIPTS.has(first);
}

function isSingleTestViaPnpm(rest: string[]): boolean {
  if (rest.length === 0) {
    return false;
  }
  const subcommand = rest[0];
  if (!subcommand) {
    return false;
  }
  if (subcommand === 'run') {
    const script = rest[1];
    return typeof script === 'string' && SINGLE_TEST_SCRIPTS.has(script);
  }
  if (subcommand === 'exec') {
    return rest.slice(1).some((token) => SINGLE_TEST_FLAGS.has(token));
  }
  return SINGLE_TEST_SCRIPTS.has(subcommand);
}

function isSingleTestViaBun(rest: string[]): boolean {
  if (rest.length === 0) {
    return false;
  }
  const subcommand = rest[0];
  if (!subcommand) {
    return false;
  }
  if (subcommand === 'run') {
    const script = rest[1];
    return typeof script === 'string' && SINGLE_TEST_SCRIPTS.has(script);
  }
  if (subcommand === 'test') {
    return true;
  }
  if (subcommand === 'x' || subcommand === 'bunx') {
    return rest.slice(1).some((token) => SINGLE_TEST_FLAGS.has(token));
  }
  return false;
}

// Normalizes potential file paths/flags to aid comparison across shells.
function normalizeForPathComparison(token: string): string {
  return token.replaceAll('\\', '/');
}

// Heuristically checks if a CLI token references an integration spec.
function tokenReferencesIntegrationTest(token: string): boolean {
  const normalized = normalizeForPathComparison(token);
  if (normalized.includes('tests/integration/')) {
    return true;
  }
  if (normalized.startsWith('--run=') || normalized.startsWith('--include=')) {
    const value = normalized.split('=', 2)[1] ?? '';
    return value.includes('tests/integration/');
  }
  return false;
}

// Scans the entire command for integration spec references.
function referencesIntegrationSpec(tokens: string[]): boolean {
  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (!token) {
      continue;
    }
    if (token === '--run' || token === '--include') {
      const next = tokens[index + 1];
      if (next && tokenReferencesIntegrationTest(next)) {
        return true;
      }
    }
    if (tokenReferencesIntegrationTest(token)) {
      return true;
    }
  }
  return false;
}

// Helper that matches a script token against a keyword allowlist.
function matchesScriptKeyword(script: string, keywords: readonly string[]): boolean {
  const lowered = script.toLowerCase();
  return keywords.some((keyword) => lowered === keyword || lowered.startsWith(`${keyword}:`));
}

// Removes wrapper binaries/env assignments so heuristics see the real command.
function stripWrappersAndAssignments(args: string[]): string[] {
  const tokens = [...args];

  while (tokens.length > 0) {
    const candidate = tokens[0];
    if (!candidate) {
      break;
    }
    if (!isEnvAssignment(candidate)) {
      break;
    }
    tokens.shift();
  }

  while (tokens.length > 0) {
    const wrapper = tokens[0];
    if (!wrapper) {
      break;
    }
    if (!WRAPPER_COMMANDS.has(wrapper)) {
      break;
    }
    tokens.shift();
    while (tokens.length > 0) {
      const assignment = tokens[0];
      if (!assignment) {
        break;
      }
      if (!isEnvAssignment(assignment)) {
        break;
      }
      tokens.shift();
    }
  }

  return tokens;
}

// Checks whether a token is an inline environment variable assignment.
function isEnvAssignment(token: string): boolean {
  return /^[A-Za-z_][A-Za-z0-9_]*=.*/.test(token);
}

// Detects `pnpm test:<suite>` style calls regardless of wrappers.
function isTestRunnerSuiteInvocation(tokens: string[], suite: string): boolean {
  if (tokens.length === 0) {
    return false;
  }

  const normalizedSuite = suite.toLowerCase();
  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (!token) {
      continue;
    }
    const normalizedToken = token.replace(/^[./\\]+/, '');
    if (normalizedToken === 'scripts/test-runner.ts' || normalizedToken.endsWith('/scripts/test-runner.ts')) {
      const suiteToken = tokens[index + 1]?.toLowerCase();
      if (suiteToken === normalizedSuite) {
        return true;
      }
    }
  }

  return false;
}

// Grants the longest timeout to explicitly tagged long-running scripts.
function shouldUseLongTimeout(commandArgs: string[]): boolean {
  const tokens = stripWrappersAndAssignments(commandArgs);
  if (tokens.length === 0) {
    return false;
  }

  const first = tokens[0];
  if (!first) {
    return false;
  }
  const rest = tokens.slice(1);
  const matches = (token: string): boolean => matchesScriptKeyword(token, LONG_SCRIPT_KEYWORDS);

  if (first === 'pnpm') {
    if (rest.length === 0) {
      return false;
    }
    const subcommand = rest[0];
    if (!subcommand) {
      return false;
    }
    if (subcommand === 'run') {
      const script = rest[1];
      if (script && matches(script)) {
        return true;
      }
    } else if (matches(subcommand)) {
      return true;
    }
    for (const token of rest.slice(1)) {
      if (matches(token)) {
        return true;
      }
    }
    return false;
  }

  if (matches(first)) {
    return true;
  }

  for (const token of rest) {
    if (matches(token)) {
      return true;
    }
  }

  return false;
}

// Kicks off the requested command with logging, timeouts, and monitoring.
async function runCommand(context: RunnerExecutionContext): Promise<void> {
  const { command, args, env } = buildExecutionParams(context.commandArgs);
  const commandLabel = formatDisplayCommand(context.commandArgs);

  const startTime = Date.now();

  const child = spawn(command, args, {
    cwd: context.workspaceDir,
    env,
    stdio: ['inherit', 'pipe', 'pipe'],
  });

  if (isRunnerTmuxSession()) {
    const childPidInfo = typeof child.pid === 'number' ? ` (pid ${child.pid})` : '';
    console.error(`[runner] Watching ${commandLabel}${childPidInfo}. Wait for the closing sentinel before moving on.`);
  }

  const removeSignalHandlers = registerSignalForwarding(child);

  if (child.stdout) {
    child.stdout.on('data', (chunk: Buffer) => {
      process.stdout.write(chunk);
    });
  }

  if (child.stderr) {
    child.stderr.on('data', (chunk: Buffer) => {
      process.stderr.write(chunk);
    });
  }

  let killTimer: NodeJS.Timeout | null = null;
  try {
    const result = await new Promise<{ exitCode: number; timedOut: boolean }>((resolve, reject) => {
      let timedOut = false;
      const timeout = setTimeout(() => {
        timedOut = true;
        if (ENABLE_DEBUG_LOGS) {
          console.error(`[runner] Command exceeded ${formatDuration(context.timeoutMs)}; sending SIGTERM.`);
        }
        if (!child.killed) {
          child.kill('SIGTERM');
          killTimer = setTimeout(() => {
            if (!child.killed) {
              child.kill('SIGKILL');
            }
          }, 5_000);
        }
      }, context.timeoutMs);

      child.once('error', (error) => {
        clearTimeout(timeout);
        if (killTimer) {
          clearTimeout(killTimer);
        }
        removeSignalHandlers();
        reject(error);
      });

      child.once('exit', (code, signal) => {
        clearTimeout(timeout);
        if (killTimer) {
          clearTimeout(killTimer);
        }
        removeSignalHandlers();
        resolve({ exitCode: code ?? exitCodeFromSignal(signal), timedOut });
      });
    });
    const { exitCode, timedOut } = result;

    const elapsedMs = Date.now() - startTime;
    if (timedOut) {
      console.error(
        `[runner] Command terminated after ${formatDuration(context.timeoutMs)}. Re-run inside tmux for long-lived work.`
      );
      console.error(
        formatCompletionSummary({ exitCode, elapsedMs, timedOut: true, commandLabel })
      );
      process.exit(124);
    }

    if (elapsedMs >= LONG_RUN_REPORT_THRESHOLD_MS) {
      console.error(
        `[runner] Completed in ${formatDuration(elapsedMs)}. For long-running tasks, prefer tmux directly.`
      );
    }

    console.error(formatCompletionSummary({ exitCode, elapsedMs, commandLabel }));
    process.exit(exitCode);
  } catch (error) {
    console.error('[runner] Failed to launch command:', error instanceof Error ? error.message : String(error));
    process.exit(1);
    return;
  }
}

async function runCommandWithoutTimeout(context: RunnerExecutionContext): Promise<void> {
  const { command, args, env } = buildExecutionParams(context.commandArgs);
  const commandLabel = formatDisplayCommand(context.commandArgs);
  const startTime = Date.now();

  const child = spawn(command, args, {
    cwd: context.workspaceDir,
    env,
    stdio: 'inherit',
  });

  const removeSignalHandlers = registerSignalForwarding(child);

  try {
    const exitCode = await new Promise<number>((resolve, reject) => {
      child.once('error', (error) => {
        removeSignalHandlers();
        reject(error);
      });
      child.once('exit', (code, signal) => {
        removeSignalHandlers();
        resolve(code ?? exitCodeFromSignal(signal));
      });
    });
    const elapsedMs = Date.now() - startTime;
    console.error(formatCompletionSummary({ exitCode, elapsedMs, commandLabel }));
    process.exit(exitCode);
  } catch (error) {
    console.error('[runner] Failed to launch command:', error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}

// Prepares the executable, args, and sanitized env for the child process.
function buildExecutionParams(commandArgs: string[]): { command: string; args: string[]; env: NodeJS.ProcessEnv } {
  const env = { ...process.env };
  const args: string[] = [];
  let commandStarted = false;

  for (const token of commandArgs) {
    if (!commandStarted && isEnvAssignment(token)) {
      const [key, ...rest] = token.split('=');
      if (key) {
        env[key] = rest.join('=');
      }
      continue;
    }
    commandStarted = true;
    args.push(token);
  }

  if (args.length === 0 || !args[0]) {
    printUsage('Missing command to execute.');
    process.exit(1);
  }

  const [command, ...restArgs] = args;
  return { command, args: restArgs, env };
}

// Forwards termination signals to the child and returns an unregister hook.
function registerSignalForwarding(child: ChildProcess): () => void {
  const signals: NodeJS.Signals[] = ['SIGINT', 'SIGTERM'];
  const handlers = new Map<NodeJS.Signals, () => void>();

  for (const signal of signals) {
    const handler = () => {
      if (!child.killed) {
        child.kill(signal);
      }
    };
    handlers.set(signal, handler);
    process.on(signal, handler);
  }

  return () => {
    for (const [signal, handler] of handlers) {
      process.off(signal, handler);
    }
  };
}

// Maps a terminating signal to the exit code conventions bash expects.
function exitCodeFromSignal(signal: NodeJS.Signals | null): number {
  if (!signal) {
    return 0;
  }
  const code = (osConstants.signals as Record<string, number | undefined>)[signal];
  if (typeof code === 'number') {
    return 128 + code;
  }
  return 1;
}

// Gives policy interceptors a chance to fully handle a command before exec.
async function resolveCommandInterception(context: RunnerExecutionContext): Promise<CommandInterceptionResult> {
  const interceptors: Array<(ctx: RunnerExecutionContext) => Promise<boolean>> = [
    maybeInjectSwiftPackagePath,
    maybeHandleTmuxInvocation,
    maybeHandleFindInvocation,
    maybeHandleRmInvocation,
    maybeHandleSleepInvocation,
  ];

  for (const interceptor of interceptors) {
    if (await interceptor(context)) {
      return { handled: true };
    }
  }

  const gitContext = analyzeGitExecution(context.commandArgs, context.workspaceDir);

  if (await maybeHandleGitRm(gitContext)) {
    return { handled: true };
  }

  return { handled: false, gitContext };
}

// Runs the shared git policy analyzers before dispatching the command.
function enforceGitPolicies(gitContext: GitExecutionContext) {
  const evaluation = evaluateGitPolicies(gitContext);
  const hasConsentOverride = process.env.RUNNER_THE_USER_GAVE_ME_CONSENT === '1';

  if (gitContext.subcommand === 'rebase' && !hasConsentOverride) {
    console.error(
      'git rebase requires the user to explicitly type "rebase" in chat. Once they do, rerun with RUNNER_THE_USER_GAVE_ME_CONSENT=1 in the same command (e.g. RUNNER_THE_USER_GAVE_ME_CONSENT=1 ./runner git rebase --continue).'
    );
    process.exit(1);
  }

  if (evaluation.requiresCommitHelper) {
    console.error(
      'Direct git add/commit is disabled. Use ./scripts/committer "chore(runner): describe change" "scripts/runner.ts" instead—see AGENTS.md and ./scripts/committer for details. The helper auto-stashes unrelated files before committing.'
    );
    process.exit(1);
  }

  if (evaluation.requiresExplicitConsent || evaluation.isDestructive) {
    if (hasConsentOverride) {
      if (ENABLE_DEBUG_LOGS) {
        const reason = evaluation.isDestructive ? 'destructive git command' : 'guarded git command';
        console.error(`[runner] Proceeding with ${reason} because RUNNER_THE_USER_GAVE_ME_CONSENT=1.`);
      }
    } else {
      if (evaluation.isDestructive) {
        console.error(
          `git ${gitContext.subcommand ?? ''} can overwrite or discard work. Confirm with the user first, then re-run with RUNNER_THE_USER_GAVE_ME_CONSENT=1 if they approve.`
        );
      } else {
        console.error(
          `Using git ${gitContext.subcommand ?? ''} requires consent. Set RUNNER_THE_USER_GAVE_ME_CONSENT=1 after verifying with the user, or ask them explicitly before proceeding.`
        );
      }
      process.exit(1);
    }
  }
}

// Handles guarded `find` invocations that may delete files outright.
async function maybeHandleFindInvocation(context: RunnerExecutionContext): Promise<boolean> {
  const findInvocation = extractFindInvocation(context.commandArgs);
  if (!findInvocation) {
    return false;
  }

  const findPlan = await buildFindDeletePlan(findInvocation.argv, context.workspaceDir);
  if (!findPlan) {
    return false;
  }

  const moveResult = await movePathsToTrash(findPlan.paths, context.workspaceDir, { allowMissing: false });
  if (moveResult.missing.length > 0) {
    for (const path of moveResult.missing) {
      console.error(`find: ${path}: No such file or directory`);
    }
    process.exit(1);
  }
  if (moveResult.errors.length > 0) {
    for (const error of moveResult.errors) {
      console.error(error);
    }
    process.exit(1);
  }
  process.exit(0);
  return true;
}

async function maybeInjectSwiftPackagePath(context: RunnerExecutionContext): Promise<boolean> {
  if (!findSwiftInvocation(context.commandArgs)) {
    return false;
  }

  const currentHasPackage = existsSync(join(context.workspaceDir, 'Package.swift'));
  if (currentHasPackage) {
    return false;
  }

  const packagePath = determineSwiftPackagePath(context.workspaceDir);
  if (!packagePath) {
    return false;
  }

  context.workspaceDir = packagePath;
  if (ENABLE_DEBUG_LOGS) {
    console.error(`[runner] Redirecting swift invocation to ${packagePath}.`);
  }
  return false;
}

// Intercepts plain `rm` commands to route them through trash safeguards.
async function maybeHandleRmInvocation(context: RunnerExecutionContext): Promise<boolean> {
  const rmInvocation = extractRmInvocation(context.commandArgs);
  if (!rmInvocation) {
    return false;
  }

  const rmPlan = parseRmArguments(rmInvocation.argv);
  if (!rmPlan?.shouldIntercept) {
    return false;
  }

  try {
    const moveResult = await movePathsToTrash(rmPlan.targets, context.workspaceDir, { allowMissing: rmPlan.force });
    reportMissingForRm(moveResult.missing, rmPlan.force);
    if (moveResult.errors.length > 0) {
      for (const error of moveResult.errors) {
        console.error(error);
      }
      process.exit(1);
    }
    process.exit(0);
  } catch (error) {
    console.error(formatTrashError(error));
    process.exit(1);
  }
  return true;
}

// Applies git-specific rm protections before the command executes.
async function maybeHandleGitRm(gitContext: GitExecutionContext): Promise<boolean> {
  if (gitContext.command?.name !== 'rm' || !gitContext.invocation) {
    return false;
  }

  const gitRmPlan = parseGitRmArguments(gitContext.invocation.argv, gitContext.command);
  if (!gitRmPlan?.shouldIntercept) {
    return false;
  }

  try {
    const moveResult = await movePathsToTrash(gitRmPlan.paths, gitContext.workDir, {
      allowMissing: gitRmPlan.allowMissing,
    });
    if (!gitRmPlan.allowMissing && moveResult.missing.length > 0) {
      for (const path of moveResult.missing) {
        console.error(`git rm: ${path}: No such file or directory`);
      }
      process.exit(1);
    }
    if (moveResult.errors.length > 0) {
      for (const error of moveResult.errors) {
        console.error(error);
      }
      process.exit(1);
    }
    await stageGitRm(gitContext.workDir, gitRmPlan);
    process.exit(0);
  } catch (error) {
    console.error(formatTrashError(error));
    process.exit(1);
  }
  return true;
}

// Blocks `sleep` calls longer than the AGENTS.md ceiling so scripts cannot stall the runner.
async function maybeHandleSleepInvocation(context: RunnerExecutionContext): Promise<boolean> {
  const tokens = stripWrappersAndAssignments(context.commandArgs);
  if (tokens.length === 0) {
    return false;
  }
  const [first, ...rest] = tokens;
  if (!first || !isSleepBinary(first) || rest.length === 0) {
    return false;
  }

  const commandIndex = context.commandArgs.length - tokens.length;
  if (commandIndex < 0) {
    return false;
  }

  const adjustedArgs = [...context.commandArgs];
  const adjustments: string[] = [];

  for (let offset = 0; offset < rest.length; offset += 1) {
    const token = rest[offset];
    const durationSeconds = parseSleepDurationSeconds(token);
    if (durationSeconds == null || durationSeconds <= MAX_SLEEP_SECONDS) {
      continue;
    }
    adjustments.push(`${token}→${formatSleepDuration(MAX_SLEEP_SECONDS)}`);
    adjustedArgs[commandIndex + 1 + offset] = formatSleepArgument(MAX_SLEEP_SECONDS);
  }

  if (adjustments.length === 0) {
    return false;
  }

  console.error(
    `[runner] sleep arguments exceed ${MAX_SLEEP_SECONDS}s; clamping (${adjustments.join(', ')}).`
  );
  context.commandArgs = adjustedArgs;
  return false;
}

async function maybeHandleTmuxInvocation(context: RunnerExecutionContext): Promise<boolean> {
  const tokens = stripWrappersAndAssignments(context.commandArgs);
  if (tokens.length === 0) {
    return false;
  }
  const candidate = tokens[0];
  if (!candidate) {
    return false;
  }
  if (basename(candidate) !== 'tmux') {
    return false;
  }
  console.error('[runner] Detected tmux invocation; executing command without runner timeout guardrails.');
  await runCommandWithoutTimeout(context);
  return true;
}

function parseSleepDurationSeconds(token: string): number | null {
  const match = /^(\d+(?:\.\d+)?)([smhdSMHD]?)$/.exec(token);
  if (!match) {
    return null;
  }
  const value = Number(match[1]);
  if (!Number.isFinite(value)) {
    return null;
  }
  const unit = match[2]?.toLowerCase() ?? '';
  const multiplier = unit === 'm' ? 60 : unit === 'h' ? 60 * 60 : unit === 'd' ? 60 * 60 * 24 : 1;
  return value * multiplier;
}

function formatSleepArgument(seconds: number): string {
  return Number.isInteger(seconds) ? `${seconds}` : seconds.toString();
}

function formatSleepDuration(seconds: number): string {
  if (Number.isInteger(seconds)) {
    return `${seconds}s`;
  }
  return `${seconds.toFixed(2)}s`;
}

function isSleepBinary(token: string): boolean {
  return token === 'sleep' || token.endsWith('/sleep');
}

// Detects `git find` invocations that need policy enforcement.
function extractFindInvocation(commandArgs: string[]): GitInvocation | null {
  for (const [index, token] of commandArgs.entries()) {
    if (token === 'find' || token.endsWith('/find')) {
      return { index, argv: commandArgs.slice(index) };
    }
  }
  return null;
}

// Detects `git rm` variants so we can intercept destructive operations.
function extractRmInvocation(commandArgs: string[]): GitInvocation | null {
  if (commandArgs.length === 0) {
    return null;
  }

  const wrappers = new Set([
    'sudo',
    '/usr/bin/sudo',
    'env',
    '/usr/bin/env',
    'command',
    '/bin/command',
    'nohup',
    '/usr/bin/nohup',
  ]);

  let index = 0;
  while (index < commandArgs.length) {
    const token = commandArgs[index];
    if (!token) {
      break;
    }
    if (token.includes('=') && !token.startsWith('-')) {
      index += 1;
      continue;
    }
    if (wrappers.has(token)) {
      index += 1;
      continue;
    }
    break;
  }

  const commandToken = commandArgs[index];
  if (!commandToken) {
    return null;
  }

  const isRmCommand =
    commandToken === 'rm' ||
    commandToken.endsWith('/rm') ||
    commandToken === 'rm.exe' ||
    commandToken.endsWith('\\rm.exe');

  if (!isRmCommand) {
    return null;
  }

  return { index, argv: commandArgs.slice(index) };
}

function findSwiftInvocation(commandArgs: string[]): GitInvocation | null {
  if (commandArgs.length === 0) {
    return null;
  }

  let index = 0;
  while (index < commandArgs.length) {
    const token = commandArgs[index];
    if (!token) {
      break;
    }
    if (ENV_ASSIGNMENT_PATTERN.test(token)) {
      index += 1;
      continue;
    }
    if (WRAPPER_COMMANDS.has(token)) {
      index += 1;
      continue;
    }
    break;
  }

  const commandToken = commandArgs[index];
  if (!commandToken) {
    return null;
  }

  const isSwiftCommand = commandToken === 'swift' || commandToken.endsWith('/swift') || commandToken.endsWith('swift.exe');
  if (!isSwiftCommand) {
    return null;
  }

  return { index, argv: commandArgs.slice(index) };
}

function determineSwiftPackagePath(workspaceDir: string): string | null {
  const override = process.env.RUNNER_SWIFT_PACKAGE?.trim();
  if (override && override.length > 0) {
    const resolved = isAbsolute(override) ? override : resolve(workspaceDir, override);
    if (existsSync(join(resolved, 'Package.swift'))) {
      return resolved;
    }
  }

  const candidates = ['Apps/CLI'];
  for (const relativePath of candidates) {
    const candidate = join(workspaceDir, relativePath);
    if (existsSync(join(candidate, 'Package.swift'))) {
      return candidate;
    }
  }
  return null;
}

// Expands guarded find expressions into an explicit delete plan for review.
async function buildFindDeletePlan(findArgs: string[], workspaceDir: string): Promise<{ paths: string[] } | null> {
  if (!findArgs.some((token) => token === '-delete')) {
    return null;
  }

  if (findArgs.some((token) => token === '-exec' || token === '-execdir' || token === '-ok' || token === '-okdir')) {
    console.error(
      'Runner cannot safely translate find invocations that combine -delete with -exec/-ok. Run the command manually after reviewing the paths.'
    );
    process.exit(1);
  }

  const printableArgs: string[] = [];
  for (const token of findArgs) {
    if (token === '-delete') {
      continue;
    }
    printableArgs.push(token);
  }
  printableArgs.push('-print0');

  const proc = Bun.spawn(printableArgs, {
    cwd: workspaceDir,
    stdout: 'pipe',
    stderr: 'pipe',
  });

  const [exitCode, stdoutBuf, stderrBuf] = await Promise.all([
    proc.exited,
    readProcessStream(proc.stdout),
    readProcessStream(proc.stderr),
  ]);

  if (exitCode !== 0) {
    const stderrText = stderrBuf.trim();
    const stdoutText = stdoutBuf.trim();
    if (stderrText.length > 0) {
      console.error(stderrText);
    } else if (stdoutText.length > 0) {
      console.error(stdoutText);
    }
    process.exit(exitCode);
  }

  const matches = stdoutBuf.split('\0').filter((entry: string) => entry.length > 0);
  if (matches.length === 0) {
    return { paths: [] };
  }

  const uniquePaths = new Map<string, string>();
  const workspaceCanonical = normalize(workspaceDir);

  for (const match of matches) {
    const absolute = isAbsolute(match) ? match : resolve(workspaceDir, match);
    const canonical = normalize(absolute);
    if (canonical === workspaceCanonical) {
      console.error('Refusing to trash the current workspace via find -delete. Narrow your find predicate.');
      process.exit(1);
    }
    if (!uniquePaths.has(canonical)) {
      uniquePaths.set(canonical, match);
    }
  }

  return { paths: Array.from(uniquePaths.values()) };
}

// Parses rm flags/targets to decide whether the runner should intervene.
function parseRmArguments(argv: string[]): { targets: string[]; force: boolean; shouldIntercept: boolean } | null {
  if (argv.length <= 1) {
    return null;
  }
  const targets: string[] = [];
  let force = false;
  let treatAsTarget = false;

  let index = 1;
  while (index < argv.length) {
    const token = argv[index];
    if (token === undefined) {
      break;
    }
    if (!treatAsTarget && token === '--') {
      treatAsTarget = true;
      index += 1;
      continue;
    }
    if (!treatAsTarget && token.startsWith('-') && token.length > 1) {
      if (token.includes('f')) {
        force = true;
      }
      if (token.includes('i') || token === '--interactive') {
        return null;
      }
      if (token === '--help' || token === '--version') {
        return null;
      }
      index += 1;
      continue;
    }
    targets.push(token);
    index += 1;
  }

  const firstTarget = targets[0];
  if (firstTarget === undefined) {
    return null;
  }

  return { targets, force, shouldIntercept: true };
}

// Generates a safe plan for git rm invocations, honoring guarded paths.
function parseGitRmArguments(argv: string[], command: GitCommandInfo): GitRmPlan | null {
  const stagingOptions: string[] = [];
  const paths: string[] = [];
  const optionsExpectingValue = new Set(['--pathspec-from-file']);
  let allowMissing = false;
  let treatAsPath = false;

  let index = command.index + 1;
  while (index < argv.length) {
    const token = argv[index];
    if (token === undefined) {
      break;
    }
    if (!treatAsPath && token === '--') {
      treatAsPath = true;
      index += 1;
      continue;
    }
    if (!treatAsPath && token.startsWith('-') && token.length > 1) {
      if (token === '--cached' || token === '--dry-run' || token === '-n') {
        return null;
      }
      if (token === '--ignore-unmatch' || token === '--force' || token === '-f') {
        allowMissing = true;
        stagingOptions.push(token);
        index += 1;
        continue;
      }
      if (optionsExpectingValue.has(token)) {
        const value = argv[index + 1];
        if (value) {
          stagingOptions.push(token, value);
          index += 2;
        } else {
          index += 1;
        }
        continue;
      }
      if (!token.startsWith('--')) {
        const flags = token.slice(1).split('');
        const retainedFlags: string[] = [];
        for (const flag of flags) {
          if (flag === 'n') {
            return null;
          }
          if (flag === 'f') {
            allowMissing = true;
            continue;
          }
          retainedFlags.push(flag);
        }
        if (retainedFlags.length > 0) {
          stagingOptions.push(`-${retainedFlags.join('')}`);
        }
        index += 1;
        continue;
      }
      stagingOptions.push(token);
      index += 1;
      continue;
    }
    if (token.length > 0) {
      paths.push(token);
    }
    index += 1;
  }

  if (paths.length === 0) {
    return null;
  }
  return {
    paths,
    stagingOptions,
    allowMissing,
    shouldIntercept: true,
  };
}

// Emits actionable messaging when git rm targets are already gone.
function reportMissingForRm(missing: string[], forced: boolean) {
  if (missing.length === 0 || forced) {
    return;
  }
  for (const path of missing) {
    console.error(`rm: ${path}: No such file or directory`);
  }
  process.exit(1);
}

// Attempts to move the provided paths into trash instead of deleting in place.
async function movePathsToTrash(
  paths: string[],
  baseDir: string,
  options: { allowMissing: boolean }
): Promise<MoveResult> {
  const missing: string[] = [];
  const existing: { raw: string; absolute: string }[] = [];

  for (const rawPath of paths) {
    const absolute = resolvePath(baseDir, rawPath);
    if (!existsSync(absolute)) {
      if (!options.allowMissing) {
        missing.push(rawPath);
      }
      continue;
    }
    existing.push({ raw: rawPath, absolute });
  }

  if (existing.length === 0) {
    return { missing, errors: [] };
  }

  const trashCliCommand = await findTrashCliCommand();
  if (trashCliCommand) {
    try {
      const cliArgs = [trashCliCommand, ...existing.map((item) => item.absolute)];
      const proc = Bun.spawn(cliArgs, {
        stdout: 'ignore',
        stderr: 'pipe',
      });
      const [exitCode, stderrText] = await Promise.all([proc.exited, readProcessStream(proc.stderr)]);
      if (exitCode === 0) {
        return { missing, errors: [] };
      }
      if (ENABLE_DEBUG_LOGS && stderrText.trim().length > 0) {
        console.error(`[runner] trash-cli error (${trashCliCommand}): ${stderrText.trim()}`);
      }
    } catch (error) {
      if (ENABLE_DEBUG_LOGS) {
        console.error(`[runner] trash-cli invocation failed: ${formatTrashError(error)}`);
      }
    }
  }

  const trashDir = getTrashDirectory();
  if (!trashDir) {
    return {
      missing,
      errors: ['Unable to locate macOS Trash directory (HOME/.Trash).'],
    };
  }

  const errors: string[] = [];

  for (const item of existing) {
    try {
      const target = buildTrashTarget(trashDir, item.absolute);
      try {
        renameSync(item.absolute, target);
      } catch (error) {
        if (isCrossDeviceError(error)) {
          cpSync(item.absolute, target, { recursive: true });
          rmSync(item.absolute, { recursive: true, force: true });
        } else {
          throw error;
        }
      }
    } catch (error) {
      errors.push(`Failed to move ${item.raw} to Trash: ${formatTrashError(error)}`);
    }
  }

  return { missing, errors };
}

// Resolves a potentially relative path against the workspace root.
function resolvePath(baseDir: string, input: string): string {
  if (input.startsWith('/')) {
    return input;
  }
  return resolve(baseDir, input);
}

// Returns the trash CLI directory if available so deletes can be safe.
function getTrashDirectory(): string | null {
  const home = process.env.HOME;
  if (!home) {
    return null;
  }
  const trash = join(home, '.Trash');
  if (!existsSync(trash)) {
    return null;
  }
  return trash;
}

// Builds the destination path inside the trash directory for a file.
function buildTrashTarget(trashDir: string, absolutePath: string): string {
  const baseName = basename(absolutePath);
  const timestamp = Date.now();
  let attempt = 0;
  let candidate = join(trashDir, baseName);
  while (existsSync(candidate)) {
    candidate = join(trashDir, `${baseName}-${timestamp}${attempt > 0 ? `-${attempt}` : ''}`);
    attempt += 1;
  }
  return candidate;
}

// Determines whether a rename failed because the devices differ.
function isCrossDeviceError(error: unknown): boolean {
  return error instanceof Error && 'code' in error && (error as NodeJS.ErrnoException).code === 'EXDEV';
}

// Normalizes trash/rename errors into a readable string.
function formatTrashError(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }
  return String(error);
}

// Replays a git rm plan via spawn so we can surface errors consistently.
async function stageGitRm(workDir: string, plan: GitRmPlan) {
  if (plan.paths.length === 0) {
    return;
  }
  const args = ['git', 'rm', '--cached', '--quiet', ...plan.stagingOptions, '--', ...plan.paths];
  const proc = Bun.spawn(args, {
    cwd: workDir,
    stdout: 'inherit',
    stderr: 'inherit',
  });
  const exitCode = await proc.exited;
  if (exitCode !== 0) {
    throw new Error(`git rm --cached exited with status ${exitCode}.`);
  }
}

// Locates a usable trash CLI binary, caching the lookup per runner process.
async function findTrashCliCommand(): Promise<string | null> {
  if (cachedTrashCliCommand !== undefined) {
    return cachedTrashCliCommand;
  }

  const candidateNames = ['trash-put', 'trash'];
  const searchDirs = new Set<string>();

  if (process.env.PATH) {
    for (const segment of process.env.PATH.split(':')) {
      if (segment && segment.length > 0) {
        searchDirs.add(segment);
      }
    }
  }

  const homebrewPrefix = process.env.HOMEBREW_PREFIX ?? '/opt/homebrew';
  searchDirs.add(join(homebrewPrefix, 'opt', 'trash', 'bin'));
  searchDirs.add('/usr/local/opt/trash/bin');

  const candidatePaths = new Set<string>();
  for (const name of candidateNames) {
    candidatePaths.add(name);
    for (const dir of searchDirs) {
      candidatePaths.add(join(dir, name));
    }
  }

  for (const candidate of candidatePaths) {
    try {
      const proc = Bun.spawn([candidate, '--help'], {
        stdout: 'ignore',
        stderr: 'ignore',
      });
      const exitCode = await proc.exited;
      if (exitCode === 0 || exitCode === 1) {
        cachedTrashCliCommand = candidate;
        return candidate;
      }
    } catch (error) {
      if (ENABLE_DEBUG_LOGS) {
        console.error(`[runner] trash-cli probe failed for ${candidate}: ${formatTrashError(error)}`);
      }
    }
  }

  cachedTrashCliCommand = null;
  return null;
}

// Consumes a child process stream to completion for logging/error output.
async function readProcessStream(stream: unknown): Promise<string> {
  if (!stream) {
    return '';
  }
  try {
    const candidate = stream as { text?: () => Promise<string> };
    if (candidate.text) {
      return (await candidate.text()) ?? '';
    }
  } catch {
    // ignore
  }
  try {
    if (stream instanceof ReadableStream) {
      return await new Response(stream).text();
    }
    if (typeof stream === 'object' && stream !== null) {
      return await new Response(stream as BodyInit).text();
    }
  } catch {
    // ignore errors and return empty string
  }
  return '';
}

// Shows CLI usage plus optional error messaging.
function printUsage(message?: string) {
  if (message) {
    console.error(`[runner] ${message}`);
  }
  console.error('Usage: runner [--] <command...>');
  console.error('');
  console.error(
    `Defaults: ${formatDuration(DEFAULT_TIMEOUT_MS)} timeout for most commands, ${formatDuration(
      EXTENDED_TIMEOUT_MS
    )} when lint/test suites are detected.`
  );
}

// Pretty-prints a millisecond duration for logs.
function formatDuration(durationMs: number): string {
  if (durationMs < 1000) {
    return `${durationMs}ms`;
  }
  const seconds = durationMs / 1000;
  if (seconds < 60) {
    return `${seconds.toFixed(1)}s`;
  }
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = Math.round(seconds % 60);
  if (minutes < 60) {
    if (remainingSeconds === 0) {
      return `${minutes}m`;
    }
    return `${minutes}m ${remainingSeconds}s`;
  }
  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;
  if (remainingMinutes === 0) {
    return `${hours}h`;
  }
  return `${hours}h ${remainingMinutes}m`;
}

function resolveSummaryStyle(rawValue: string | undefined | null): SummaryStyle {
  if (!rawValue) {
    return 'compact';
  }
  const normalized = rawValue.trim().toLowerCase();
  switch (normalized) {
    case 'minimal':
      return 'minimal';
    case 'verbose':
      return 'verbose';
    case 'compact':
    case 'short':
    default:
      return 'compact';
  }
}

function formatCompletionSummary(options: {
  exitCode: number;
  elapsedMs?: number;
  timedOut?: boolean;
  commandLabel: string;
}): string {
  const { exitCode, elapsedMs, timedOut, commandLabel } = options;
  const durationText = typeof elapsedMs === 'number' ? formatDuration(elapsedMs) : null;
  switch (SUMMARY_STYLE) {
    case 'minimal': {
      const parts = [`${exitCode}`];
      if (durationText) {
        parts.push(durationText);
      }
      if (timedOut) {
        parts.push('timeout');
      }
      return `[runner] ${parts.join(' · ')}`;
    }
    case 'verbose': {
      const elapsedPart = durationText ? `, elapsed ${durationText}` : '';
      const timeoutPart = timedOut ? '; timed out' : '';
      return `[runner] Finished ${commandLabel} (exit ${exitCode}${elapsedPart}${timeoutPart}).`;
    }
    case 'compact':
    default: {
      const elapsedPart = durationText ? ` in ${durationText}` : '';
      const timeoutPart = timedOut ? ' (timeout)' : '';
      return `[runner] exit ${exitCode}${elapsedPart}${timeoutPart}`;
    }
  }
}

// Joins the command args in a shell-friendly way for log display.
function formatDisplayCommand(commandArgs: string[]): string {
  return commandArgs.map((token) => (token.includes(' ') ? `"${token}"` : token)).join(' ');
}

// Tells whether the runner is already executing inside the tmux guard.
function isRunnerTmuxSession(): boolean {
  const value = process.env.RUNNER_TMUX;
  if (value) {
    return value !== '0' && value.toLowerCase() !== 'false';
  }
  return Boolean(process.env.TMUX);
}
