import * as assert from 'assert';
import * as fs from 'fs';
import * as path from 'path';
import { test } from 'node:test';
import { createConfigCommandId, navGitCommands, sortProfiles } from '../src/commands/registry';

// Compiled to out-test/test, so the project root is two levels up.
const root = path.resolve(__dirname, '..', '..');
const packageJson = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
const commandsPsd1 = fs.readFileSync(path.resolve(root, '..', 'module', 'NavGit', 'Commands.psd1'), 'utf8');

test('package.json contributes exactly the registry commands plus Create navgit.json', () => {
    const contributed = packageJson.contributes.commands.map((command: { command: string }) => command.command).sort();
    const expected = [...navGitCommands.map((command) => command.id), createConfigCommandId].sort();
    assert.deepStrictEqual(contributed, expected);
});

test('titles in package.json match the registry', () => {
    for (const command of navGitCommands) {
        const contributed = packageJson.contributes.commands.find((entry: { command: string }) => entry.command === command.id);
        assert.strictEqual(contributed.title, command.title, command.id);
        assert.strictEqual(contributed.category, 'NavGit', command.id);
    }
});

test('every registry entry exists in the PowerShell Commands.psd1', () => {
    for (const command of navGitCommands) {
        assert.match(commandsPsd1, new RegExp(`Name\\s*=\\s*'${command.psName}'`), command.psName);
    }
});

test('the planned commands are present', () => {
    const titles = navGitCommands.map((command) => command.title);
    for (const title of [
        'Build and Update Container',
        'Build Container',
        'Remove Container',
        'Import Test Toolkit',
        'Import All GIT Objects to NAV',
        'Export NAV objects to GIT',
        'Start Development Environment (FinSql)',
        'Start NAV Client (default)',
        'Start NAV Client...',
    ]) {
        assert.ok(titles.includes(title), title);
    }
});

test('only Remove Container asks for confirmation and only Start NAV Client... picks a profile', () => {
    assert.deepStrictEqual(navGitCommands.filter((command) => command.confirm).map((command) => command.id), ['navgit.removeContainer']);
    assert.deepStrictEqual(navGitCommands.filter((command) => command.pickProfile).map((command) => command.id), ['navgit.startClient']);
});

test('client commands run in the background, the others in an (elevated) terminal', () => {
    const background = navGitCommands.filter((command) => command.mode === 'background').map((command) => command.psName);
    assert.deepStrictEqual([...new Set(background)].sort(), ['StartClient', 'StartDevEnv']);
});

test('sortProfiles puts the default first, then sorts by id', () => {
    const sorted = sortProfiles([
        { Id: 'SALES', Description: '', RoleCenterId: 1, IsDefault: false },
        { Id: 'ORDER PROCESSOR', Description: '', RoleCenterId: 2, IsDefault: true },
        { Id: 'ACCOUNTANT', Description: '', RoleCenterId: 3, IsDefault: false },
    ]);
    assert.deepStrictEqual(sorted.map((profile) => profile.Id), ['ORDER PROCESSOR', 'ACCOUNTANT', 'SALES']);
});
