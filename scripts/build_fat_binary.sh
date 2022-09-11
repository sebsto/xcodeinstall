#!/bin/sh
set -e
set -o pipefail

echo "\n➕ Get version number \n"
VERSION=$(scripts/version.sh)

mkdir -p dist/fat

echo "\n📦 Downloading packages according to Package.resolved\n"
swift package resolve

echo "\n🩹 Patching Switft Tools Support Core dependency to produce a static library\n"
sed -i .bak -E -e "s/^( *type: .dynamic,)$/\/\/\1/" .build/checkouts/swift-tools-support-core/Package.swift

echo "\n🏗 Building the fat binary (x86_64 and arm64) version\n"
swift build --configuration release \
            --arch arm64            \
            --arch x86_64
cp .build/apple/Products/Release/xcodeinstall dist/fat



