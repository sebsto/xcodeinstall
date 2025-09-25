#!/bin/sh -e 
#
#
# Builds bottles of xcodeinstall Homebrew formula for custom tap:
# https://github.com/sebsto/homebrew-macos
#

################################################################################
#
# Variables
#

echo "\n➕ Get version number \n"
if [ ! -f VERSION ]; then 
    echo "VERSION file does not exist."
    echo "It is created by 'scripts/deploy/release_sources.sh"
    exit -1
fi
VERSION=$(cat VERSION)
TAG=v$VERSION
echo "🍼 Bottling version $VERSION"

BOTTLE_DIR="$PWD/dist/bottle"
ROOT_URL="https://github.com/sebsto/xcodeinstall/releases/download/${TAG}"

if [ ! -f VERSION ]; then 
    echo "VERSION file does not exist."
    echo "It is created by 'scripts/deploy/release_sources.sh"
    exit -1
fi
VERSION=$(cat VERSION)

# Supports macOS 13 (Ventura) and later
OS_NAMES=(arm64_ventura arm64_sonoma arm64_sequoia ventura sonoma sequoia)

# Semantic version number split into a list using  Ugly, bash 3 compatible syntax
IFS=" " read -r -a CURRENT_OS_VERSION <<<"$(sw_vers -productVersion | sed 's/\./ /g')"
CURRENT_OS_VERSION_MAJOR=${CURRENT_OS_VERSION[0]}
CURRENT_OS_VERSION_MINOR=${CURRENT_OS_VERSION[1]}

echo "CURRENT_OS_VERSION_MAJOR: $CURRENT_OS_VERSION_MAJOR"
echo "CURRENT_OS_VERSION_MINOR: $CURRENT_OS_VERSION_MINOR"

if [[ ${CURRENT_OS_VERSION_MAJOR} == "13" ]]; then
  if [[ "x86_64" == "$(uname -m)" ]]; then
    CURRENT_PLATFORM=ventura
  else
    CURRENT_PLATFORM=arm64_ventura
  fi
elif [[ ${CURRENT_OS_VERSION_MAJOR} == "14" ]]; then
  if [[ "x86_64" == "$(uname -m)" ]]; then
    CURRENT_PLATFORM=sonoma
  else
    CURRENT_PLATFORM=arm64_sonoma
  fi
elif [[ ${CURRENT_OS_VERSION_MAJOR} == "15" ]]; then
  if [[ "x86_64" == "$(uname -m)" ]]; then
    CURRENT_PLATFORM=sequoia
  else
    CURRENT_PLATFORM=arm64_sequoia
  fi
elif [[ ${CURRENT_OS_VERSION_MAJOR} == "26" ]]; then
  if [[ "x86_64" == "$(uname -m)" ]]; then
    CURRENT_PLATFORM=tahoe
  else
    CURRENT_PLATFORM=arm64_tahoe
  fi
else
  echo "Unsupported macOS version. This script requires Monterey or better."
  exit -1
fi

echo "CURRENT_PLATFORM: ${CURRENT_PLATFORM}"

################################################################################
#
# Preflight checks
#

echo "🍼 Uninstall formula and it's tap. Then reinstalling and audit it"

# Uninstall if necessary
brew remove xcodeinstall 2>/dev/null || true # ignore failure
brew untap sebsto/macos  2>/dev/null || true #ignore failure

# Uninstall if still found on path
# if command -v xcodeinstall >/dev/null; then
#   script/uninstall || true # ignore failure
# fi

# Use formula from custom tap
brew tap sebsto/macos
# brew update

# Audit formula
brew audit --strict sebsto/macos/xcodeinstall
brew style sebsto/macos/xcodeinstall

################################################################################
#
# Build the formula for the current macOS version and architecture.
#

echo "🍼 Bottling xcodeinstall ${VERSION} for: ${OS_NAMES[*]}"
brew install --build-bottle sebsto/macos/xcodeinstall

# Generate bottle do block, dropping last 2 lines
brew bottle --verbose --no-rebuild --root-url="$ROOT_URL" sebsto/macos/xcodeinstall
FILENAME="xcodeinstall--${VERSION}.${CURRENT_PLATFORM}.bottle.tar.gz"
SHA256=$(shasum --algorithm 256 "${FILENAME}" | cut -f 1 -d ' ' -)

mkdir -p "$BOTTLE_DIR"
rm -rf "$BOTTLE_DIR/*"

# Start of bottle block
BOTTLE_BLOCK=$(
  cat <<-EOF
  bottle do
    root_url "$ROOT_URL"
EOF
)

################################################################################
#
# Copy the bottle for all macOS version + architecture combinations.
#

# Fix filename
for os in "${OS_NAMES[@]}"; do
  echo "📂 Copying xcodeinstall ${VERSION} for: ${os}"
  new_filename="xcodeinstall-${VERSION}.${os}.bottle.tar.gz"
  cp -v "${FILENAME}" "${BOTTLE_DIR}/${new_filename}"

  # Append each os
  # BOTTLE_BLOCK="$(printf "${BOTTLE_BLOCK}\n  sha256 cellar: :any_skip_relocation, %-15s %s" "${os}:" "${SHA256}")"
  BOTTLE_BLOCK="$BOTTLE_BLOCK"$(
    cat <<-EOF

    sha256 cellar: :any_skip_relocation, $os: "$SHA256"
EOF
  )
done

# End of bottle block
BOTTLE_BLOCK="$BOTTLE_BLOCK"$(
  cat <<-EOF

  end
EOF
)

rm "${FILENAME}"
ls -l "${BOTTLE_DIR}"
echo "${BOTTLE_BLOCK}" > BOTTLE_BLOCK
echo "${BOTTLE_BLOCK}" 

brew remove sebsto/macos/xcodeinstall
