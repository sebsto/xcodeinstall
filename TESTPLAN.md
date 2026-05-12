# Manual Test Plan: Multi-Version Xcode Management

## Prerequisites

- macOS with at least one Xcode XIP file downloaded (or use `xcodeinstall download` to get one)
- Sufficient disk space (~16 GiB per Xcode version)
- `sudo` access (required for `xcode-select` and package installs)

## Setup

Run all commands from the worktree directory:

```bash
cd /Users/sst/code/swift/mac/xcodeinstall/.claude/worktrees/feature+multi-xcode-versions
swift build
```

Run the binary with:
```bash
swift run xcodeinstall <command>
```

Or use the built binary directly:
```bash
.build/debug/xcodeinstall <command>
```

---

## Test 1: Install with auto-detected version

**Goal:** Verify that installing a XIP auto-extracts the version and creates a versioned app + symlink.

```bash
xcodeinstall install --name "Xcode_16.2.xip"
```

**Expected:**
1. XIP expands (takes a while)
2. App moves to `/Applications/Xcode-16.2.app`
3. PKG packages install (prompts for sudo password)
4. Symlink created: `/Applications/Xcode.app -> Xcode-16.2.app`
5. `xcode-select -s` runs (may prompt for sudo again)
6. Success message: "Xcode 16.2 installed and activated"

**Verify:**
```bash
ls -la /Applications/Xcode.app
# Should show: Xcode.app -> Xcode-16.2.app

xcode-select -p
# Should show: /Applications/Xcode-16.2.app/Contents/Developer
```

---

## Test 2: Install a second version

**Goal:** Verify installing another version alongside the first works and updates the symlink.

```bash
xcodeinstall install --name "Xcode_16.1.xip"
```

**Expected:**
1. Installs as `/Applications/Xcode-16.1.app`
2. Symlink updates: `/Applications/Xcode.app -> Xcode-16.1.app`
3. Previous `/Applications/Xcode-16.2.app` still exists untouched

**Verify:**
```bash
ls -la /Applications/Xcode*.app
# Should show both Xcode-16.1.app and Xcode-16.2.app, plus the symlink
```

---

## Test 3: Install with explicit --xcode-version override

**Goal:** Verify the `--xcode-version` flag overrides auto-detection.

```bash
xcodeinstall install --name "Xcode_16.2.xip" --xcode-version "16.2-custom"
```

**Expected:**
- App installs as `/Applications/Xcode-16.2-custom.app`
- Symlink points to `Xcode-16.2-custom.app`

---

## Test 4: Install with beta filename

**Goal:** Verify beta naming is handled correctly.

```bash
xcodeinstall install --name "Xcode 16 beta 3.xip"
```

**Expected:**
- Installs as `/Applications/Xcode-16-beta-3.app`
- Spaces/underscores normalized to hyphens

---

## Test 5: Switch command — list versions

**Goal:** Verify `switch` without arguments shows installed versions interactively.

```bash
xcodeinstall switch
```

**Expected:**
```
Installed Xcode versions:

[00] 16.1
[01] 16.2
2 versions
Which version do you want to activate?
```

Type a number or press Enter to cancel.

---

## Test 6: Switch to a specific version

**Goal:** Verify direct switching works.

```bash
xcodeinstall switch 16.2
```

**Expected:**
- Symlink updates: `/Applications/Xcode.app -> Xcode-16.2.app`
- `xcode-select -s /Applications/Xcode-16.2.app` runs
- Message: "Switched to Xcode 16.2"

**Verify:**
```bash
ls -la /Applications/Xcode.app
xcode-select -p
```

---

## Test 7: Switch to non-existent version

**Goal:** Verify error handling for missing version.

```bash
xcodeinstall switch 99.0
```

**Expected:**
- Error message: "Xcode 99.0 is not installed in /Applications"
- Exit code: failure

---

## Test 8: Existing non-symlink Xcode.app blocks install

**Goal:** Verify that a real `/Applications/Xcode.app` directory (not a symlink) prevents silent overwrite.

**Setup:** If you have a versioned symlink in place, temporarily replace it:
```bash
sudo rm /Applications/Xcode.app
sudo mkdir /Applications/Xcode.app  # fake real directory
```

**Run:**
```bash
xcodeinstall install --name "Xcode_16.2.xip"
```

**Expected:**
- Error: "/Applications/Xcode.app exists and is not a symlink. Please rename or remove it before installing a versioned Xcode."
- No files overwritten

**Cleanup:**
```bash
sudo rm -rf /Applications/Xcode.app
# Restore your symlink if needed:
sudo ln -s Xcode-16.2.app /Applications/Xcode.app
```

---

## Test 9: Interactive version prompt (unrecognized filename)

**Goal:** Verify the tool prompts for version when it can't parse the filename.

**Setup:** Rename a XIP to something unparseable:
```bash
cp ~/.xcodeinstall/download/Xcode_16.2.xip ~/.xcodeinstall/download/MyXcode.xip
```

**Run:**
```bash
xcodeinstall install --name "MyXcode.xip"
```

**Expected:**
- Warning: "Could not determine Xcode version from filename 'MyXcode.xip'."
- Prompt: "Please enter the version (e.g., 16.2): "
- After entering "16.2": installs as `/Applications/Xcode-16.2.app`

**Cleanup:**
```bash
rm ~/.xcodeinstall/download/MyXcode.xip
```

---

## Test 10: Interactive install (no --name)

**Goal:** Verify interactive file selection still works.

```bash
xcodeinstall install
```

**Expected:**
- Lists downloaded files
- Prompts for selection
- After selection, proceeds with versioned install

---

## Test 11: Command Line Tools install (unchanged behavior)

**Goal:** Verify DMG installs are unaffected by the version logic.

```bash
xcodeinstall install --name "Command Line Tools for Xcode 16.dmg"
```

**Expected:**
- Mounts DMG, installs PKG, unmounts — same as before
- No versioned rename or symlink (only applies to Xcode XIP)

---

## Quick Verification Checklist

| # | Test | Pass? |
|---|------|-------|
| 1 | Auto-detected version install | |
| 2 | Second version alongside first | |
| 3 | Explicit --xcode-version override | |
| 4 | Beta filename normalization | |
| 5 | Switch lists versions interactively | |
| 6 | Switch to specific version | |
| 7 | Switch to non-existent version errors | |
| 8 | Real Xcode.app blocks symlink | |
| 9 | Prompt on unrecognized filename | |
| 10 | Interactive install (no --name) | |
| 11 | Command Line Tools unaffected | |
