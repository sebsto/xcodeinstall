#!/bin/bash
#
# End-to-end test for xcodeinstall
# Tests: authenticate → list → download (no install)
#
# Usage: ./scripts/e2e-test.sh
#
# Prerequisites:
#   - AWS credentials configured for profile "pro-login"
#   - Apple Developer account credentials stored in AWS Secrets Manager (eu-central-1)
#   - swift build must have been run first (or use swift run which builds automatically)
#

set -euo pipefail

AWS_OPTS="-s eu-central-1 --profile pro-login"
XCODEINSTALL="swift run xcodeinstall"
XCODEINSTALL_DIR="$HOME/.xcodeinstall"
FILE_TO_DOWNLOAD="Command Line Tools for Xcode 26.3 Release Candidate.dmg" 

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

step() {
    echo ""
    echo -e "${YELLOW}=== $1 ===${NC}"
    echo ""
}

pass() {
    echo -e "${GREEN}✓ $1${NC}"
}

fail() {
    echo -e "${RED}✗ $1${NC}"
    exit 1
}

# ------------------------------------------------------------------
step "Step 0: Build"
swift build || fail "Build failed"
pass "Build succeeded"

# ------------------------------------------------------------------
step "Step 1: Clean state — delete $XCODEINSTALL_DIR"

if [ -d "$XCODEINSTALL_DIR" ]; then
    rm -rf "$XCODEINSTALL_DIR"
    pass "Deleted $XCODEINSTALL_DIR"
else
    pass "$XCODEINSTALL_DIR did not exist (already clean)"
fi

# ------------------------------------------------------------------
step "Step 2: Authenticate"

$XCODEINSTALL authenticate $AWS_OPTS || fail "authenticate failed"
pass "authenticate succeeded (session stored in AWS Secrets Manager)"

# ------------------------------------------------------------------
step "Step 3: List"

$XCODEINSTALL list $AWS_OPTS -o -m || fail "list failed"
pass "list succeeded"

# ------------------------------------------------------------------
step "Step 4: Download"

$XCODEINSTALL download $AWS_OPTS -n "$FILE_TO_DOWNLOAD" || fail "download failed"
pass "download succeeded"

# ------------------------------------------------------------------
step "Done"
echo ""
pass "All e2e steps completed successfully"
echo ""
echo "Downloaded files:"
ls -lh "$XCODEINSTALL_DIR/download/" 2>/dev/null || echo "(no downloads directory)"
