#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const skill = join(root, 'skills/firestartr/firestartr-operation');
const packageName = '@firestartr/fs-forge-cli';

function run(command, args) {
  return execFileSync(command, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

// npm's latest tag may be a prerelease; compare it using semver precedence.
function compareVersions(a, b) {
  function parse(version) {
    const match = /^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/.exec(version);
    if (!match) throw new Error(`Invalid semver: ${version}`);
    return { core: match.slice(1, 4).map(Number), pre: match[4]?.split('.') };
  }
  const left = parse(a), right = parse(b);
  for (let i = 0; i < 3; i++) {
    if (left.core[i] !== right.core[i]) return left.core[i] - right.core[i];
  }
  if (!left.pre || !right.pre) return Number(!left.pre) - Number(!right.pre);
  for (let i = 0; i < Math.max(left.pre.length, right.pre.length); i++) {
    const x = left.pre[i], y = right.pre[i];
    if (x === undefined || y === undefined) return x === undefined ? -1 : 1;
    if (x === y) continue;
    const xn = /^\d+$/.test(x), yn = /^\d+$/.test(y);
    if (xn && yn) return Number(x) - Number(y);
    if (xn !== yn) return xn ? -1 : 1;
    return x < y ? -1 : 1;
  }
  return 0;
}

function markdownFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const path = join(dir, entry.name);
    return entry.isDirectory() ? markdownFiles(path) : entry.name.endsWith('.md') ? [path] : [];
  }).sort();
}

// Return each inline or fenced invocation, joining only shell continuation lines.
function invocations(path) {
  const lines = readFileSync(path, 'utf8').split(/\r?\n/);
  const result = [];
  let fence = false;
  for (let i = 0; i < lines.length; i++) {
    if (/^\s*```/.test(lines[i])) { fence = !fence; continue; }
    const pattern = /\bnpx\s+(?:-y\s+)?@firestartr\/fs-forge-cli@[^\s`]+\s*/g;
    for (const match of lines[i].matchAll(pattern)) {
      let body = lines[i].slice(match.index + match[0].length);
      if (!fence) body = body.split('`', 1)[0];
      else {
        let next = i;
        while (/\\\s*$/.test(body) && next + 1 < lines.length) {
          body = body.replace(/\\\s*$/, '') + '\n' + lines[++next];
        }
      }
      result.push({ body, line: i + 1 });
    }
  }
  return result;
}

function flagUses(body) {
  // Mask quoted values, and stop at a pipe to another shell command (not | in
  // the documented parenthesized or bracketed flag alternatives).
  let visible = '', quote = '';
  for (let i = 0; i < body.length; i++) {
    const c = body[i];
    if (quote) {
      if (c === quote && body[i - 1] !== '\\') quote = '';
      visible += c === '\n' ? '\n' : ' ';
    } else if (c === "'" || c === '"') {
      quote = c;
      visible += ' ';
    } else if (c === '|' && /^\|\s+[a-z]/.test(body.slice(i))) {
      break;
    } else visible += c;
  }
  const pattern = /(?:^|[\s[(|])(--[A-Za-z][\w.-]*|-[A-Za-z])(?==|[\s\])|]|$|<)/g;
  return [...visible.matchAll(pattern)].map(match => ({
    flag: match[1],
    lineOffset: visible.slice(0, match.index + match[0].indexOf(match[1])).split('\n').length - 1,
  }));
}

function check() {
  const targetMatch = /\*\*Skill-target CLI version: `([^`]+)`\*\*/.exec(readFileSync(join(skill, 'SKILL.md'), 'utf8'));
  if (!targetMatch) throw new Error('Skill-target CLI version not found in SKILL.md');
  const target = targetMatch[1];
  const latest = run('npm', ['view', packageName, 'version']).trim();
  if (compareVersions(latest, target) > 0) {
    console.log(`::warning::${packageName} latest ${latest} is newer than skill target ${target}`);
  }

  const temp = mkdtempSync(join(tmpdir(), 'firestartr-cli-contract-'));
  try {
    run('npm', ['install', '--prefix', temp, '--no-audit', '--no-fund', `${packageName}@${target}`]);
    const pkg = join(temp, 'node_modules', '@firestartr', 'fs-forge-cli');
    const manifest = JSON.parse(readFileSync(join(pkg, 'oclif.manifest.json'), 'utf8'));
    const cli = join(temp, 'node_modules', '.bin', 'fs-forge');
    const commands = new Map();
    for (const id of Object.keys(manifest.commands)) {
      const help = JSON.parse(run(cli, [...id.split(':'), '--help', '--json']));
      if (help.id !== id || !Array.isArray(help.flags)) throw new Error(`Invalid help for ${id}`);
      commands.set(id, help.flags);
    }
    const createFlags = [...commands.entries()].filter(([id]) => id.startsWith('create:')).flatMap(([, flags]) => flags);
    const topics = new Set([...commands.keys()].filter(id => id.includes(':')).map(id => id.split(':')[0]));
    let errors = 0, checked = 0;
    for (const file of markdownFiles(skill)) {
      for (const { body, line } of invocations(file)) {
        const words = body.trim().split(/\s+/);
        if (['<args>', '...', '…', ''].includes(words[0])) continue;
        checked++;
        let id = words[0], flags = commands.get(id);
        if (topics.has(id)) {
          const subcommand = words[1];
          if (id === 'create' && subcommand === '<kind>') flags = createFlags;
          else if (!subcommand || subcommand.startsWith('--')) flags = [];
          else { id += `:${subcommand}`; flags = commands.get(id); }
        }
        if (!flags) {
          console.error(`${relative(root, file)}:${line}: unknown command ${id.replaceAll(':', ' ')}`);
          errors++;
          continue;
        }
        const uses = flagUses(body);
        const helpRequested = uses.some(({ flag }) => flag === '--help');
        for (const use of uses) {
          const name = use.flag.slice(use.flag.startsWith('--') ? 2 : 1);
          if (name.startsWith('args.')) continue;
          const valid = use.flag === '--help' || (use.flag === '--json' && helpRequested) || flags.some(flag => {
            if (use.flag.startsWith('--')) return flag.name === name || (name.startsWith('no-') && flag.name === name.slice(3) && flag.allowNo === true);
            return flag.char === name;
          });
          if (!valid) {
            console.error(`${relative(root, file)}:${line + use.lineOffset}: unknown flag ${use.flag} for ${id.replaceAll(':', ' ')}`);
            errors++;
          }
        }
      }
    }
    if (errors) process.exitCode = 1;
    else console.log(`Checked ${checked} invocations against ${packageName}@${target}`);
  } finally {
    rmSync(temp, { recursive: true, force: true });
  }
}

try { check(); }
catch (error) {
  console.error(`CLI contract check failed: ${error.message}`);
  if (error.stderr) console.error(String(error.stderr).trim());
  process.exitCode = 1;
}
