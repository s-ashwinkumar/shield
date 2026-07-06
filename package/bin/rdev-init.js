#!/usr/bin/env node
// rdev-init — npm shim that runs the bash installer against the user's CWD.
// Resolves the package root (where setup + skills/ + agents/ live) and execs setup.

const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const pkgRoot = path.resolve(__dirname, '..');
const setupScript = path.join(pkgRoot, 'setup');

if (!fs.existsSync(setupScript)) {
  console.error(`rdev-init: setup script not found at ${setupScript}`);
  console.error('Reinstall the package — files may be corrupted.');
  process.exit(1);
}

if (process.platform === 'win32') {
  console.error('rdev-init: Windows is not supported. The installer requires bash.');
  console.error('Workarounds: use WSL2, or clone the repo and run setup from a Unix shell.');
  process.exit(1);
}

// Pass user's CWD (or whatever extra args they gave) through to setup.
const targetDir = process.cwd();
const extraArgs = process.argv.slice(2);
const args = extraArgs.length > 0 ? extraArgs : [targetDir];

const result = spawnSync('bash', [setupScript, ...args], {
  stdio: 'inherit',
  cwd: targetDir,
});

process.exit(result.status ?? 1);
