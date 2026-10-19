import * as assert from 'assert';
import { test } from 'node:test';
import {
    backgroundArguments,
    backgroundScript,
    encodeCommand,
    installModuleScript,
    invokeLine,
    parseJsonArray,
    quotePs,
    startElevatedArguments,
} from '../src/powershell/script';

function decode(base64: string): string {
    return Buffer.from(base64, 'base64').toString('utf16le');
}

test('quotePs doubles single quotes', () => {
    assert.strictEqual(quotePs("C:\\Repos\\O'Brien"), "'C:\\Repos\\O''Brien'");
});

test('invokeLine builds the Invoke-NAVGitCommand call', () => {
    assert.strictEqual(
        invokeLine('BuildContainer', 'C:\\Repos\\Customer'),
        "Invoke-NAVGitCommand -Name BuildContainer -Repository 'C:\\Repos\\Customer'",
    );
    assert.strictEqual(
        invokeLine('StartClient', 'C:\\R', { profileId: "ORDER PROCESSOR's", asJson: true }),
        "Invoke-NAVGitCommand -Name StartClient -Repository 'C:\\R' -ProfileId 'ORDER PROCESSOR''s' -AsJson",
    );
    assert.strictEqual(invokeLine('RemoveContainer', 'C:\\R', { force: true }), "Invoke-NAVGitCommand -Name RemoveContainer -Repository 'C:\\R' -Force");
});

test('backgroundScript imports the module and exits with the command exit code', () => {
    const script = backgroundScript('C:\\ext\\NAVGit.psd1', 'Invoke-NAVGitCommand -Name GetProfiles');
    assert.match(script, /Import-Module 'C:\\ext\\NAVGit\.psd1' -DisableNameChecking -Force/);
    assert.match(script, /Invoke-NAVGitCommand -Name GetProfiles; exit \$LASTEXITCODE$/);
});

test('installModuleScript installs or updates for the current user without prompting', () => {
    const script = installModuleScript('NAVGit');
    assert.match(script, /Get-InstalledModule -Name 'NAVGit' -ErrorAction SilentlyContinue/);
    assert.match(script, /Install-Module -Name 'NAVGit' -Repository PSGallery -Scope CurrentUser -Force/);
    assert.match(script, /Update-Module -Name 'NAVGit' -Force/);
    assert.match(script, /Install-PackageProvider -Name NuGet/);
    assert.match(script, /ConvertTo-Json/);
    assert.doesNotMatch(script, /Import-Module/);
});

test('encodeCommand round-trips as UTF-16LE base64', () => {
    const script = "Write-Host 'æøå \"quoted\"'";
    assert.strictEqual(decode(encodeCommand(script)), script);
});

test('backgroundArguments pass the script encoded', () => {
    const args = backgroundArguments('Get-Date');
    assert.deepStrictEqual(args.slice(0, 5), ['-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass']);
    assert.strictEqual(args[5], '-EncodedCommand');
    assert.strictEqual(decode(args[6]), 'Get-Date');
});

test('startElevatedArguments start an elevated window that runs the encoded script', () => {
    const args = startElevatedArguments('powershell.exe', "Invoke-NAVGitCommand -Name BuildContainer -Repository 'C:\\R'");
    const command = args[args.length - 1];
    assert.match(command, /^Start-Process -FilePath 'powershell\.exe' -Verb RunAs -ArgumentList '-NoLogo','-NoExit','-ExecutionPolicy','Bypass','-EncodedCommand','[A-Za-z0-9+/=]+'$/);
    const encoded = /'-EncodedCommand','([A-Za-z0-9+/=]+)'/.exec(command)![1];
    assert.strictEqual(decode(encoded), "Invoke-NAVGitCommand -Name BuildContainer -Repository 'C:\\R'");
});

test('parseJsonArray handles arrays, single values, null and empty output', () => {
    assert.deepStrictEqual(parseJsonArray('[{"Id":"A"},{"Id":"B"}]'), [{ Id: 'A' }, { Id: 'B' }]);
    assert.deepStrictEqual(parseJsonArray('{"Id":"A"}'), [{ Id: 'A' }]);
    assert.deepStrictEqual(parseJsonArray('[null]'), []);
    assert.deepStrictEqual(parseJsonArray('  \r\n'), []);
});
