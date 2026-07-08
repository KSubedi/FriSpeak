#!/usr/bin/env node
// FriSpeak local release script.
//
//   npm run release        # full release
//   npm run release:dry    # show what would happen, change nothing
//
// Flow:
//   1. Preflight (Xcode, gh, fetch tags, clean tree)
//   2. Compute a date-based version: vYY.MM.DD, appending 1, 2, 3 ... for
//      additional same-day releases (vYY.MM.DD1, vYY.MM.DD2, ...).
//   3. Bump MARKETING_VERSION / CURRENT_PROJECT_VERSION in the Xcode project.
//   4. Commit the version bump.
//   5. Build + package the DMG (scripts/package-dmg.sh).
//   6. Prompt for a release message.
//   7. Generate release notes (install + unsigned-app + macOS permission reset).
//   8. Push the version commit and create the GitHub Release with the DMG.

import { execSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import readline from 'node:readline';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT = path.resolve(__dirname, '..');

const PBXPROJ = path.join(ROOT, 'FriSpeak.xcodeproj', 'project.pbxproj');
const BUILD_DIR = path.join(ROOT, 'build');
const DMG_PATH = path.join(BUILD_DIR, 'FriSpeak.dmg');
const PACKAGE_DMG = path.join(ROOT, 'scripts', 'package-dmg.sh');
const NOTES_PATH = path.join(BUILD_DIR, 'release-notes.md');
const BUNDLE_ID = 'com.fridev.FriSpeak';

const argv = process.argv.slice(2);
const DRY_RUN = argv.includes('--dry-run') || argv.includes('-n');

function run(cmd, opts = {}) {
  return execSync(cmd, { cwd: ROOT, stdio: 'inherit', ...opts });
}
function capture(cmd, opts = {}) {
  return execSync(cmd, { cwd: ROOT, stdio: ['ignore', 'pipe', 'pipe'], ...opts }).toString();
}
const gitCapture = (a) => capture(`git ${a}`).trim();
const gitRun = (a) => run(`git ${a}`);

function log(msg = '') { console.log(msg); }
function die(msg) { console.error(`\n✖ ${msg}`); process.exit(1); }
function step(name) { log(`\n▶ ${name}`); }

// ── Preflight ──────────────────────────────────────────────────────────────
function preflight() {
  step('Preflight checks');

  try {
    const devDir = capture('xcode-select -p').trim();
    if (devDir === '/Library/Developer/CommandLineTools') {
      die('xcode-select points to CommandLineTools, not full Xcode.\n  Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer');
    }
    log(`  ✓ Xcode: ${devDir}`);
  } catch {
    die('Xcode is not installed or xcode-select is not set.\n  Install Xcode, then: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer');
  }

  try { capture('gh --version'); }
  catch { die('GitHub CLI (gh) is not installed. Install it from https://cli.github.com'); }

  try { capture('gh auth status'); }
  catch { die('You are not logged in to gh. Run: gh auth login'); }
  log('  ✓ gh authenticated');

  // Keep local tags in sync with the remote so same-day release counts are correct.
  try {
    gitRun('fetch --tags origin');
    log('  ✓ Tags fetched from origin');
  } catch {
    die('Could not fetch tags from origin. Check your remote and network: git remote -v');
  }

  const branch = gitCapture('branch --show-current');
  if (!branch) die('HEAD is detached. Checkout a branch before releasing.');
  log(`  ✓ Branch: ${branch}`);

  if (!DRY_RUN) {
    const status = gitCapture('status --porcelain');
    if (status) {
      die(`Working tree is not clean. Commit or stash these before releasing:\n${status}`);
    }
    log('  ✓ Working tree clean');
  }

  return branch;
}

// ── Version ────────────────────────────────────────────────────────────────
// vYY.MM.DD for the first release of the day, then vYY.MM.DD1, vYY.MM.DD2, ...
function computeVersion() {
  const now = new Date();
  const yy = String(now.getFullYear() % 100).padStart(2, '0');
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const dd = String(now.getDate()).padStart(2, '0');
  const dateVersion = `${yy}.${mm}.${dd}`;
  const tagPrefix = `v${dateVersion}`;

  const existing = gitCapture(`tag -l "${tagPrefix}*"`).split('\n').filter(Boolean);
  const count = existing.length;

  let version;
  let buildNum;
  if (count === 0) {
    version = tagPrefix;               // v26.07.08
    buildNum = 1;
  } else {
    version = `${tagPrefix}${count}`;  // v26.07.081, v26.07.082, ...
    buildNum = count + 1;
  }
  const marketing = version.replace(/^v/, '');
  return { version, marketing, buildNum, existing };
}

// ── Bump Xcode project version ─────────────────────────────────────────────
function bumpProject(marketing, buildNum) {
  if (DRY_RUN) {
    log(`  (dry-run) would set MARKETING_VERSION = ${marketing}; CURRENT_PROJECT_VERSION = ${buildNum};`);
    return;
  }
  let pbx = readFileSync(PBXPROJ, 'utf8');
  const mCount = (pbx.match(/MARKETING_VERSION = [^;]*;/g) || []).length;
  const cCount = (pbx.match(/CURRENT_PROJECT_VERSION = [0-9]*;/g) || []).length;
  pbx = pbx.replace(/MARKETING_VERSION = [^;]*;/g, `MARKETING_VERSION = ${marketing};`);
  pbx = pbx.replace(/CURRENT_PROJECT_VERSION = [0-9]*;/g, `CURRENT_PROJECT_VERSION = ${buildNum};`);
  writeFileSync(PBXPROJ, pbx);
  log(`  ✓ MARKETING_VERSION → ${marketing} (${mCount} entries)`);
  log(`  ✓ CURRENT_PROJECT_VERSION → ${buildNum} (${cCount} entries)`);
}

// ── Commit the version bump ────────────────────────────────────────────────
function commitBump(version) {
  if (DRY_RUN) { log(`  (dry-run) would commit: Bump version to ${version}`); return; }
  gitRun('add FriSpeak.xcodeproj/project.pbxproj');
  const staged = gitCapture('diff --cached --name-only');
  if (!staged) {
    log('  ✓ Version already bumped (no new commit needed)');
    return;
  }
  run(`git commit -m "Bump version to ${version}"`);
  log('  ✓ Committed version bump');
}

// ── Build + package DMG ────────────────────────────────────────────────────
function buildDmg() {
  if (DRY_RUN) { log('  (dry-run) would run: bash scripts/package-dmg.sh'); return; }
  if (!existsSync(PACKAGE_DMG)) die(`Missing ${PACKAGE_DMG}`);
  run(`bash "${PACKAGE_DMG}"`);
  if (!existsSync(DMG_PATH)) die(`DMG was not produced at ${DMG_PATH}`);
  const sizeMB = (statSync(DMG_PATH).size / 1048576).toFixed(1);
  log(`  ✓ DMG: ${DMG_PATH} (${sizeMB} MB)`);
}

// ── Release message prompt ─────────────────────────────────────────────────
function askMessage(version) {
  return new Promise((resolve) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(`\nRelease version: ${version}\nEnter release message (what's new), then press Enter: `, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

// ── Release notes ──────────────────────────────────────────────────────────
function buildNotes(version, message) {
  const userNotes = (message && message.trim()) || `Release ${version}.`;
  const F = '```';
  const ctrl = '`Ctrl`';
  const lines = [
    `# FriSpeak ${version}`,
    '',
    userNotes,
    '',
    '## Installation',
    '1. Download **FriSpeak.dmg** below.',
    '2. Open it and drag **FriSpeak** into your **Applications** folder.',
    '3. Launch FriSpeak from Applications and complete onboarding.',
    '',
    '## Opening an unsigned app (macOS Gatekeeper)',
    'This build is not signed with an Apple Developer ID, so macOS Gatekeeper will block the first launch. Use any one of these:',
    '',
    '**Option A — Right-click → Open (easiest)**',
    `- Right-click (or ${ctrl}+click) **FriSpeak.app** in Applications.`,
    '- Select **Open**, then click **Open** in the dialog. You only need to do this once.',
    '',
    '**Option B — Remove the quarantine attribute**',
    `${F}bash`,
    'xattr -rd com.apple.quarantine /Applications/FriSpeak.app',
    F,
    '',
    '**Option C — System Settings**',
    '1. Open **System Settings → Privacy & Security**.',
    '2. Scroll down to the **Security** section.',
    '3. Find the message about FriSpeak being blocked and click **Open Anyway**.',
    '',
    '## Resetting macOS permissions',
    'FriSpeak needs **Microphone** and **Accessibility** permissions. If the hotkey stops working or it cannot hear audio, reset and re-grant them:',
    '',
    'Reset Microphone permission:',
    `${F}bash`,
    `tccutil reset Microphone ${BUNDLE_ID}`,
    F,
    '',
    'Reset Accessibility permission:',
    `${F}bash`,
    `tccutil reset Accessibility ${BUNDLE_ID}`,
    F,
    '',
    'Reset all permissions for FriSpeak at once:',
    `${F}bash`,
    `tccutil reset All ${BUNDLE_ID}`,
    F,
    '',
    'Then re-launch FriSpeak and grant the permissions again when prompted.',
    '',
  ];
  return lines.join('\n');
}

// ── Push + GitHub release ──────────────────────────────────────────────────
function publish(version, branch) {
  if (DRY_RUN) {
    log(`  (dry-run) would: git push origin ${branch}`);
    log(`  (dry-run) would: gh release create "${version}" "${DMG_PATH}" --title "FriSpeak ${version}" --notes-file "${NOTES_PATH}" --target "${branch}"`);
    return;
  }
  step(`Pushing version bump to origin/${branch}`);
  gitRun(`push origin ${branch}`);

  step('Creating GitHub release');
  run(`gh release create "${version}" "${DMG_PATH}" --title "FriSpeak ${version}" --notes-file "${NOTES_PATH}" --target "${branch}"`);
}

// ── Main ───────────────────────────────────────────────────────────────────
async function main() {
  log('╔══════════════════════════════════════════╗');
  log('║        FriSpeak Local Release            ║');
  log('╚══════════════════════════════════════════╝');
  if (DRY_RUN) log('  (dry-run — nothing will be changed)');

  const branch = preflight();

  const { version, marketing, buildNum, existing } = computeVersion();
  step('Version');
  log(`  Date-based tag : v${marketing}`);
  if (existing.length) log(`  Same-day tags  : ${existing.join(', ')}`);
  log(`  Release version: ${version} (build ${buildNum})`);

  step('Bump Xcode project version');
  bumpProject(marketing, buildNum);

  step('Commit version bump');
  commitBump(version);

  step('Build & package DMG');
  buildDmg();

  const message = DRY_RUN ? 'Sample release message for dry run.' : await askMessage(version);

  step('Generate release notes');
  mkdirSync(BUILD_DIR, { recursive: true });
  const notes = buildNotes(version, message);
  writeFileSync(NOTES_PATH, notes);
  if (DRY_RUN) {
    log(`  (dry-run) notes preview written to ${NOTES_PATH}`);
    log('\n----- notes preview -----');
    log(notes);
    log('----- end preview -----');
  } else {
    log(`  ✓ Notes: ${NOTES_PATH}`);
  }

  step('Publish');
  publish(version, branch);

  if (DRY_RUN) {
    log('\n✓ Dry run complete. Nothing was changed.');
  } else {
    const repo = capture('gh repo view --json nameWithOwner -q .nameWithOwner').trim();
    log(`\n✓ Released ${version}`);
    log(`  https://github.com/${repo}/releases/tag/${version}`);
  }
}

main().catch((err) => die(err && err.message ? err.message : String(err)));

