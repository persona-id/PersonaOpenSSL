#!/usr/bin/env bash

# Yay shell scripting! This script builds a static version of
# OpenSSL for iOS that contains code for arm64 and x86_64.

set -e
# set -x

BASE_PWD="$PWD"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# Setup paths to stuff we need

if [[ -z $OPENSSL_VERSION ]]; then
 echo "OPENSSL_VERSION not set"
 exit 1
fi

export OPENSSL_LOCAL_CONFIG_DIR="${SCRIPT_DIR}/../config"


DEVELOPER=$(xcode-select --print-path)

export IPHONEOS_DEPLOYMENT_VERSION="13.0"
IPHONEOS_SDK=$(xcrun --sdk iphoneos --show-sdk-path)
IPHONESIMULATOR_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)

# Disabled OpenSSL features
OPENSSL_DISABLED_FEATURES=(
   no-ssl          # SSL protocol - not used, only crypto primitives needed
   no-tls          # TLS protocol - not used for NFC
   no-dtls         # DTLS protocol - not used for NFC
   no-bf           # Blowfish cipher - passport uses AES/3DES only
   no-camellia     # Camellia cipher - not in ICAO spec
   no-cast         # CAST cipher - not in ICAO spec
   no-idea         # IDEA cipher - not in ICAO spec
   no-md2          # MD2 hash - obsolete, not used
   no-md4          # MD4 hash - obsolete, not used
   no-mdc2         # MDC2 hash - obsolete, not used
   no-rc2          # RC2 cipher - not in ICAO spec
   no-rc4          # RC4 cipher - not in ICAO spec
   no-rc5          # RC5 cipher - not in ICAO spec
   no-seed         # SEED cipher - Korean standard, not used
   no-whirlpool    # Whirlpool hash - not in ICAO spec
   no-ocsp         # OCSP - online cert checking not needed
   no-srp          # SRP - password auth protocol not used
   no-ct           # Certificate Transparency - not needed
   no-comp         # Compression - not used in passport protocol
   no-ts           # Timestamp - not needed
   no-gost         # GOST - Russian algorithms not in ICAO spec
   no-scrypt       # scrypt KDF - not used, custom KDF in PACE
   no-sm2          # SM2 - Chinese algorithm not in ICAO spec
   no-sm3          # SM3 - Chinese hash not in ICAO spec
   no-sm4          # SM4 - Chinese cipher not in ICAO spec
   no-srtp         # SRTP - media encryption not needed
   no-siphash      # SipHash - not in ICAO spec
   no-poly1305     # Poly1305 MAC - not in ICAO spec
   no-chacha       # ChaCha20 cipher - not in ICAO spec
   no-aria         # ARIA cipher - Korean standard, not used
   no-blake2       # BLAKE2 hash - not in ICAO spec
)

# Turn versions like 1.2.3 into numbers that can be compare by bash.
version()
{
   printf "%03d%03d%03d%03d" $(tr '.' ' ' <<<"$1");
}

configure() {
   local OS=$1
   local ARCH=$2
   local BUILD_DIR=$3
   local SRC_DIR=$4

   echo "Configuring for ${OS} ${ARCH}"

   local SDK=
   case "$OS" in
      iPhoneOS)
	 SDK="${IPHONEOS_SDK}"
	 ;;
      iPhoneSimulator)
	 SDK="${IPHONESIMULATOR_SDK}"
	 ;;
      *)
	 echo "Unsupported OS '${OS}'!" >&1
	 exit 1
	 ;;
   esac

   local PREFIX="${BUILD_DIR}/${OPENSSL_VERSION}-${OS}-${ARCH}"

   export CROSS_TOP="${SDK%%/SDKs/*}"
   export CROSS_SDK="${SDK##*/SDKs/}"
   if [ -z "$CROSS_TOP" -o -z "$CROSS_SDK" ]; then
      echo "Failed to parse SDK path '${SDK}'!" >&1
      exit 2
   fi

   if [ "$OS" == "iPhoneSimulator" ]; then
      ${SRC_DIR}/Configure ios-sim-cross-$ARCH no-asm no-shared ${OPENSSL_DISABLED_FEATURES[@]} --prefix="${PREFIX}" &> "${PREFIX}.config.log"
   elif [ "$OS" == "iPhoneOS" ]; then
      ${SRC_DIR}/Configure ios-cross-$ARCH no-asm no-shared ${OPENSSL_DISABLED_FEATURES[@]} --prefix="${PREFIX}" &> "${PREFIX}.config.log"
   fi
}

