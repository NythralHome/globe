# Globe build entry points.
#
# Two distribution channels are produced from one codebase:
#   - direct    : Developer ID signed, notarized, shipped as PKG/DMG off the site.
#   - appstore  : sandboxed, Apple Distribution signed, shipped via the App Store.
# The only differences are the GLOBE_DISTRIBUTION env var (which flips the
# GLOBE_APP_STORE compile flag, bundle id, sandbox entitlement and signing).
#
# Every recipe invokes the underlying script directly so a failing build returns
# a non-zero exit status. Do NOT pipe build commands into `tail`/`head`: a pipe
# masks the build's exit code and a stale bundle can be shipped silently.

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := check

# Codesign identity for local Developer ID builds; override on the CLI if needed.
GLOBE_CODESIGN_IDENTITY ?= -
export GLOBE_CODESIGN_IDENTITY

.PHONY: check build-direct build-appstore test run package-direct package-dmg package-appstore clean

## check: compile both channels (no signing). The fast local/CI gate.
check:
	@echo "==> Compiling direct (Developer ID) flavor"
	swift build -c release --arch arm64 --arch x86_64
	@echo "==> Compiling App Store flavor (-DGLOBE_APP_STORE)"
	swift build -c release --arch arm64 --arch x86_64 -Xswiftc -DGLOBE_APP_STORE
	@echo "==> Both flavors compile."

## test: run the unit tests.
test:
	swift test

## build-direct: build the signed direct .app bundle.
build-direct:
	GLOBE_DISTRIBUTION=developer-id Scripts/build-app-bundle.sh

## build-appstore: build the App Store .app bundle.
build-appstore:
	GLOBE_DISTRIBUTION=app-store Scripts/build-app-bundle.sh

## run: build the direct bundle, install to /Applications and launch it.
run: build-direct
	@pkill -x Globe 2>/dev/null || true
	@sleep 1
	rm -rf /Applications/Globe.app
	cp -R .build/bundles/Globe.app /Applications/Globe.app
	codesign --verify --strict /Applications/Globe.app
	open /Applications/Globe.app

## package-direct: build the signed PKG installer (direct channel).
package-direct:
	Scripts/package-pkg.sh

## package-dmg: build the signed DMG (direct channel).
package-dmg:
	Scripts/package-beta.sh

## package-appstore: build the App Store .pkg for App Store Connect.
package-appstore:
	Scripts/package-app-store.sh

## clean: remove build products.
clean:
	rm -rf .build/bundles .build/dist .build/pkg .build/app-store .build/staging .build/mount
