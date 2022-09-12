#!/bin/sh -x
set -e
set -o pipefail

echo "Did you update version number before running this script ?"
# exit -1 
######################
VERSION="0.5"
######################

echo $VERSION > VERSION
TAG=v$VERSION

echo "\n➕ Add new version to source code\n"
scripts/version.sh

echo "\n🏷 Tagging GitHub\n"
git tag $TAG 
git push --quiet origin $TAG

echo "\n📦 Create Source Code Release on GitHub\n"
gh auth status > /dev/null 2>&1
gh release create $TAG --generate-notes

echo "\n⬇️ Downloading the source tarball\n"
URL="https://github.com/sebsto/xcodeinstall/archive/refs/tags/$TAG.tar.gz"
wget -q $URL 

echo "\n∑ Computing SHA 256\n"
SHA256=$(shasum -a 256 $TAG.tar.gz | awk -s '{print $1}')
rm $TAG.tar.gz

echo "\n🍺 Generate brew formula\n"
# do not use / as separator as it is confused with / from the URL
sed -E -e "s+URL+url \"$URL\"+g"             \
       -e "s/SHA/sha256 \"$SHA256\"/g"       \
       scripts/xcodeinstall.template > scripts/xcodeinstall.rb

echo "\n🍺 Pushing new formula\n"
cp scripts/xcodeinstall.rb ../homebrew-macos
pushd ../homebrew-macos
git add xcodeinstall.rb 
git commit --quiet -m "update for $TAG"
git push --quiet > /dev/null 2>&1
popd 