build()
{
   local ARCH=$1
   local OS=$2
   local BUILD_DIR=$3
   local TYPE=$4 # iphoneos/iphonesimulator

   local SRC_DIR="${BUILD_DIR}/openssl-${OPENSSL_VERSION}-${TYPE}"
   local PREFIX="${BUILD_DIR}/${OPENSSL_VERSION}-${OS}-${ARCH}"

   mkdir -p "${SRC_DIR}"
   tar xzf "${SCRIPT_DIR}/../openssl-${OPENSSL_VERSION}.tar.gz" -C "${SRC_DIR}" --strip-components=1

   # Apply patches if needed
   local PATCH_FILE="${SCRIPT_DIR}/../patches/openssl-${OPENSSL_VERSION}.patch"
   if [ -f "$PATCH_FILE" ]; then
      patch -d "${SRC_DIR}" -p1 < $PATCH_FILE
   fi

   echo "Building for ${OS} ${ARCH}"

   # Change dir
   cd "${SRC_DIR}"

   # fix headers for Swift

   sed -ie "s/BIGNUM \*I,/BIGNUM \*i,/g" ${SRC_DIR}/crypto/rsa/rsa_local.h   

   configure "${OS}" $ARCH ${BUILD_DIR} ${SRC_DIR}

   LOG_PATH="${PREFIX}.build.log"
   echo "Building ${LOG_PATH}"
   make &> ${LOG_PATH}
   make install &> ${LOG_PATH}
   cd ${BASE_PWD}

   # Add arch to library (only libcrypto.a - libssl.a not needed for NFC passport reader)
   if [ -f "${SCRIPT_DIR}/../${TYPE}/lib/libcrypto.a" ]; then
      xcrun lipo "${SCRIPT_DIR}/../${TYPE}/lib/libcrypto.a" "${PREFIX}/lib/libcrypto.a" -create -output "${SCRIPT_DIR}/../${TYPE}/lib/libcrypto.a"
   else
      cp "${PREFIX}/lib/libcrypto.a" "${SCRIPT_DIR}/../${TYPE}/lib/libcrypto.a"
   fi

   rm -rf "${SRC_DIR}"
}

build_ios() {
   local TMP_BUILD_DIR=$( mktemp -d )

   # Clean up whatever was left from our previous build
   rm -rf "${SCRIPT_DIR}"/../{iphonesimulator/include,iphonesimulator/lib}
   mkdir -p "${SCRIPT_DIR}"/../{iphonesimulator/include,iphonesimulator/lib}

   build "x86_64" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator"
   build "arm64" "iPhoneSimulator" ${TMP_BUILD_DIR} "iphonesimulator"

   rm -rf "${SCRIPT_DIR}"/../{iphoneos/include,iphoneos/lib}
   mkdir -p "${SCRIPT_DIR}"/../{iphoneos/include,iphoneos/lib}

   build "arm64" "iPhoneOS" ${TMP_BUILD_DIR} "iphoneos"

   ditto "${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneOS-arm64/include/openssl" "${SCRIPT_DIR}/../iphoneos/include/openssl"
   cp -f "${SCRIPT_DIR}/../shim/shim.h" "${SCRIPT_DIR}/../iphoneos/include/openssl/shim.h"

   # Copy headers
   ditto "${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneSimulator-arm64/include/openssl" "${SCRIPT_DIR}/../iphonesimulator/include/openssl"
   cp -f "${SCRIPT_DIR}/../shim/shim.h" "${SCRIPT_DIR}/../iphonesimulator/include/openssl/shim.h"

   # fix inttypes.h
   find "${SCRIPT_DIR}/../iphoneos/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/include <inttypes\.h>/include <sys\/types\.h>/g" {} \;
   find "${SCRIPT_DIR}/../iphonesimulator/include/openssl" -type f -name "*.h" -exec sed -i "" -e "s/include <inttypes\.h>/include <sys\/types\.h>/g" {} \;

   local OPENSSLCONF_PATH="${SCRIPT_DIR}/../iphonesimulator/include/openssl/opensslconf.h"
   echo "#if defined(__APPLE__) && defined (__x86_64__)" > ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneSimulator-x86_64/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#elif defined(__APPLE__) && defined (__arm64__)" >> ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneSimulator-arm64/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#endif" >> ${OPENSSLCONF_PATH}

   OPENSSLCONF_PATH="${SCRIPT_DIR}/../iphoneos/include/openssl/opensslconf.h"
   echo "#if defined(__APPLE__) && defined (__arm64__)" > ${OPENSSLCONF_PATH}
   cat ${TMP_BUILD_DIR}/${OPENSSL_VERSION}-iPhoneOS-arm64/include/openssl/opensslconf.h >> ${OPENSSLCONF_PATH}
   echo "#endif" >> ${OPENSSLCONF_PATH}

   rm -rf ${TMP_BUILD_DIR}
}

# Start

if [ ! -f "${SCRIPT_DIR}/../openssl-${OPENSSL_VERSION}.tar.gz" ]; then
   curl -fL "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" -o "${SCRIPT_DIR}/../openssl-${OPENSSL_VERSION}.tar.gz"
   curl -fL "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz.sha256" -o "${SCRIPT_DIR}/../openssl-${OPENSSL_VERSION}.tar.gz.sha256"
   DIGEST=$( cat ${SCRIPT_DIR}/../openssl-${OPENSSL_VERSION}.tar.gz.sha256 )

   if [[ "$(shasum -a 256 "openssl-${OPENSSL_VERSION}.tar.gz" | awk '{print $1}')" != "${DIGEST}" ]]
   then
      echo "openssl-${OPENSSL_VERSION}.tar.gz: checksum mismatch"
      exit 1
   fi
   rm -f "${SCRIPT_DIR}/../openssl-${OPENSSL_VERSION}.tar.gz.sha256"
fi

build_ios
