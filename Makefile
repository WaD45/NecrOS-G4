# ============================================================================
#  necros-g4 Makefile
# ============================================================================

VERSION := $(shell cat VERSION 2>/dev/null || echo "0.0.0")
SHELL   := /bin/sh
SCRIPTS := $(shell find . -name '*.sh' -not -path './.git/*')

.PHONY: help lint fmt fmt-fix test build build-64 build-ppc clean install release version

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# We lint with the `dash` dialect, not `sh`: NecrOS runs on BusyBox ash / dash,
# both of which support `local` (SC3043). SC1090/SC1091 are dynamic `source`
# lines that cannot be followed statically. Everything else must pass.
SHELLCHECK_OPTS := -s dash -e SC1090,SC1091

lint: ## Run shellcheck on all scripts (dash dialect)
	@echo "[*] Running shellcheck on $(words $(SCRIPTS)) scripts..."
	@_fail=0; for f in $(SCRIPTS); do \
		shellcheck $(SHELLCHECK_OPTS) "$$f" || _fail=1; \
	done; \
	if [ "$$_fail" -eq 0 ]; then echo "[✓] All scripts passed shellcheck"; \
	else echo "[!] shellcheck reported issues"; exit 1; fi

fmt: ## Check formatting with shfmt (use 'make fmt-fix' to apply)
	@shfmt -i 4 -ci -ln posix -d $(SCRIPTS)

fmt-fix: ## Reformat all scripts with shfmt
	@shfmt -i 4 -ci -ln posix -w $(SCRIPTS)
	@echo "[✓] Formatted $(words $(SCRIPTS)) scripts"

test: lint ## Run lint + integration tests
	@echo "[*] Running tests..."
	@sh tests/test_lib.sh
	@echo "[✓] All tests passed"

build: ## Build the ISO (requires Alpine Linux)
	@echo "[*] Building necros-g4 v$(VERSION) ISO..."
	@sh build_iso.sh --arch x86 --output build/
	@echo "[✓] Build complete"

build-64: ## Build 64-bit ISO
	@sh build_iso.sh --arch x86_64 --output build/

build-ppc: ## Build a PowerPC install bundle for PowerBook G4 class hardware
	@sh build_iso.sh --arch ppc --output build/

clean: ## Clean build artifacts
	@rm -rf build/ /tmp/necros-*
	@echo "[✓] Cleaned"

install: ## Install NecrOS on current Alpine system (requires root)
	@sh necro_install.sh

release: lint test ## Create a release tarball
	@mkdir -p build
	@tar czf "build/necros-g4-$(VERSION).tar.gz" \
		--exclude='.git' --exclude='build' --exclude='*.tar.gz' \
		-C .. "$(notdir $(CURDIR))"
	@echo "[✓] Release tarball: build/necros-g4-$(VERSION).tar.gz"

version: ## Show current version
	@echo "necros-g4 v$(VERSION)"
