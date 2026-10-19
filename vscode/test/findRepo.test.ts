import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { after, test } from 'node:test';
import { findAdvaniaGitRepositories, findRepositories, findRepositoryUpwards } from '../src/workspace/findRepo';

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'navgit-findrepo-'));
after(() => fs.rmSync(root, { recursive: true, force: true }));

function makeRepo(name: string, files: string[] = ['navgit.json']): string {
    const folder = path.join(root, name);
    fs.mkdirSync(path.join(folder, 'Objects'), { recursive: true });
    for (const file of files) {
        fs.writeFileSync(path.join(folder, file), '{}');
    }
    return folder;
}

test('findRepositoryUpwards finds navgit.json from a file deep inside the repository', () => {
    const repo = makeRepo('a');
    const file = path.join(repo, 'Objects', 'TAB18.TXT');
    fs.writeFileSync(file, 'OBJECT Table 18 Customer');
    assert.strictEqual(findRepositoryUpwards(file), repo);
});

test('findRepositoryUpwards returns undefined outside a repository', () => {
    const folder = path.join(root, 'plain');
    fs.mkdirSync(folder, { recursive: true });
    assert.strictEqual(findRepositoryUpwards(folder), undefined);
});

test('findRepositories prefers the repository of the active file', () => {
    const one = makeRepo('one');
    const two = makeRepo('two');
    assert.deepStrictEqual(findRepositories(path.join(two, 'Objects'), [one, two]), [two]);
});

test('findRepositories falls back to the workspace folders without duplicates', () => {
    const one = makeRepo('w1');
    const two = makeRepo('w2');
    assert.deepStrictEqual(findRepositories(undefined, [one, path.join(one, 'Objects'), two]), [one, two]);
});

test('findAdvaniaGitRepositories lists folders with setup.json but no navgit.json', () => {
    const advania = makeRepo('adv', ['setup.json']);
    const migrated = makeRepo('migrated', ['setup.json', 'navgit.json']);
    assert.deepStrictEqual(findAdvaniaGitRepositories([advania, migrated]), [advania]);
});
