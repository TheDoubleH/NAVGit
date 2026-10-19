// Copies the NAVGit PowerShell module (../module/NAVGit) and the license into the extension, so the packaged
// extension carries the module and the navgit.json schema.
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const source = path.resolve(root, '..', 'module', 'NAVGit');
const target = path.join(root, 'resources', 'NAVGit');

if (!fs.existsSync(path.join(source, 'NAVGit.psd1'))) {
    console.error(`NAVGit module not found at ${source}`);
    process.exit(1);
}

fs.rmSync(target, { recursive: true, force: true });
fs.mkdirSync(path.dirname(target), { recursive: true });
fs.cpSync(source, target, { recursive: true });
fs.copyFileSync(path.resolve(root, '..', 'LICENSE'), path.join(root, 'LICENSE'));
console.log(`Copied ${source} -> ${target}`);
