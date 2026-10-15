#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
INPUT="${ROOT}/.build/static"
NAME=PersonaOpenSSLStatic
OUTPUT="${ROOT}/Frameworks/${NAME}.xcframework"
TEMP=$(mktemp -d)
trap 'rm -rf "${TEMP}"' EXIT

for PLATFORM in iphoneos iphonesimulator; do
  LIBRARY_DIR="${TEMP}/${PLATFORM}"
  HEADERS="${LIBRARY_DIR}/Headers"
  mkdir -p "${HEADERS}/${NAME}"
  cp "${INPUT}/${PLATFORM}/lib/libcrypto.a" "${LIBRARY_DIR}/lib${NAME}.a"
  ditto "${INPUT}/${PLATFORM}/include/openssl" "${HEADERS}/${NAME}"
  printf '#include <%s/ssl.h>\n' "${NAME}" > "${HEADERS}/${NAME}/${NAME}.h"
  for HEADER in "${HEADERS}/${NAME}"/*.h; do
    HEADER_NAME=$(basename "${HEADER}")
    if [[ "${HEADER_NAME}" != "${NAME}.h" && "${HEADER_NAME}" != ssl.h ]]; then
      printf '#include <%s/%s>\n' "${NAME}" "${HEADER_NAME}" >> "${HEADERS}/${NAME}/${NAME}.h"
    fi
  done
  printf 'module %s {\n  umbrella header "%s/%s.h"\n  export *\n}\n' \
    "${NAME}" "${NAME}" "${NAME}" > "${HEADERS}/module.modulemap"
done

rm -rf "${OUTPUT}"
xcrun xcodebuild -quiet -create-xcframework \
  -library "${TEMP}/iphoneos/lib${NAME}.a" -headers "${TEMP}/iphoneos/Headers" \
  -library "${TEMP}/iphonesimulator/lib${NAME}.a" -headers "${TEMP}/iphonesimulator/Headers" \
  -output "${OUTPUT}"
cp "${ROOT}/LICENSE.txt" "${OUTPUT}/LICENSE.txt"
cp "${ROOT}/support/ios/PrivacyInfo.xcprivacy" "${OUTPUT}/PrivacyInfo.xcprivacy"
codesign --force --sign "${PERSONA_CODE_SIGN_IDENTITY:--}" "${OUTPUT}"
rm -f "${OUTPUT}.zip"
(cd "${ROOT}/Frameworks" && zip -9 --symlinks -qr "${NAME}.xcframework.zip" "${NAME}.xcframework")
