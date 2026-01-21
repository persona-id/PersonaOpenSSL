#!/usr/bin/env bash

# This script generates a patch to rename all <openssl/...> includes to <personaopenssl/...>
# Run this ONCE when upgrading OpenSSL versions, then commit the patch file

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
OPENSSL_VERSION="${1:-1.1.1s}"
TARBALL="${SCRIPT_DIR}/../openssl-${OPENSSL_VERSION}.tar.gz"
PATCH_FILE="${SCRIPT_DIR}/../patches/openssl-${OPENSSL_VERSION}-headers.patch"

if [ ! -f "$TARBALL" ]; then
    echo "Error: $TARBALL not found"
    echo "Usage: $0 [openssl-version]"
    exit 1
fi

echo "Generating header patch for OpenSSL ${OPENSSL_VERSION}..."

# Create temp directory
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# Extract twice: original and modified
echo "Extracting original..."
tar xzf "$TARBALL"
cp -R "openssl-${OPENSSL_VERSION}" "openssl-${OPENSSL_VERSION}-orig"

# Apply header renames to modified version
echo "Applying header renames..."
cd "openssl-${OPENSSL_VERSION}"
find include/openssl -type f -name "*.h" -exec sed -i "" -e "s|include <openssl/|include <personaopenssl/|g" {} \;
cd ..

# Generate patch
echo "Generating patch file..."
diff -Naur "openssl-${OPENSSL_VERSION}-orig" "openssl-${OPENSSL_VERSION}" > "$PATCH_FILE" || true

# Cleanup
cd /
rm -rf "$TMP_DIR"

if [ -f "$PATCH_FILE" ]; then
    echo "✅ Patch created: $PATCH_FILE"
    echo "   Lines: $(wc -l < "$PATCH_FILE")"
    echo ""
    echo "Next steps:"
    echo "  1. Verify the patch looks correct"
    echo "  2. Remove sed commands from build.sh (the patch will handle it)"
    echo "  3. Commit the patch file"
else
    echo "❌ Failed to create patch"
    exit 1
fi
