// Builds the PowerShell command lines that run NAVGit. No VS Code dependencies (unit tested).

/** Quotes a value as a PowerShell single-quoted string. */
export function quotePs(value: string): string {
    return `'${value.replace(/'/g, "''")}'`;
}

export interface InvokeOptions {
    force?: boolean;
    profileId?: string;
    asJson?: boolean;
}

/** Import-Module line for the NAVGit module. */
export function importModuleLine(modulePath: string): string {
    return `Import-Module ${quotePs(modulePath)} -DisableNameChecking -Force`;
}

/** Invoke-NAVGitCommand call for a registry command. */
export function invokeLine(psName: string, repository: string, options: InvokeOptions = {}): string {
    const parts = ['Invoke-NAVGitCommand', '-Name', psName, '-Repository', quotePs(repository)];
    if (options.force) {
        parts.push('-Force');
    }
    if (options.profileId) {
        parts.push('-ProfileId', quotePs(options.profileId));
    }
    if (options.asJson) {
        parts.push('-AsJson');
    }
    return parts.join(' ');
}

/** Script for a hidden background process: imports the module, runs the command and exits with its exit code. */
export function backgroundScript(modulePath: string, body: string): string {
    return [
        "$ErrorActionPreference = 'Stop'",
        '$ProgressPreference = \'SilentlyContinue\'',
        importModuleLine(modulePath),
        body,
        'exit $LASTEXITCODE',
    ].join('; ');
}

/** Script for a separate elevated window: sets the title, imports the module and runs the command. */
export function elevatedScript(modulePath: string, title: string, body: string): string {
    return [
        `$Host.UI.RawUI.WindowTitle = ${quotePs(`NAVGit - ${title}`)}`,
        importModuleLine(modulePath),
        body,
    ].join('; ');
}

/** -EncodedCommand value (Base64 of UTF-16LE), avoids every quoting problem when passing scripts on. */
export function encodeCommand(script: string): string {
    return Buffer.from(script, 'utf16le').toString('base64');
}

/**
 * Arguments for a non-elevated powershell.exe that starts an elevated PowerShell window (UAC prompt)
 * running the encoded script. The window stays open (-NoExit) so the output can be read.
 */
export function startElevatedArguments(powershellPath: string, script: string): string[] {
    const inner = ['-NoLogo', '-NoExit', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', encodeCommand(script)]
        .map(quotePs)
        .join(',');
    return [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        `Start-Process -FilePath ${quotePs(powershellPath)} -Verb RunAs -ArgumentList ${inner}`,
    ];
}

/** Arguments for a hidden background powershell.exe running a script. */
export function backgroundArguments(script: string): string[] {
    return ['-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', encodeCommand(script)];
}

/** Parses the JSON array written by Invoke-NAVGitCommand -AsJson (tolerates an empty output). */
export function parseJsonArray<T>(stdout: string): T[] {
    const text = stdout.trim();
    if (!text) {
        return [];
    }
    const value = JSON.parse(text);
    if (Array.isArray(value)) {
        return value.filter((item) => item !== null) as T[];
    }
    return value === null ? [] : [value as T];
}
