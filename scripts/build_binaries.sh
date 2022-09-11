#!/bin/sh
set -e
set -o pipefail

echo "\n➕ Get version number from last tag on GitHub\n"
VERSION=$(scripts/version.sh)

mkdir -p dist/arm64
mkdir -p dist/x86_64

echo "\n📦 Downloading packages according to Package.resolved\n"
swift package resolve

echo "\n🩹 Patching Switft Tools Support Core dependency to produce a static library\n"
sed -i .bak -E -e "s/^( *type: .dynamic,)$/\/\/\1/" .build/checkouts/swift-tools-support-core/Package.swift

echo "\n🏗 Building the ARM version\n"
swift build --configuration release \
            --arch arm64
cp .build/arm64-apple-macosx/release/xcodeinstall dist/arm64

echo "\n🏗 Building the x86_64 version\n"
swift build --configuration release \
            --arch x86_64
cp .build/x86_64-apple-macosx/release/xcodeinstall dist/x86_64



