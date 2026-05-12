# Test Plan: Pre-flight Sudoers Check (#22)

## Prerequisites

- Have a valid authenticated session (run `xcodeinstall authenticate` first)
- Have an Xcode or CLT download available to install

## Build

```bash
cd /path/to/xcodeinstall
swift build
```

Run all test commands using:

```bash
.build/debug/xcodeinstall install
```

## Test Cases

### Test 1: Warning shown when no NOPASSWD rule exists

```bash
# Clear any cached sudo credentials
sudo -k

# Remove your sudoers file if it exists
sudo rm -f /etc/sudoers.d/$(whoami)

# Run install — should show the warning BEFORE starting installation
xcodeinstall install
```

**Expected:** A warning message appears mentioning:
- "Passwordless sudo is not configured"
- Instructions to create `/etc/sudoers.d/<your_username>`
- The suggested `NOPASSWD: /usr/sbin/installer, /usr/bin/hdiutil` rule

Installation should still proceed (prompting for password when it hits `sudo`).

---

### Test 2: No warning when NOPASSWD rule is configured

```bash
# Create the sudoers file with restricted permissions
sudo sh -c 'echo "$(whoami) ALL=(ALL) NOPASSWD: /usr/sbin/installer, /usr/bin/hdiutil" > /etc/sudoers.d/$(whoami)'

# Clear cached credentials to ensure we're testing the rule, not the cache
sudo -k

# Run install — should NOT show any warning
xcodeinstall install
```

**Expected:** No warning message. Installation proceeds directly without prompting for a password.

---

### Test 3: No warning when sudo credentials are cached

```bash
# Remove the sudoers file
sudo rm -f /etc/sudoers.d/$(whoami)

# Prime the sudo cache by running any sudo command (enter password)
sudo true

# Run install immediately (within 5 minutes)
xcodeinstall install
```

**Expected:** No warning message (cached credentials make `sudo -n true` succeed).

---

### Test 4: Warning does not abort installation

```bash
sudo -k
sudo rm -f /etc/sudoers.d/$(whoami)

xcodeinstall install
```

**Expected:** Warning is displayed, but the install command continues. When it reaches the `sudo /usr/sbin/installer` step, it prompts for your password interactively. If you enter the correct password, installation completes successfully.

---

## Cleanup

```bash
# If you want to keep passwordless sudo for xcodeinstall:
sudo sh -c 'echo "$(whoami) ALL=(ALL) NOPASSWD: /usr/sbin/installer, /usr/bin/hdiutil" > /etc/sudoers.d/$(whoami)'

# Or remove it entirely:
sudo rm -f /etc/sudoers.d/$(whoami)
```
