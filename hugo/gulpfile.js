const gulp = require('gulp');
const postcss = require('gulp-postcss');
const postcssImport = require('postcss-import');
const tailwindcss = require('tailwindcss');
const autoprefixer = require('autoprefixer');
const esbuild = require('esbuild');
const { spawn } = require('child_process');
const cssnano = require('cssnano');
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');

// Parse command line arguments
const argv = yargs(hideBin(process.argv))
    .option('en', {
        describe: 'Start Hugo server with English only (faster)',
        type: 'boolean'
    })
    .option('metrics', {
        describe: 'Show Hugo template metrics',
        type: 'boolean'
    })
    .help()
    .argv;

// CSS and JS source paths
const cssSrc = 'themes/boilerplate/assets/css/main.css';
const cssDest = 'static/css';
const jsEntryPoints = ['themes/boilerplate/assets/js/main.js'];
const jsDest = 'static/js';

// CSS build with @import processing
function buildCSS() {
    return gulp.src(cssSrc)
        .pipe(postcss([
            postcssImport,    // Process @import statements first
            tailwindcss,
            autoprefixer,
            cssnano()
        ]))
        .pipe(gulp.dest(cssDest));
}

// JavaScript build with ESBuild
async function buildJS() {
    try {
        await esbuild.build({
            entryPoints: jsEntryPoints,
            bundle: true,
            minify: true,
            sourcemap: false,
            format: 'iife',
            outdir: jsDest,
            platform: 'browser'
        });
    } catch (error) {
        console.error('JavaScript build failed:', error);
        throw error;
    }
}

// Watch CSS files for changes
function watchCSS() {
    return gulp.watch(
        [
            'themes/boilerplate/assets/css/**/*.css',
            'themes/boilerplate/layouts/**/*.html',
            'layouts/**/*.html',
            'content/**/*.{html,md}'
        ],
        buildCSS
    );
}

// Watch JavaScript files with ESBuild
async function watchJS() {
    const ctx = await esbuild.context({
        entryPoints: jsEntryPoints,
        bundle: true,
        minify: true,
        sourcemap: false,
        format: 'iife',
        outdir: jsDest,
        platform: 'browser'
    });
    
    await ctx.watch();
}

// Start Hugo server with configurable options
function startHugo(done) {
    const hugoArgs = ['server', '--gc', '--disableFastRender'];
    
    // Add language-specific flags if requested
    // Note: Hugo doesn't have a direct flag to disable languages in server mode
    // This would need to be handled via config
    
    // Add metrics flags if requested
    if (argv.metrics) {
        hugoArgs.push('--templateMetrics', '--templateMetricsHints');
    }
    
    const hugo = spawn('hugo', hugoArgs, { stdio: 'inherit' });
    
    hugo.on('close', (code) => {
        if (code === 0) {
            done();
        } else {
            done(new Error(`Hugo exited with code ${code}`));
        }
    });
}

// Export individual tasks
exports.css = buildCSS;
exports.js = buildJS;
exports.watch = gulp.parallel(watchCSS, watchJS);

// Default task: build assets and start Hugo server
exports.default = gulp.series(
    gulp.parallel(buildCSS, buildJS),
    startHugo
);

// Development task: build, watch, and serve
exports.dev = gulp.series(
    gulp.parallel(buildCSS, buildJS),
    gulp.parallel(startHugo, watchCSS, watchJS)
);