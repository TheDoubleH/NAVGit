import * as vscode from 'vscode';
import { registerCommands } from './commands/register';
import { NavGitRunner } from './powershell/runner';

export function activate(context: vscode.ExtensionContext): void {
    const output = vscode.window.createOutputChannel('NavGit');
    const runner = new NavGitRunner(context.extensionPath, output);
    context.subscriptions.push(output, runner);
    registerCommands(context, runner, output);
}

export function deactivate(): void {
    // Everything is disposed through context.subscriptions.
}
