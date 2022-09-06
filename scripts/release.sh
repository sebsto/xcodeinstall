#! /bin/sh
set -e
set -o pipefail

VERSION="0.2"

swift build -c release 

cp .build/arm64-apple-macosx/release/xcodeinstall dist/
cp .build/arm64-apple-macosx/release/libSwiftToolsSupport.dylib dist/

git add dist/*
git commit -m "release binaries $VERSION"
git tag -a "v"$VERSION -m "Version $VERSION"
git push origin "v"$VERSION

wget https://github.com/sebsto/xcodeinstall/archive/refs/tags/v$VERSION.tar.gz
shasum -a 256 v$VERSION.tar.gz
rm v$VERSION.tar.gz

# TODO : update brew Formula 

