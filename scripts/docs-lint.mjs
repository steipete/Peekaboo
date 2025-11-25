#!/usr/bin/env node
/**
 * Minimal docs linter: verifies every Markdown file in docs/ has front matter
 * with a summary and at least one read_when entry.
 */
import { promises as fs } from 'fs';
import path from 'path';

const docsRoot = path.resolve('docs');
const failures = [];

async function walk(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      await walk(full);
    } else if (entry.isFile() && entry.name.endsWith('.md')) {
      await checkFile(full);
    }
  }
}

async function checkFile(file) {
  const text = await fs.readFile(file, 'utf8');
  const trimmed = text.trimStart();
  if (!trimmed.startsWith('---')) {
    failures.push(`${file}: missing front matter start`);
    return;
  }
  const end = trimmed.indexOf('\n---', 3);
  if (end === -1) {
    failures.push(`${file}: missing front matter end delimiter`);
    return;
  }
  const header = trimmed.slice(3, end).split('\n').map(l => l.trim());
  const hasSummary = header.some(l => l.startsWith('summary:') && l.replace('summary:', '').trim().length > 0);
  const readWhenStart = header.findIndex(l => l.startsWith('read_when:'));
  let hasReadWhen = false;
  if (readWhenStart !== -1) {
    for (let i = readWhenStart + 1; i < header.length; i++) {
      const line = header[i];
      if (!line.startsWith('-') && !line.startsWith('#') && !line.startsWith('summary:') && !line.startsWith('read_when:') && line.length) break;
      if (line.startsWith('-')) {
        hasReadWhen = true;
        break;
      }
    }
  }
  if (!hasSummary) failures.push(`${file}: summary missing or empty`);
  if (readWhenStart === -1) failures.push(`${file}: read_when missing`);
  else if (!hasReadWhen) failures.push(`${file}: read_when has no entries`);
}

await walk(docsRoot);

if (failures.length) {
  console.error('Docs lint failures:');
  failures.forEach(f => console.error(' -', f));
  process.exit(1);
}

console.log('docs-lint: ok');
