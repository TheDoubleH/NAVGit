// Finds NAVGit repositories (folders with navgit.json). No VS Code dependencies (unit tested).
import * as fs from 'fs';
import * as path from 'path';

export const configFileName = 'navgit.json';

/** Walks up from a file or folder and returns the folder containing navgit.json, or undefined. */
export function findRepositoryUpwards(start: string): string | undefined {
    let current = path.resolve(start);
    if (fs.existsSync(current) && fs.statSync(current).isFile()) {
        current = path.dirname(current);
    }
    while (true) {
        if (fs.existsSync(path.join(current, configFileName))) {
            return current;
        }
        const parent = path.dirname(current);
        if (parent === current) {
            return undefined;
        }
        current = parent;
    }
}

/**
 * Candidate repositories: the one containing the active file wins; otherwise every workspace folder that is (or is
 * inside) a repository. Duplicates are removed, order is kept.
 */
export function findRepositories(activeFile: string | undefined, workspaceFolders: readonly string[]): string[] {
    if (activeFile) {
        const fromActive = findRepositoryUpwards(activeFile);
        if (fromActive) {
            return [fromActive];
        }
    }
    const result: string[] = [];
    for (const folder of workspaceFolders) {
        const repository = findRepositoryUpwards(folder);
        if (repository && !result.some((existing) => samePath(existing, repository))) {
            result.push(repository);
        }
    }
    return result;
}

/** Workspace folders that have an AdvaniaGIT setup.json but no navgit.json yet. */
export function findAdvaniaGitRepositories(workspaceFolders: readonly string[]): string[] {
    return workspaceFolders.filter(
        (folder) => fs.existsSync(path.join(folder, 'setup.json')) && !fs.existsSync(path.join(folder, configFileName)),
    );
}

function samePath(a: string, b: string): boolean {
    return path.resolve(a).toLowerCase() === path.resolve(b).toLowerCase();
}
