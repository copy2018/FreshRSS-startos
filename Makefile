PKG_VERSION := $(shell yq -e ".version" manifest.yaml)
PKG_ID := $(shell yq -e ".id" manifest.yaml)
MANAGER_SRC := $(shell find ./manager -name '*.rs') manager/Cargo.toml manager/Cargo.lock
VERSION_CORE := $(shell (cd bitcoin && git describe) | sed 's/^v//')

.DELETE_ON_ERROR:

all: verify

clean:
	rm -f $(PKG_ID).s9pk
	rm -f docker-images/*.tar
	rm -f scripts/*.js

verify: $(PKG_ID).s9pk
	@start-sdk verify s9pk $(PKG_ID).s9pk
	@echo " Done!"
	@echo "   Filesize: $(shell du -h $(PKG_ID).s9pk) is ready"

# for rebuilding just the arm image.
arm:
	@rm -f docker-images/x86_64.tar
	@ARCH=aarch64 $(MAKE) -s

# for rebuilding just the x86 image.
x86:
	@rm -f docker-images/aarch64.tar
	@ARCH=x86_64 $(MAKE) -s

$(PKG_ID).s9pk: manifest.yaml assets/compat/* docker-images/aarch64.tar docker-images/x86_64.tar instructions.md scripts/embassy.js
ifeq ($(ARCH),aarch64)
	@echo "start-sdk: Preparing aarch64 package ..."
else ifeq ($(ARCH),x86_64)
	@echo "start-sdk: Preparing x86_64 package ..."
else
	@echo "start-sdk: Preparing Universal Package ..."
endif
	@start-sdk pack

install: $(PKG_ID).s9pk
ifeq (,$(wildcard ./start9/config.yaml))
	@echo; echo "You must define \"host: http://server-name.local\" in ./start9/config.yaml config file first"; echo
else
	start-cli package install $(PKG_ID).s9pk
endif

docker-images/aarch64.tar: Dockerfile docker_entrypoint.sh
ifeq ($(ARCH),x86_64)
else
	mkdir -p docker-images
	docker buildx build --tag start9/$(PKG_ID)/main:$(PKG_VERSION) --build-arg ARCH=aarch64 --build-arg PLATFORM=arm64 --platform=linux/arm64 -o type=docker,dest=docker-images/aarch64.tar .
endif

docker-images/x86_64.tar: Dockerfile docker_entrypoint.sh 
ifeq ($(ARCH),aarch64)
else
	mkdir -p docker-images
	docker buildx build --tag start9/$(PKG_ID)/main:$(PKG_VERSION) --build-arg ARCH=x86_64 --build-arg PLATFORM=amd64 --platform=linux/amd64 -o type=docker,dest=docker-images/x86_64.tar .
endif

scripts/embassy.js: scripts/**/*.ts
	deno bundle scripts/embassy.ts scripts/embassy.js
