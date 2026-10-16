// Copies the NavGit PowerShell module (../module/NavGit) and the license into the extension, so the packaged
// extension carries the module and the navgit.json schema.
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const source = path.resolve(root, '..', 'module', 'NavGit');
const target = path.join(root, 'resources', 'NavGit');

if (!fs.existsSync(path.join(source, 'NavGit.psd1'))) {
    console.error(`NavGit module not found at ${source}`);
    process.exit(1);
}

fs.rmSync(target, { recursive: true, force: true });
fs.mkdirSync(path.dirname(target), { recursive: true });
fs.cpSync(source, target, { recursive: true });
fs.copyFileSync(path.resolve(root, '..', 'LICENSE'), path.join(root, 'LICENSE'));
console.log(`Copied ${source} -> ${target}`);
