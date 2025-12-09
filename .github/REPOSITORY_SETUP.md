# GitHub Repository Setup Guide

This document contains instructions for setting up the DX.TOML repository on GitHub after the initial push.

## Repository Topics

Add the following topics to the repository for better discoverability:

### Primary Topics
- `delphi`
- `toml`
- `parser`
- `config`
- `configuration`

### Technology Topics
- `delphi-library`
- `toml-parser`
- `toml-v1`
- `embarcadero`
- `pascal`

### Feature Topics
- `serialization`
- `deserialization`
- `config-parser`
- `configuration-management`
- `file-parser`

### Quality Topics
- `spec-compliant`
- `tested`
- `single-file`
- `no-dependencies`

## How to Add Topics

1. Go to your repository on GitHub
2. Click on the ⚙️ (gear) icon next to "About" in the top-right section
3. In the "Topics" field, add the topics listed above (separated by spaces or commas)
4. Click "Save changes"

## GitHub Discussions

Enable GitHub Discussions for community questions and support:

1. Go to your repository on GitHub
2. Click on "Settings" tab
3. Scroll down to "Features" section
4. Check the box next to "Discussions"
5. Click "Set up discussions"
6. Use the default welcome post or customize it

### Recommended Discussion Categories

The repository includes discussion templates for:
- **General** - General discussions about DX.TOML
- **Ideas** - Feature requests and enhancement ideas
- **Help** - Q&A and troubleshooting

You can add more categories in Settings → Discussions → Categories:
- **Show and Tell** - Share projects using DX.TOML
- **Announcements** - Project updates and releases

## Social Preview Image

Upload the social preview image (`social-preview.png` or `social-preview.svg`):

1. Go to your repository on GitHub
2. Click on "Settings" tab
3. Scroll down to "Social preview"
4. Click "Upload an image"
5. Upload the `social-preview.png` file (1280x640px recommended)
6. Click "Save"

The social preview image is used when sharing the repository link on social media, messaging apps, and websites.

## Repository Description

Set a clear, concise description:

```
TOML 1.0.0 parser for Delphi - 100% spec compliant, single-file library with no dependencies
```

## Repository Website

Set the repository website to the TOML specification:

```
https://toml.io
```

Or to your documentation site if you have one.

## License

The repository is already configured with MIT License. No action needed.

## Branch Protection (Optional)

For collaborative development, consider setting up branch protection rules:

1. Go to Settings → Branches
2. Add rule for `main` branch
3. Enable:
   - Require pull request reviews before merging
   - Require status checks to pass before merging
   - Require conversation resolution before merging

## GitHub Actions (Future Enhancement)

The repository is ready for CI/CD integration with GitHub Actions. A workflow file can be added later for:
- Automated builds on push/PR
- Running DUnitX tests
- Running toml-test suite
- Creating release artifacts

This requires a GitHub-hosted Windows runner or self-hosted runner with Delphi installed.
