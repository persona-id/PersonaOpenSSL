#!/usr/bin/env bash

set -euo pipefail

BASE_PWD="$PWD"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
FWNAME="PersonaOpenSSL"
OPENSSL_VERSION=${OPENSSL_VERSION:-3.5.8}
OUTPUT_DIR=$( mktemp -d )
# Keep the dynamic ABI limited to the OpenSSL entry points consumed by PersonaNfc.
# The linker treats this list as roots and can dead-strip the remaining archive code.
EXPORTED_SYMBOLS_LIST="${SCRIPT_DIR}/../config/PersonaOpenSSL.exports"
IPHONEOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IPHONESIMULATOR_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
PERSONA_CODE_SIGN_IDENTITY=${PERSONA_CODE_SIGN_IDENTITY:--}

cleanup() {
  rm -rf "${OUTPUT_DIR}"
}
trap cleanup EXIT

PODSPEC_VERSION=$(grep -m 1 's.version' "${BASE_PWD}/Persona-OpenSSL-Universal.podspec" | sed 's/.*"\([^"]*\)".*/\1/')

create_framework() {
  local TYPE=$1
  local PLATFORM=$2
  local FRAMEWORK_DIR="${OUTPUT_DIR}/${TYPE}/${FWNAME}.framework"
  local INFO_PLIST="${FRAMEWORK_DIR}/Info.plist"
  local PRIVACY_PLATFORM="${TYPE}"

  if [[ "${TYPE}" == "iphoneos" ]]; then
    PRIVACY_PLATFORM="ios"
  fi

  mkdir -p "${FRAMEWORK_DIR}/Headers" "${FRAMEWORK_DIR}/Modules"
  if [[ "${TYPE}" == "iphoneos" ]]; then
    xcrun clang -dynamiclib -arch arm64 -isysroot "${IPHONEOS_SDK}" \
      -mios-version-min=13.0 -Wl,-all_load -Wl,-dead_strip \
      -Wl,-exported_symbols_list,"${EXPORTED_SYMBOLS_LIST}" "${SCRIPT_DIR}/../${TYPE}/lib/libcrypto.a" \
      -Wl,-install_name,@rpath/${FWNAME}.framework/${FWNAME} \
      -Wl,-compatibility_version,1.0 -Wl,-current_version,"${OPENSSL_VERSION}" \
      -o "${FRAMEWORK_DIR}/${FWNAME}"
  else
    xcrun clang -dynamiclib -arch arm64 -isysroot "${IPHONESIMULATOR_SDK}" \
      -mios-simulator-version-min=13.0 -Wl,-all_load -Wl,-dead_strip \
      -Wl,-exported_symbols_list,"${EXPORTED_SYMBOLS_LIST}" "${SCRIPT_DIR}/../${TYPE}/lib/libcrypto.a" \
      -Wl,-install_name,@rpath/${FWNAME}.framework/${FWNAME} \
      -Wl,-compatibility_version,1.0 -Wl,-current_version,"${OPENSSL_VERSION}" \
      -o "${OUTPUT_DIR}/${FWNAME}-sim-arm64"
    xcrun clang -dynamiclib -arch x86_64 -isysroot "${IPHONESIMULATOR_SDK}" \
      -mios-simulator-version-min=13.0 -Wl,-all_load -Wl,-dead_strip \
      -Wl,-exported_symbols_list,"${EXPORTED_SYMBOLS_LIST}" "${SCRIPT_DIR}/../${TYPE}/lib/libcrypto.a" \
      -Wl,-install_name,@rpath/${FWNAME}.framework/${FWNAME} \
      -Wl,-compatibility_version,1.0 -Wl,-current_version,"${OPENSSL_VERSION}" \
      -o "${OUTPUT_DIR}/${FWNAME}-sim-x86_64"
    xcrun lipo -create \
      "${OUTPUT_DIR}/${FWNAME}-sim-arm64" "${OUTPUT_DIR}/${FWNAME}-sim-x86_64" \
      -output "${FRAMEWORK_DIR}/${FWNAME}"
  fi
  ditto "${SCRIPT_DIR}/../${TYPE}/include/openssl" "${FRAMEWORK_DIR}/Headers"
  cp "${SCRIPT_DIR}/../support/${PRIVACY_PLATFORM}/PrivacyInfo.xcprivacy" "${FRAMEWORK_DIR}/PrivacyInfo.xcprivacy"

  printf '%s\n' '// Include before others:' '#include <PersonaOpenSSL/ssl.h>' \
    > "${FRAMEWORK_DIR}/Headers/${FWNAME}.h"
  for HEADER_PATH in "${FRAMEWORK_DIR}/Headers"/*.h; do
    local HEADER_NAME
    HEADER_NAME=$(basename "${HEADER_PATH}")
    if [[ "${HEADER_NAME}" != "${FWNAME}.h" && "${HEADER_NAME}" != "ssl.h" ]]; then
      printf '#include <PersonaOpenSSL/%s>\n' "${HEADER_NAME}" \
        >> "${FRAMEWORK_DIR}/Headers/${FWNAME}.h"
    fi
  done

  printf '%s\n' \
    "framework module ${FWNAME} {" \
    "  umbrella header \"${FWNAME}.h\"" \
    '  export *' \
    '  module * { export * }' \
    '}' \
    > "${FRAMEWORK_DIR}/Modules/module.modulemap"

  plutil -create xml1 "${INFO_PLIST}"
  /usr/libexec/PlistBuddy -c "Add :CFBundleDevelopmentRegion string en" "${INFO_PLIST}"
  /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string ${FWNAME}" "${INFO_PLIST}"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.withpersona.sdk.${FWNAME}" "${INFO_PLIST}"
  /usr/libexec/PlistBuddy -c "Add :CFBundleInfoDictionaryVersion string 6.0" "${INFO_PLIST}"
  /usr/libexec/PlistBuddy -c "Add :CFBundleName string ${FWNAME}" "${INFO_PLIST}"
  /usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string FMWK" "${INFO_PLIST}"
  /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${PODSPEC_VERSION}" "${INFO_PLIST}"
  /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "${INFO_PLIST}"
  /usr/libexec/PlistBuddy -c "Add :CFBundleSupportedPlatforms array" "${INFO_PLIST}"
  /usr/libexec/PlistBuddy -c "Add :CFBundleSupportedPlatforms:0 string ${PLATFORM}" "${INFO_PLIST}"
  /usr/libexec/PlistBuddy -c "Add :MinimumOSVersion string 13.0" "${INFO_PLIST}"

  codesign --force --sign "${PERSONA_CODE_SIGN_IDENTITY}" "${FRAMEWORK_DIR}"
}

create_framework "iphoneos" "iPhoneOS"
create_framework "iphonesimulator" "iPhoneSimulator"

mkdir -p "${BASE_PWD}/Frameworks"
rm -rf "${BASE_PWD}/Frameworks/${FWNAME}.xcframework"
xcrun xcodebuild -quiet -create-xcframework \
  -framework "${OUTPUT_DIR}/iphoneos/${FWNAME}.framework" \
  -framework "${OUTPUT_DIR}/iphonesimulator/${FWNAME}.framework" \
  -output "${BASE_PWD}/Frameworks/${FWNAME}.xcframework"

codesign --force --sign "${PERSONA_CODE_SIGN_IDENTITY}" \
  "${BASE_PWD}/Frameworks/${FWNAME}.xcframework"

rm -f "${BASE_PWD}/Frameworks/${FWNAME}.xcframework.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
  "${BASE_PWD}/Frameworks/${FWNAME}.xcframework" \
  "${BASE_PWD}/Frameworks/${FWNAME}.xcframework.zip"
