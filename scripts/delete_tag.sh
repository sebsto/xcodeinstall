#!/bin/sh -e

VERSION_TO_DELETE="0.3"
TAG=v$VERSION_TO_DELETE
git tag -d $TAG
git push origin --delete $TAG