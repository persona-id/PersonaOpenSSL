#!/usr/bin/env bash

set -e
# set -x

XC_USER_DEFINED_VARS=""

while getopts ":s" option; do
   case $option in
      s) # Build XCFramework as static instead of dynamic
         XC_USER_DEFINED_VARS="MACH_O_TYPE=staticlib"
   esac
done

BASE_PWD="$PWD"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
FWNAME="PersonaOpenSSL"
OUTPUT_DIR=$( mktemp -d )
COMMON_SETUP=" -project ${SCRIPT_DIR}/../${FWNAME}.xcodeproj -configuration Release -quiet BUILD_LIBRARY_FOR_DISTRIBUTION=YES $XC_USER_DEFINED_VARS"

# iOS
DERIVED_DATA_PATH=$( mktemp -d )
xcrun xcodebuild build \
	$COMMON_SETUP \
    -scheme "${FWNAME} (iOS)" \
	-derivedDataPath "${DERIVED_DATA_PATH}" \
	-destination 'generic/platform=iOS'

rm -rf "${OUTPUT_DIR}/iphoneos"
mkdir -p "${OUTPUT_DIR}/iphoneos"
ditto "${DERIVED_DATA_PATH}/Build/Products/Release-iphoneos/${FWNAME}.framework" "${OUTPUT_DIR}/iphoneos/${FWNAME}.framework"
rm -rf "${DERIVED_DATA_PATH}"

# iOS Simulator
DERIVED_DATA_PATH=$( mktemp -d )
xcrun xcodebuild build \
	$COMMON_SETUP \
    -scheme "${FWNAME} (iOS Simulator)" \
	-derivedDataPath "${DERIVED_DATA_PATH}" \
	-destination 'generic/platform=iOS Simulator'

rm -rf "${OUTPUT_DIR}/iphonesimulator"
mkdir -p "${OUTPUT_DIR}/iphonesimulator"
ditto "${DERIVED_DATA_PATH}/Build/Products/Release-iphonesimulator/${FWNAME}.framework" "${OUTPUT_DIR}/iphonesimulator/${FWNAME}.framework"
rm -rf "${DERIVED_DATA_PATH}"

#

rm -rf "${BASE_PWD}/Frameworks/iphoneos"
mkdir -p "${BASE_PWD}/Frameworks/iphoneos"
ditto "${OUTPUT_DIR}/iphoneos/${FWNAME}.framework" "${BASE_PWD}/Frameworks/iphoneos/${FWNAME}.framework"

rm -rf "${BASE_PWD}/Frameworks/iphonesimulator"
mkdir -p "${BASE_PWD}/Frameworks/iphonesimulator"
ditto "${OUTPUT_DIR}/iphonesimulator/${FWNAME}.framework" "${BASE_PWD}/Frameworks/iphonesimulator/${FWNAME}.framework"

# XCFramework
rm -rf "${BASE_PWD}/Frameworks/${FWNAME}.xcframework"

xcrun xcodebuild -quiet -create-xcframework \
	-framework "${OUTPUT_DIR}/iphoneos/${FWNAME}.framework" \
	-framework "${OUTPUT_DIR}/iphonesimulator/${FWNAME}.framework" \
	-output "${BASE_PWD}/Frameworks/${FWNAME}.xcframework"

# Fix Info.plist files: Add CFBundleShortVersionString (required for App Store validation)
echo "Adding CFBundleShortVersionString to framework Info.plist files..."
PODSPEC_VERSION=$(grep -m 1 's.version' "${BASE_PWD}/Persona-OpenSSL-Universal.podspec" | sed 's/.*"\(.*\)".*/\1/')
echo "Using version: ${PODSPEC_VERSION}"

for INFO_PLIST in "${BASE_PWD}/Frameworks/${FWNAME}.xcframework"/*/*/Info.plist; do
  if [ -f "$INFO_PLIST" ]; then
    # Remove code signature if it exists (will be re-signed later)
    FRAMEWORK_DIR=$(dirname "$INFO_PLIST")
    if [ -d "${FRAMEWORK_DIR}/_CodeSignature" ]; then
      echo "Removing code signature from $(basename $(dirname ${FRAMEWORK_DIR}))"
      rm -rf "${FRAMEWORK_DIR}/_CodeSignature"
    fi

    # Add CFBundleShortVersionString if it doesn't exist
    if ! /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null; then
      echo "Adding CFBundleShortVersionString to $(basename $(dirname ${FRAMEWORK_DIR}))"
      /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${PODSPEC_VERSION}" "$INFO_PLIST"
    else
      echo "CFBundleShortVersionString already exists in $(basename $(dirname ${FRAMEWORK_DIR}))"
    fi
  fi
done

# Re-sign the XCFramework after modifying Info.plist files
echo "Re-signing XCFramework..."
codesign --timestamp -v --sign "iPhone Distribution: Persona Identities, Inc. (YA49JBJSCR)" \
  "${BASE_PWD}/Frameworks/${FWNAME}.xcframework"

# Zip archive
pushd "${BASE_PWD}/Frameworks"
zip --symlinks -r "./${FWNAME}.xcframework.zip" "./${FWNAME}.xcframework"
popd

rm -rf "${OUTPUT_DIR}"
