#!/bin/sh -e -x
#
# Generate code level version file
#

if [ ! -f VERSION ]; then 
    echo "VERSION file does not exist."
    echo "It is created by 'scripts/release_sources.sh"
    exit -1
fi

VERSION=$(cat VERSION)
SCRIPT_PATH=$(dirname "$(which "$0")")
SOURCE_FILE="${SCRIPT_PATH}/../Sources/xcodeinstall/Version.swift"

cat <<EOF >"$SOURCE_FILE"
// Generated by: scripts/version
enum Version {
    static let version = "${VERSION}"
}
EOF

git add "$SOURCE_FILE" VERSION #> /dev/null 2>&1
git commit --quiet -m "Bump source to version $VERSION" "$SOURCE_FILE" VERSION #> /dev/null 2>&1
git push --quiet > /dev/null 2>&1