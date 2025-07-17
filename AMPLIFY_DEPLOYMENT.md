# Amazon Amplify Deployment Guide for CaptainVFR

This guide explains how to deploy the CaptainVFR website and web application using Amazon Amplify.

## Project Structure

- **Hugo Static Site**: The main website built with Hugo (in `/hugo` directory)
- **Flutter Web App**: The CaptainVFR web application (in root directory) accessible at `/app/`

## URLs

- Main website: `https://www.captainvfr.com/`
- Web application: `https://www.captainvfr.com/app/`

## Build Configuration

The project includes a single `amplify.yml` in the root directory which:

1. Installs Hugo Extended (v0.146.5)
2. Installs Flutter SDK
3. Builds the Flutter web app with base href `/app/`
4. Builds the Hugo static site
5. Copies the Flutter web app to `hugo/public/app/`
6. Serves everything from `hugo/public/`

## Setup Instructions

### 1. Create Amplify App

1. Go to AWS Amplify Console
2. Click "Host web app"
3. Connect your Git repository
4. Select the branch to deploy

### 2. Configure Build Settings

The `amplify.yml` file in the root directory is automatically detected by AWS Amplify. No additional configuration is needed.

If you need to modify build settings in the Amplify Console:
1. Go to "App settings" > "Build settings"
2. The build specification will show the content from `amplify.yml`

### 3. Environment Variables

Add these environment variables in Amplify Console if needed:

```
HUGO_ENV=production
```

### 4. Domain Configuration

1. Go to "App settings" > "Domain management"
2. Add custom domain: `www.captainvfr.com`
3. Configure SSL certificate
4. Add redirect from `captainvfr.com` to `www.captainvfr.com`

### 5. Rewrites and Redirects

Add these rules in Amplify Console under "Rewrites and redirects":

```
Source: /app/<*>
Target: /app/<*>
Type: 200 (Rewrite)

Source: /app
Target: /app/
Type: 301 (Redirect)
```

## Build Commands

### Local Development

```bash
# Hugo site only
cd hugo
npm run dev

# Build for production
cd hugo
npm run build
```

### Production Build

The Amplify build process runs:

1. `flutter build web --release --base-href=/app/` - Builds Flutter web app
2. `npm run build` - Builds Hugo site with minification

## Troubleshooting

### Homepage Not Found

If you get a "Page not found" error at the root:

1. Ensure `defaultContentLanguageInSubdir = false` in `hugo/config/_default/hugo.toml`
2. Check that English content is in `content/en/` directory
3. Verify the build generates files in `public/` root

### Flutter App Not Loading

1. Ensure Flutter build uses `--base-href=/app/`
2. Check that Flutter build output is copied to `hugo/public/app/`
3. Verify rewrite rules in Amplify Console

### Build Failures

1. Check Hugo version matches: v0.146.5 extended
2. Ensure all npm dependencies are in `package.json`
3. Check Flutter SDK version compatibility

## Monitoring

- Check Amplify Console for build logs
- Monitor CloudWatch for runtime errors
- Use Amplify Analytics for usage tracking