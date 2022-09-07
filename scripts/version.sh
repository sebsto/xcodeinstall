#!/bin/sh -e
#
# script/version
#
# Displays the current marketing version of mas.
#

# This no longer works with MARKETING_VERSION build setting in Info.plist
# agvtool what-marketing-version -terse1

VERSION=$(git describe --abbrev=0 --tags)
VERSION=${VERSION#v}

SCRIPT_PATH=$(dirname "$(which "$0")")

cat <<EOF >"${SCRIPT_PATH}/../Sources/xcodeinstall/Version.swift"
// Generated by: scripts/version
enum Version {
    static let version = "${VERSION}"
}
EOF

echo "${VERSION}"