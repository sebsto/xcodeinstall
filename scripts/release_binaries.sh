# echo 
# gh release create "v"$VERSION --generate-notes
# gh release upload "v"$VERSION bottle files

# git add dist/*
# git commit -m "release binaries $VERSION"
# git tag -a "v"$VERSION -m "Version $VERSION"
# git push origin "v"$VERSION

# wget https://github.com/sebsto/xcodeinstall/archive/refs/tags/v$VERSION.tar.gz
# shasum -a 256 v$VERSION.tar.gz
# rm v$VERSION.tar.gz

# TODO : update brew Formula 