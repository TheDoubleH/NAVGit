// The NAVGit commands offered in VS Code. Each entry maps to a command in the PowerShell module's Commands.psd1
// (psName). To add a command: add the PowerShell function and its Commands.psd1 entry, then an entry here and in
// package.json contributes.commands.

/** terminal: long running, visible output, elevated. background: hidden process, result in the NAVGit output. */
export type RunMode = 'terminal' | 'background';

export interface NAVGitCommand {
    /** VS Code command id (package.json contributes.commands). */
    id: string;
    title: string;
    /** Name in Commands.psd1, passed to Invoke-NAVGitCommand -Name. */
    psName: string;
    mode: RunMode;
    /** Ask before running; the command then runs with -Force so PowerShell does not ask again. */
    confirm?: string;
    /** Let the user pick a profile first and pass it as -ProfileId. */
    pickProfile?: boolean;
}

export const navGitCommands: readonly NAVGitCommand[] = [
    { id: 'navgit.buildAndUpdateContainer', title: 'Build and Update Container', psName: 'BuildAndUpdate', mode: 'terminal' },
    { id: 'navgit.buildContainer', title: 'Build Container', psName: 'BuildContainer', mode: 'terminal' },
    {
        id: 'navgit.removeContainer',
        title: 'Remove Container',
        psName: 'RemoveContainer',
        mode: 'terminal',
        confirm: 'Remove the NAV container of this repository? The database in the container is deleted.',
    },
    { id: 'navgit.importTestToolkit', title: 'Import Test Toolkit', psName: 'ImportTestToolkit', mode: 'terminal' },
    { id: 'navgit.importAllObjects', title: 'Import All GIT Objects to NAV', psName: 'ImportObjects', mode: 'terminal' },
    { id: 'navgit.exportObjects', title: 'Export NAV objects to GIT', psName: 'ExportObjects', mode: 'terminal' },
    { id: 'navgit.compileUncompiled', title: 'Compile Uncompiled Objects', psName: 'CompileUncompiled', mode: 'terminal' },
    { id: 'navgit.compileModified', title: 'Compile Modified Objects', psName: 'CompileModified', mode: 'terminal' },
    {
        id: 'navgit.compileAll',
        title: 'Compile All Objects',
        psName: 'CompileAll',
        mode: 'terminal',
        confirm: 'Compile all objects in the container? This can take a long time.',
    },
    { id: 'navgit.updateAddIns', title: 'Update Add-ins', psName: 'UpdateAddIns', mode: 'terminal' },
    { id: 'navgit.startDevEnv', title: 'Start Development Environment (FinSql)', psName: 'StartDevEnv', mode: 'background' },
    { id: 'navgit.startClientDefault', title: 'Start NAV Client (default)', psName: 'StartClient', mode: 'background' },
    { id: 'navgit.startClient', title: 'Start NAV Client...', psName: 'StartClient', mode: 'background', pickProfile: true },
];

/** Commands that are handled by the extension itself instead of the registry. */
export const createConfigCommandId = 'navgit.createConfig';
export const installModuleCommandId = 'navgit.installModule';

/** Name of the module on the PowerShell Gallery. */
export const galleryModuleName = 'NAVGit';

export interface NAVGitProfile {
    Id: string;
    Description: string;
    RoleCenterId: number;
    IsDefault: boolean;
}

/** Profiles for the picker: the default role center first, then by id. */
export function sortProfiles(profiles: readonly NAVGitProfile[]): NAVGitProfile[] {
    return [...profiles].sort((a, b) => {
        if (a.IsDefault !== b.IsDefault) {
            return a.IsDefault ? -1 : 1;
        }
        return a.Id.localeCompare(b.Id);
    });
}
