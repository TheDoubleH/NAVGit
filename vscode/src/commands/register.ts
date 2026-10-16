import * as path from 'path';
import * as vscode from 'vscode';
import { NAVGitRunner } from '../powershell/runner';
import { invokeLine, parseJsonArray, quotePs } from '../powershell/script';
import { configFileName, findAdvaniaGitRepositories, findRepositories } from '../workspace/findRepo';
import { createConfigCommandId, NAVGitCommand, navGitCommands, NAVGitProfile, sortProfiles } from './registry';

export function registerCommands(context: vscode.ExtensionContext, runner: NAVGitRunner, output: vscode.OutputChannel): void {
    for (const command of navGitCommands) {
        context.subscriptions.push(
            vscode.commands.registerCommand(command.id, () => runSafely(output, command.title, () => runCommand(command, runner))),
        );
    }
    context.subscriptions.push(
        vscode.commands.registerCommand(createConfigCommandId, () => runSafely(output, 'Create navgit.json', () => createConfig(runner))),
    );
}

async function runSafely(output: vscode.OutputChannel, title: string, action: () => Promise<void>): Promise<void> {
    try {
        await action();
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        output.appendLine(`${title} failed: ${message}`);
        void vscode.window.showErrorMessage(`NAVGit: ${message}`);
    }
}

async function runCommand(command: NAVGitCommand, runner: NAVGitRunner): Promise<void> {
    const repository = await pickRepository();
    if (!repository) {
        return;
    }

    let force = false;
    if (command.confirm) {
        const answer = await vscode.window.showWarningMessage(command.confirm, { modal: true, detail: repository }, command.title);
        if (answer !== command.title) {
            return;
        }
        force = true;
    }

    if (command.mode === 'terminal') {
        await runner.runElevatedCommand(command.title, invokeLine(command.psName, repository, { force }));
        return;
    }

    let profileId: string | undefined;
    if (command.pickProfile) {
        const picked = await pickProfile(runner, repository);
        if (picked === undefined) {
            return;
        }
        profileId = picked || undefined;
    }

    await runBackgroundCommand(runner, command.title, invokeLine(command.psName, repository, { profileId, asJson: true }));
}

async function runBackgroundCommand(runner: NAVGitRunner, title: string, body: string): Promise<string> {
    const result = await vscode.window.withProgress(
        { location: vscode.ProgressLocation.Window, title: `NAVGit: ${title}` },
        () => runner.runBackground(title, body),
    );
    if (result.exitCode !== 0) {
        const message = result.stderr.replace(/^NAVGit:\s*/gm, '').trim() || `${title} failed (exit code ${result.exitCode}).`;
        throw new Error(message);
    }
    return result.stdout;
}

/** Returns the profile id, '' for the default role center, or undefined when cancelled. */
async function pickProfile(runner: NAVGitRunner, repository: string): Promise<string | undefined> {
    const stdout = await runBackgroundCommand(runner, 'Reading profiles', invokeLine('GetProfiles', repository, { asJson: true }));
    const profiles = sortProfiles(parseJsonArray<NAVGitProfile>(stdout));

    type ProfileItem = vscode.QuickPickItem & { profileId: string };
    const items: ProfileItem[] = [
        { label: '$(home) Default role center', description: 'Open without a profile', profileId: '' },
        ...profiles.map((profile) => ({
            label: profile.IsDefault ? `$(star-full) ${profile.Id}` : profile.Id,
            description: profile.Description,
            detail: `Role Center ${profile.RoleCenterId}${profile.IsDefault ? ' (default)' : ''}`,
            profileId: profile.Id,
        })),
    ];
    const picked = await vscode.window.showQuickPick(items, {
        title: 'Start NAV Client',
        placeHolder: 'Select the profile to open',
        matchOnDescription: true,
    });
    return picked?.profileId;
}

/** The repository to run in: the one containing the active file, or one picked from the workspace folders. */
async function pickRepository(): Promise<string | undefined> {
    const repositories = findRepositories(activeFilePath(), workspaceFolderPaths());
    if (repositories.length === 0) {
        const create = 'Create navgit.json';
        const answer = await vscode.window.showErrorMessage(`NAVGit: no ${configFileName} found in the workspace.`, create);
        if (answer === create) {
            await vscode.commands.executeCommand(createConfigCommandId);
        }
        return undefined;
    }
    if (repositories.length === 1) {
        return repositories[0];
    }
    const picked = await vscode.window.showQuickPick(
        repositories.map((repository) => ({ label: path.basename(repository), description: repository, repository })),
        { placeHolder: 'Select the NAVGit repository' },
    );
    return picked?.repository;
}

async function createConfig(runner: NAVGitRunner): Promise<void> {
    const folders = workspaceFolderPaths();
    if (folders.length === 0) {
        throw new Error('Open the repository folder first.');
    }

    let folder = folders[0];
    if (folders.length > 1) {
        const picked = await vscode.window.showQuickPick(
            folders.map((candidate) => ({ label: path.basename(candidate), description: candidate, folder: candidate })),
            { placeHolder: `Folder for ${configFileName}` },
        );
        if (!picked) {
            return;
        }
        folder = picked.folder;
    }

    let body: string;
    if (findAdvaniaGitRepositories([folder]).length > 0) {
        const convert = 'Convert setup.json';
        const answer = await vscode.window.showInformationMessage(
            `${path.basename(folder)} has an AdvaniaGIT setup.json. Create ${configFileName} from it?`,
            { modal: true },
            convert,
            'Start empty',
        );
        if (!answer) {
            return;
        }
        body = answer === convert ? `ConvertFrom-AdvaniaGitSetup -Path ${quotePs(folder)}` : await newConfigBody(folder);
    }
    else {
        body = await newConfigBody(folder);
    }
    if (!body) {
        return;
    }

    const result = await runner.runBackground('Create navgit.json', `${body} 3>&1 6>&1 | Out-String -Width 200`);
    if (result.exitCode !== 0) {
        throw new Error(result.stderr.trim() || 'Creating navgit.json failed.');
    }
    // Remaining output lines are the migration notes (warnings); the 'Created ...navgit.json' lines are dropped.
    const notes = result.stdout
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter((line) => line && !/navgit\.json$/i.test(line));
    const document = await vscode.workspace.openTextDocument(path.join(folder, configFileName));
    await vscode.window.showTextDocument(document);
    if (notes.length > 0) {
        void vscode.window.showWarningMessage(`NAVGit: ${notes.join(' ')}`);
    }
}

async function newConfigBody(folder: string): Promise<string> {
    const release = await vscode.window.showQuickPick(
        [
            { label: 'NAV 2018', args: '-Nav 2018' },
            { label: 'NAV 2017', args: '-Nav 2017' },
            { label: 'NAV 2016', args: '-Nav 2016' },
            { label: 'Business Central 14', args: '-Version 14' },
        ],
        { placeHolder: 'Version' },
    );
    if (!release) {
        return '';
    }
    const country = await vscode.window.showInputBox({ prompt: 'Localization (country code)', value: 'w1' });
    if (country === undefined) {
        return '';
    }
    return `New-NAVGitConfig -Path ${quotePs(folder)} ${release.args} -Country ${quotePs(country || 'w1')}`;
}

function activeFilePath(): string | undefined {
    const document = vscode.window.activeTextEditor?.document;
    return document && document.uri.scheme === 'file' ? document.uri.fsPath : undefined;
}

function workspaceFolderPaths(): string[] {
    return (vscode.workspace.workspaceFolders ?? []).filter((folder) => folder.uri.scheme === 'file').map((folder) => folder.uri.fsPath);
}
