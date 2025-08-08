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

// Separate entry points for theme and app JS
const jsThemeEntryPoints = ['themes/boilerplate/assets/js/main.js'];
const jsAppEntryPoints = ['assets/js/app.js'];
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

// Build theme JavaScript (main.js)
async function buildThemeJS() {
    try {
        await esbuild.build({
            entryPoints: jsThemeEntryPoints,
            bundle: true,
            minify: true,
            sourcemap: false,
            format: 'iife',
            outdir: jsDest,
            platform: 'browser',
            target: ['es2020']
        });
    } catch (error) {
        console.error('Theme JavaScript build failed:', error);
        throw error;
    }
}

// Build app JavaScript (app.js)
async function buildAppJS() {
    try {
        await esbuild.build({
            entryPoints: jsAppEntryPoints,
            bundle: true,
            minify: true,
            sourcemap: false,
            format: 'iife',
            outdir: jsDest,
            platform: 'browser',
            target: ['es2020']
        });
    } catch (error) {
        console.error('App JavaScript build failed:', error);
        throw error;
    }
}

// Combined JavaScript build
async function buildJS() {
    await buildThemeJS();
    await buildAppJS();
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

// Watch theme JavaScript files
async function watchThemeJS() {
    const ctx = await esbuild.context({
        entryPoints: jsThemeEntryPoints,
        bundle: true,
        minify: true,
        sourcemap: false,
        format: 'iife',
        outdir: jsDest,
        platform: 'browser',
        target: ['es2020']
    });
    
    await ctx.watch();
}

// Watch app JavaScript files
async function watchAppJS() {
    const ctx = await esbuild.context({
        entryPoints: jsAppEntryPoints,
        bundle: true,
        minify: true,
        sourcemap: false,
        format: 'iife',
        outdir: jsDest,
        platform: 'browser',
        target: ['es2020']
    });
    
    await ctx.watch();
}

// Combined JavaScript watch
async function watchJS() {
    await watchThemeJS();
    await watchAppJS();
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
exports.themejs = buildThemeJS;
exports.appjs = buildAppJS;
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