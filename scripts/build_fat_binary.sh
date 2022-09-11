#!/bin/sh
set -e
set -o pipefail

echo "\n➕ Get version number \n"
if [ ! -f VERSION ]; then 
    echo "VERSION file does not exist."
    echo "It is created by 'scripts/release_sources.sh"
    exit -1
fi
VERSION=$(cat VERSION)

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



