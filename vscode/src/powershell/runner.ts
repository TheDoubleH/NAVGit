import { execFile, spawn } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import {
    backgroundArguments,
    backgroundScript,
    elevatedScript,
    importModuleLine,
    startElevatedArguments,
} from './script';

export interface BackgroundResult {
    exitCode: number;
    stdout: string;
    stderr: string;
}

/** Runs NavGit PowerShell commands in the integrated terminal, an elevated window or a hidden background process. */
export class NavGitRunner implements vscode.Disposable {
    private terminal: vscode.Terminal | undefined;
    private elevated: Promise<boolean> | undefined;
    private readonly subscriptions: vscode.Disposable[] = [];

    constructor(
        private readonly extensionPath: string,
        private readonly output: vscode.OutputChannel,
    ) {
        this.subscriptions.push(
            vscode.window.onDidCloseTerminal((closed) => {
                if (closed === this.terminal) {
                    this.terminal = undefined;
                }
            }),
            vscode.workspace.onDidChangeConfiguration((event) => {
                if (event.affectsConfiguration('navgit')) {
                    // A new module or PowerShell path needs a fresh terminal.
                    this.terminal?.dispose();
                    this.terminal = undefined;
                }
            }),
        );
    }

    dispose(): void {
        this.terminal?.dispose();
        this.subscriptions.forEach((subscription) => subscription.dispose());
    }

    /** Path of NavGit.psd1: the navgit.modulePath setting, or the module bundled with the extension. */
    get modulePath(): string {
        const configured = vscode.workspace.getConfiguration('navgit').get<string>('modulePath', '').trim();
        if (configured) {
            return configured.toLowerCase().endsWith('.psd1') ? configured : path.join(configured, 'NavGit.psd1');
        }
        return path.join(this.extensionPath, 'resources', 'NavGit', 'NavGit.psd1');
    }

    get powershellPath(): string {
        return vscode.workspace.getConfiguration('navgit').get<string>('powershellPath', 'powershell.exe') || 'powershell.exe';
    }

    assertModule(): void {
        if (!fs.existsSync(this.modulePath)) {
            throw new Error(`The NavGit module was not found at ${this.modulePath}. Check the navgit.modulePath setting.`);
        }
    }

    /** Runs a command that needs elevation: integrated terminal when VS Code is elevated, otherwise an elevated window. */
    async runElevatedCommand(title: string, body: string): Promise<void> {
        this.assertModule();
        const mode = vscode.workspace.getConfiguration('navgit').get<string>('runMode', 'auto');
        const useTerminal = mode === 'terminal' || (mode === 'auto' && (await this.isElevated()));

        this.output.appendLine(`> ${title}: ${body}`);
        if (useTerminal) {
            const terminal = this.getTerminal();
            terminal.show(true);
            terminal.sendText(body, true);
            return;
        }

        const args = startElevatedArguments(this.powershellPath, elevatedScript(this.modulePath, title, body));
        const child = spawn(this.powershellPath, args, { windowsHide: true });
        child.on('error', (error) => {
            void vscode.window.showErrorMessage(`NavGit: could not start PowerShell (${error.message}).`);
        });
        child.on('exit', (code) => {
            if (code !== 0) {
                // Typically: the UAC prompt was declined.
                void vscode.window.showWarningMessage(`NavGit: the elevated PowerShell window for '${title}' was not started.`);
            }
        });
    }

    /** Runs a script in a hidden PowerShell process and returns its output. */
    runBackground(title: string, body: string, token?: vscode.CancellationToken): Promise<BackgroundResult> {
        this.assertModule();
        const script = backgroundScript(this.modulePath, body);
        this.output.appendLine(`> ${title}: ${body}`);

        return new Promise((resolve) => {
            const child = execFile(
                this.powershellPath,
                backgroundArguments(script),
                { windowsHide: true, maxBuffer: 16 * 1024 * 1024 },
                (error, stdout, stderr) => {
                    const exitCode = error ? (typeof error.code === 'number' ? error.code : 1) : 0;
                    if (stderr.trim()) {
                        this.output.appendLine(stderr.trim());
                    }
                    resolve({ exitCode, stdout, stderr });
                },
            );
            token?.onCancellationRequested(() => child.kill());
        });
    }

    private getTerminal(): vscode.Terminal {
        if (!this.terminal) {
            this.terminal = vscode.window.createTerminal({
                name: 'NavGit',
                shellPath: this.powershellPath,
                shellArgs: ['-NoLogo', '-NoExit', '-ExecutionPolicy', 'Bypass', '-Command', importModuleLine(this.modulePath)],
            });
        }
        return this.terminal;
    }

    /** True when VS Code (and so its integrated terminal) runs as administrator. */
    private isElevated(): Promise<boolean> {
        if (!this.elevated) {
            this.elevated = new Promise((resolve) => {
                // 'net session' only succeeds in an elevated process.
                execFile('net', ['session'], { windowsHide: true }, (error) => resolve(!error));
            });
        }
        return this.elevated;
    }
}
