# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is Kaj Kowalski's GitHub profile repository, containing profile visualization, GitHub workflow automation, and browser extension scripts.

## Architecture & Structure

### Key Components

1. **GitHub Metrics System**
   - Automated metrics generation via GitHub Actions (`.github/workflows/metrics.yml`)
   - Runs every 8 hours to update profile visualizations
   - Generates three focused SVG metrics:
     - `assets/images/readme/metrics-profile.svg` - Profile overview and languages
     - `assets/images/readme/metrics-contributions.svg` - Development activity
     - `assets/images/readme/metrics-community.svg` - Social engagement and stars
   - Uses lowlighter/metrics with plugins organized by category
   - Three parallel jobs for efficient generation

2. **Automation Scripts**
   - **Tampermonkey Script** (`scripts/tampermonkey/github-saved-replies.js`)
     - Auto-imports GitHub saved replies from JSON configuration
     - Source: `.github/saved-replies.json` (contains template replies for GitHub issues/PRs)
     - Progressive import with localStorage tracking

3. **CI/CD Workflows**
   - **Metrics Workflow**: Profile visualization updates
   - **Autofix Workflow**: Automated code formatting with Prettier and Ruff (Python)

## Development Commands

Since this is primarily a GitHub profile repository without a traditional build system:

### Code Quality
```bash
# Format JavaScript/JSON files
npx prettier . "!**/.github/**" --write

# For Python files (if any)
uvx ruff check --fix-only . --exclude .github
uvx ruff format . --exclude .github
```

### Git Workflow
```bash
# The repository auto-commits metrics updates with "[Skip GitHub Action]" to prevent loops
# Manual commits trigger both workflows
```

## Working with Components

### Modifying Metrics
- Edit `.github/workflows/metrics.yml` to change plugins or schedule
- Token `METRICS_TOKEN` requires repo and user read permissions
- Changes to master/main branch auto-trigger metrics regeneration

### GitHub Saved Replies
- Template replies are in `.github/saved-replies.json`
- The Tampermonkey script auto-fetches from the raw GitHub URL
- Script handles progressive import with page reload between items

### Adding New Automation
- Place browser scripts in `scripts/tampermonkey/`
- GitHub Actions go in `.github/workflows/`
- Keep automation focused on GitHub profile/workflow improvements

## Important Context

- The repository is public and serves as the GitHub profile
- Metrics workflow has concurrency limits to prevent overlap
- Autofix workflow runs on all PRs and pushes to main branches
- The Tampermonkey script is designed for personal GitHub settings automation