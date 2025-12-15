# GitHub Infrastructure Files

This directory contains GitHub-specific configuration and documentation files.

## Contents

### Issue Templates (ISSUE_TEMPLATE/)
- **bug_report.md** - Template for bug reports
- **feature_request.md** - Template for feature requests
- **config.yml** - Issue template configuration with links to discussions and TOML spec

### Discussion Templates (DISCUSSION_TEMPLATE/)
- **general.yml** - General discussions
- **ideas.yml** - Feature ideas and enhancements
- **help.yml** - Questions and help requests

### Repository Setup
- **REPOSITORY_SETUP.md** - Complete guide for setting up the GitHub repository
  - Repository topics/tags
  - Enabling GitHub Discussions
  - Uploading social preview image
  - Branch protection rules

### Social Preview
- **social-preview.svg** - Social preview image (vector format)

To use the social preview image on GitHub (requires PNG format):

#### Option 1: Convert with Inkscape (Free)
```bash
inkscape social-preview.svg --export-filename=social-preview.png --export-width=1280 --export-height=640
```

#### Option 2: Convert with ImageMagick
```bash
magick convert -background none -density 300 social-preview.svg -resize 1280x640 social-preview.png
```

#### Option 3: Online Converter
Use any SVG to PNG online converter (e.g., https://cloudconvert.com/svg-to-png)
- Upload social-preview.svg
- Set dimensions to 1280x640
- Download PNG

Then upload the PNG file to GitHub repository settings under "Social preview".

## Setup Instructions

After pushing the repository to GitHub, follow the instructions in [REPOSITORY_SETUP.md](REPOSITORY_SETUP.md) to:

1. Add repository topics for discoverability
2. Enable GitHub Discussions
3. Upload social preview image
4. Configure repository description and website

## Recommended Repository Topics

```
delphi toml parser config configuration delphi-library toml-parser
toml-v1 embarcadero pascal serialization deserialization config-parser
configuration-management file-parser spec-compliant tested single-file
no-dependencies
```

## Repository Description

```
TOML 1.0.0 parser for Delphi - 100% spec compliant, single-file library with no dependencies
```

## Repository Website

```
https://toml.io
```
