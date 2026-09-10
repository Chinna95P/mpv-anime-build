# Git and Release Workflow

## Overview
This document covers Git safety rules, version management, and release synchronization procedures for MPV Anime Build.

---

## 🚨 Critical Git Rules

### Never Auto-Commit or Auto-Push
**Claude/AI agents must NEVER commit or push automatically.**

The user tests changes locally first and explicitly requests Git operations.

```bash
# ✅ CORRECT: Show changes and wait for instruction
git status
git diff

# ❌ WRONG: Never do this automatically
git commit -m "..."
git push
```

### Never Modify Git History Without Permission
- Never `git reset`
- Never `git rebase`
- Never `git checkout` (except when explicitly told)
- Never `git merge` automatically
- Never discard uncommitted changes

### Always Inspect Before Modifications
```bash
# Before significant changes
cd /path/to/mpv-anime-build
git status
git diff
```

### Always Show Changes After Modifications
```bash
# After making changes
git status
git diff
# Summarize changed files for the user
```

---

## 📌 Version Management

### Authoritative Version Source
**`script-opts/build_info.conf` is the ONLY source of truth for the application version.**

```conf
# script-opts/build_info.conf
version=v5.2
```

### ❌ Do NOT Use Git Describe
Never infer the version from `git describe` output. Historical version references in changelogs and comments are not active version sources.

### Version Reading
```lua
-- Correct way to read version in Lua scripts
local config = { version = "v0.0.0" }
opts.read_options(config, "build_info")
local BUILD_VERSION = config.version
```

---

## 🔄 Release Synchronization

When performing a version update or release, keep these files synchronized:

### Files to Update
1. **`script-opts/build_info.conf`** — Primary version source
2. **`README.md`** — Version badge and "What's New" section
3. **`CHANGELOG.md`** — New version entry with date
4. **`index.html`** — Website version display
5. **GitHub Release metadata** — Tag and release notes

### Release Checklist
```bash
# 1. Update version in build_info.conf
# 2. Update README.md header and changelog summary
# 3. Add new CHANGELOG.md entry
# 4. Update index.html version display
# 5. Test locally
# 6. Show git diff to user
# 7. Wait for explicit commit instruction
# 8. After commit, wait for explicit push instruction
# 9. Create GitHub release (if instructed)
```

---

## 🌿 Branch Strategy

### Current Branch
The user is currently on: `test/live-action-thumbfast-ytdl-fixes`

### Default Branch
Check the default branch before assuming:
```bash
git remote show origin | grep "HEAD branch"
```

---

## 📝 Commit Message Format

### Standard Commits
Use clear, descriptive commit messages:
```
Fix live-action detection override in anime_profile_controller

- Reconnect is_live_action() to main profile evaluation
- Ensure explicit live-action signals take priority over anime folder
- Add validation for 1920x1080 test case
```

### Co-Authorship
End commits with:
```
Co-Authored-By: Claude Code <noreply@anthropic.com>
```

---

## 🔍 Pre-Modification Checks

### Before Making Changes
1. **Check working tree status**
   ```bash
   git status
   ```

2. **Understand current state**
   - Are there uncommitted changes?
   - Which branch is active?
   - Are there untracked files?

3. **Read relevant files first**
   - Don't assume file contents
   - Check for customizations
   - Understand dependencies

---

## ✅ Post-Modification Protocol

### After Making Changes
1. **Show git diff**
   ```bash
   git diff
   ```

2. **Summarize changes**
   - List modified files
   - Describe what changed
   - Highlight potential impacts

3. **Wait for user instruction**
   - User will test locally
   - User will request commit when ready
   - User will request push when ready

---

## 🛡️ Safety Principles

### Minimal Changes
- Prefer targeted changes over broad rewrites
- Don't make unrelated cleanup during feature work
- One logical change per commit (when instructed)

### Preserve Functionality
- Don't remove features without explicit request
- Preserve existing filenames and structure
- Maintain backward compatibility when possible

### Test Before Commit
The user prefers to:
1. Test changes locally with MPV
2. Verify UOSC UI behavior
3. Check Lua syntax
4. Test at relevant resolutions
5. Only then commit

---

## 📚 Related Documentation
- [Architecture Overview](01-architecture-overview.md) — Script lifecycle and event flow
- [UOSC Custom UI](04-uosc-custom-ui.md) — UI testing guidelines
- [Configuration Hierarchy](14-configuration-hierarchy.md) — Config file precedence

---

## 🎯 Quick Reference

| Action | Permission Required |
|--------|-------------------|
| Read files | ✅ No |
| Edit files | ✅ No (for assigned tasks) |
| Show git diff | ✅ No |
| git commit | ❌ YES - Explicit instruction required |
| git push | ❌ YES - Explicit instruction required |
| git reset/rebase | ❌ YES - Explicit instruction required |

**Remember: When in doubt, show the diff and ask.**
