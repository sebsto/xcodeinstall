#!/bin/sh -e

echo "\n➕ Get version number \n"
if [ ! -f VERSION ]; then 
    echo "VERSION file does not exist."
    echo "It is created by 'scripts/deploy/release_sources.sh"
    exit -1
fi
VERSION=$(cat VERSION)
TAG=v$VERSION

echo "⬆️ Upload bottles"
gh release upload $TAG dist/bottle/*

echo "🍺 Add bottles to brew formula"
if [ ! -f ./scripts/deploy/xcodeinstall.rb ]; then 
    echo "Brew formula file does not exist. (./scripts/deploy/xcodeinstall.rb)"
    echo "It is created by 'scripts/deploy/release_sources.sh"
    exit -1
fi
if [ ! -f ./BOTTLE_BLOCK ]; then 
    echo "Bottle block file does not exist. (./BOTTLE_BLOCK)"
    echo "It is created by 'scripts/deploy/bottle.sh"
    exit -1
fi
sed -i .bak -E -e "/  # insert bottle definition here/r BOTTLE_BLOCK" ./scripts/deploy/xcodeinstall.rb
rm ./scripts/deploy/xcodeinstall.rb.bak

echo "\n🍺 Pushing new formula\n"
cp ./scripts/deploy/xcodeinstall.rb ../homebrew-macos
pushd ../homebrew-macos
git add xcodeinstall.rb 
git commit --quiet -m "update for $TAG"
git push --no-verify --quiet > /dev/null 2>&1
popd 
