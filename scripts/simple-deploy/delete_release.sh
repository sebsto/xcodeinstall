#!/bin/sh -e

VERSION="$1"
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 0.15.0"
    exit 1
fi
TAG="v$VERSION"
echo "🚀 Deleting version $VERSION"

gh release delete $TAG
git tag -d $TAG
git push --no-verify origin --delete $TAG
git reset HEAD~1