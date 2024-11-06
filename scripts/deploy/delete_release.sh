#!/bin/sh -e

VERSION_TO_DELETE=$(cat VERSION)
TAG=v$VERSION_TO_DELETE

gh release delete $TAG
git tag -d $TAG
git push origin --delete $TAG