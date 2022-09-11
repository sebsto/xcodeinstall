#!/bin/sh -e
#
# script/bootstrap.sh
#
# Installs development dependencies and builds project dependencies.
#

main() {
  scripts/clean.sh

  echo "==> 👢 Bootstrapping"

  # When not installed, install Swift Lint
  if [[ ! -x "$(command -v swiftlint)" ]]; then
    brew install swiftlint
  fi

  # When not installed, install GitHub command line 
  if [[ ! -x "$(command -v gh)" ]]; then
    brew install gh
  fi
}

main