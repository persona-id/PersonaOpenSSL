# PersonaOpenSSL Binary Size Optimization

## Purpose

PersonaOpenSSL packages OpenSSL for the NFC passport functionality in
`persona-ios`. Binary size is important because the framework is distributed
with Persona's iOS SDK and ultimately packaged by consuming applications.

This document records the OpenSSL 3.5.8 size work completed for CQEPD-9849 and
identifies possible follow-up optimizations. The measurements below are raw file
sizes from the repository build; App Store compression and architecture thinning
can produce different download and installed sizes.

## Measured artifacts

| Artifact | OpenSSL 1.1.1s baseline | Initial OpenSSL 3.5.8 | Final OpenSSL 3.5.8 |
| --- | ---: | ---: | ---: |
| Device framework binary | 1,701,328 bytes | 3,583,472 bytes | 1,604,768 bytes |
| Simulator framework binary | 3,486,880 bytes | 7,249,024 bytes | 3,201,104 bytes |
| XCFramework zip | 2,958,498 bytes | 5,354,503 bytes | 2,922,427 bytes |

Compared with the initial OpenSSL 3.5.8 build, trimming reduced:

- The device binary by 55.2%.
- The simulator binary by 55.8%.
- The release zip by 45.4%.

Compared with the optimized OpenSSL 1.1.1s baseline, the OpenSSL 3.5.8 device
binary is 96,560 bytes (5.7%) smaller, the simulator binary is 285,776 bytes
(8.2%) smaller, and the release zip is 36,071 bytes (1.2%) smaller.

## Optimizations already applied

The current trimmed build includes:

- Oleg's earlier exclusions of TLS, DTLS, `libssl`, unused legacy algorithms,
  macOS, and Mac Catalyst slices.
- Additional exclusions for CMP, HTTP, ML-KEM, ML-DSA, SLH-DSA, RFC3779,
  command-line applications, documentation, and tests.
- Clang `-Os` optimization. A test using `-Oz` produced slightly larger final
  artifacts, so `-Os` was retained.
- Linker dead stripping.
- Local-symbol stripping. The 169-entry public export surface remains intact;
  only non-exported linker symbols are removed from the shipped binaries.
- An exported-symbol allowlist containing the OpenSSL entry points consumed by
  PersonaNfc, plus OpenSSL's version diagnostics. This reduces the exported
  surface from approximately 7,500 symbols to 169.
- OpenSSL API compatibility level 1.1.1. This keeps the legacy APIs used by
  PersonaNfc available without annotating them as deprecated, preventing those
  diagnostics from failing Persona's warnings-as-errors release build.
- Exclusions for ECX/EdDSA, binary-field elliptic curves, RIPEMD-160, OCB, SIV,
  the legacy provider, dynamic module loading, sockets, secure-heap APIs, and
  automatic OpenSSL configuration loading. These facilities are outside the
  PersonaNfc passport protocol and exported API surface.
- Maximum deflate compression for the distributed XCFramework zip.

The allowlist is stored in `config/PersonaOpenSSL.exports`. Any new OpenSSL API
used by PersonaNfc must be added to the allowlist before rebuilding the
framework.

## Potential follow-up optimizations

### 1. ThinLTO

Compile OpenSSL and link the dynamic framework with `-flto=thin`. The export
allowlist gives LLVM a narrow public boundary, so link-time optimization may be
able to internalize functions and eliminate code across archive-object
boundaries.

ThinLTO was tested and rejected. It increased the device binary from 2,124,672
to 2,271,120 bytes, so the final build does not enable it.

### 2. OpenSSL small-footprint compilation

`OPENSSL_SMALL_FOOTPRINT` was tested and rejected. It saved only 33,616 bytes
before stripping and trades runtime performance for size, while the final build
already beats the release baseline without that compromise.

### 3. Additional symbol stripping

Implemented at link time with `-Wl,-x`. Exported OpenSSL API symbols and error
strings remain available, while private linker symbols are omitted from the
distributed binary.

### 4. Reduce diagnostic data

OpenSSL options such as `no-filenames` may remove source filenames embedded in
error data. Removing error strings more broadly could save additional space but
would make production failures significantly harder to diagnose.

### 5. Consolidate CMS, PKCS7, PEM, and ASN.1 workflows

PersonaNfc currently uses overlapping CMS and PKCS7 verification paths, PEM
serialization helpers, X.509 presentation helpers, and ASN.1 dump parsing.
Removing unused fallbacks or replacing diagnostic-only functionality could make
additional OpenSSL object groups unreachable.

This changes consumer behavior and should be driven by product and passport
compatibility requirements rather than build configuration alone.

### 6. Move simple primitives to Apple frameworks

Some operations, including hashes and AES-based operations, may be replaceable
with CommonCrypto, CryptoKit, or Security.framework. This only reduces the final
binary when it allows the corresponding OpenSSL implementation and its
dependencies to be removed entirely.

Apple frameworks do not cover the complete current dependency surface. The
passport reader uses RFC 5114 finite-field DH, multiple Brainpool curves,
arbitrary-precision arithmetic, and CMS/X.509 processing. Apple's CMS decoder is
not available on iOS, so a complete platform-only replacement is not currently
straightforward.

### 7. Curate distributed headers

The OpenSSL headers occupy approximately 2.3 MB in each XCFramework slice.
Shipping only the public and transitive headers needed by PersonaNfc could reduce
the repository and release-zip sizes substantially.

Headers normally do not contribute to the executable embedded in a customer
application, so this primarily improves SDK download and storage size.

### 8. Remove the x86_64 simulator slice

Shipping only arm64 for the simulator would materially reduce the release zip
and likely bring it below the old zip size. The tradeoff is loss of simulator
support on Intel Macs and any CI infrastructure that still requires x86_64.

### 9. Static linking

A static XCFramework prototype built and linked successfully and removed the
runtime dependency on `PersonaOpenSSL.framework`. In the measured PersonaNfc
debug build, however, the combined binary was larger than the allowlisted
dynamic approach. Static linkage is therefore not the leading option, although
a release/LTO configuration could be reevaluated.

## Copying OpenSSL source into PersonaNfc

Copying only the apparent OpenSSL functions into Persona's source tree is not a
simple dependency removal. CMS, X.509, EVP, DH, EC, RSA, ASN.1, provider, and
big-number implementations have extensive internal dependencies. A selected
source copy would effectively become a private OpenSSL fork.

That approach would require Persona to:

- Track and backport relevant OpenSSL security fixes.
- Preserve OpenSSL licensing and attribution.
- Maintain the selected internal dependency graph across compiler and platform
  changes.
- Demonstrate that security scanners and SBOM tooling correctly identify the
  embedded OpenSSL-derived code.
- Establish extensive passport, cryptographic, and malformed-input test
  coverage.

Source-level extraction could eventually produce a smaller binary, but the
maintenance and security costs are considerably higher than using OpenSSL's
supported configuration and linker-level pruning.

## Further investigation

The current artifacts meet the release-size target without removing Intel
simulator support, error strings, filename diagnostics, or thread safety. Any
future reductions should be driven by a new size target and validated against
the runtime passport matrix before accepting additional compatibility tradeoffs.

Every candidate should be evaluated against both the release zip and the
arm64 device binary. Any accepted change should also pass PersonaNfc compilation,
CMS/X.509 symbol verification, code-signature validation, and runtime passport
tests covering BAC, PACE, passive authentication, active authentication, and
chip authentication.
