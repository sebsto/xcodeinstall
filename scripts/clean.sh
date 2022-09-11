#!/bin/sh -e
#
# script/clean
#
# Deletes the build directory.
#

echo "🧻 Cleaning build artefacts"
swift package clean
swift package reset
rm -rf dist/*