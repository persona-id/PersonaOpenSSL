.PHONY: build
.PHONY: frameworks

CWD := $(abspath $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST))))))

all: build frameworks

build:
	OPENSSL_VERSION="3.5.8" $(CWD)/scripts/build.sh

frameworks:
	$(CWD)/scripts/create-frameworks.sh

.PHONY: static
static:
	OPENSSL_VERSION="3.5.8" OPENSSL_OUTPUT_DIR="$(CWD)/.build/static" OPENSSL_MODULE_NAME=PersonaOpenSSLStatic OPENSSL_PRIVATE_SYMBOLS=1 $(CWD)/scripts/build.sh
	$(CWD)/scripts/create-static-frameworks.sh
