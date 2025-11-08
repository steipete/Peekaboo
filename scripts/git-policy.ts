import { resolve } from 'node:path';

export type GitInvocation = {
  index: number;
  argv: string[];
};

export type GitCommandInfo = {
  name: string;
  index: number;
};

export type GitExecutionContext = {
  invocation: GitInvocation | null;
  command: GitCommandInfo | null;
  subcommand: string | null;
  workDir: string;
};

export type GitPolicyEvaluation = {
  requiresCommitHelper: boolean;
  requiresExplicitConsent: boolean;
  isDestructive: boolean;
};

const COMMIT_HELPER_SUBCOMMANDS = new Set(['add', 'commit']);
const GUARDED_SUBCOMMANDS = new Set(['push', 'pull', 'merge', 'rebase', 'cherry-pick']);
const DESTRUCTIVE_SUBCOMMANDS = new Set([
  'reset',
  'checkout',
  'clean',
  'restore',
  'switch',
  'stash',
  'branch',
  'filter-branch',
  'fast-import',
]);

export function extractGitInvocation(commandArgs: string[]): GitInvocation | null {
  for (const [index, token] of commandArgs.entries()) {
    if (token === 'git' || token.endsWith('/git')) {
      return { index, argv: commandArgs.slice(index) };
    }
  }
  return null;
}

export function findGitSubcommand(commandArgs: string[]): GitCommandInfo | null {
  if (commandArgs.length <= 1) {
    return null;
  }

  const optionsWithValue = new Set(['-C', '--git-dir', '--work-tree', '-c']);
  let index = 1;

  while (index < commandArgs.length) {
    const token = commandArgs[index];
    if (token === '--') {
      const next = commandArgs[index + 1];
      return next ? { name: next, index: index + 1 } : null;
    }
    if (!token.startsWith('-')) {
      return { name: token, index };
    }
    if (token.includes('=')) {
      index += 1;
      continue;
    }
    if (optionsWithValue.has(token)) {
      index += 2;
      continue;
    }
    index += 1;
  }
  return null;
}

export function determineGitWorkdir(baseDir: string, gitArgs: string[], command: GitCommandInfo | null): string {
  let workDir = baseDir;
  const limit = command ? command.index : gitArgs.length;
  let index = 1;

  while (index < limit) {
    const token = gitArgs[index];
    if (token === '-C') {
      const next = gitArgs[index + 1];
      if (next) {
        workDir = resolve(workDir, next);
      }
      index += 2;
      continue;
    }
    if (token.startsWith('-C')) {
      const pathSegment = token.slice(2);
      if (pathSegment.length > 0) {
        workDir = resolve(workDir, pathSegment);
      }
    }
    index += 1;
  }

  return workDir;
}

export function analyzeGitExecution(commandArgs: string[], workspaceDir: string): GitExecutionContext {
  const invocation = extractGitInvocation(commandArgs);
  const command = invocation ? findGitSubcommand(invocation.argv) : null;
  const workDir = invocation ? determineGitWorkdir(workspaceDir, invocation.argv, command) : workspaceDir;

  return {
    invocation,
    command,
    subcommand: command?.name ?? null,
    workDir,
  };
}

export function requiresCommitHelper(subcommand: string | null): boolean {
  if (!subcommand) {
    return false;
  }
  return COMMIT_HELPER_SUBCOMMANDS.has(subcommand);
}

export function requiresExplicitGitConsent(subcommand: string | null): boolean {
  if (!subcommand) {
    return false;
  }
  return GUARDED_SUBCOMMANDS.has(subcommand);
}

export function isDestructiveGitSubcommand(command: GitCommandInfo | null, gitArgv: string[]): boolean {
  if (!command) {
    return false;
  }

  const subcommand = command.name;
  if (DESTRUCTIVE_SUBCOMMANDS.has(subcommand)) {
    return true;
  }

  if (subcommand === 'bisect') {
    const action = gitArgv[command.index + 1] ?? '';
    return action === 'reset';
  }

  return false;
}

export function evaluateGitPolicies(context: GitExecutionContext): GitPolicyEvaluation {
  const invocationArgv = context.invocation?.argv;
  const normalizedArgv = Array.isArray(invocationArgv) ? invocationArgv : [];
  return {
    requiresCommitHelper: requiresCommitHelper(context.subcommand),
    requiresExplicitConsent: requiresExplicitGitConsent(context.subcommand),
    isDestructive: isDestructiveGitSubcommand(context.command, normalizedArgv),
  };
}
