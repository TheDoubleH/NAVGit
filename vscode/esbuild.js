// Bundles the extension into dist/extension.js. Usage: node esbuild.js [--production] [--watch]
const esbuild = require('esbuild');

const production = process.argv.includes('--production');
const watch = process.argv.includes('--watch');

async function main() {
    const context = await esbuild.context({
        entryPoints: ['src/extension.ts'],
        bundle: true,
        format: 'cjs',
        platform: 'node',
        target: 'node18',
        outfile: 'dist/extension.js',
        external: ['vscode'],
        sourcemap: !production,
        minify: production,
        logLevel: 'info',
    });
    if (watch) {
        await context.watch();
    } else {
        await context.rebuild();
        await context.dispose();
    }
}

main().catch((error) => {
    console.error(error);
    process.exit(1);
});
