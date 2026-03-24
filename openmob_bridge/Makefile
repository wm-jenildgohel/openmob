BINARY_NAME := aibridge
VERSION := $(shell cargo metadata --format-version=1 --no-deps 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['packages'][0]['version'])" 2>/dev/null || echo "0.1.0")

# Default: build debug
.PHONY: build
build:
	cargo build

# Release build for current platform
.PHONY: release
release:
	cargo build --release

# Install to ~/.cargo/bin
.PHONY: install
install:
	cargo install --path .

# Cross-compile all targets (requires `cross` tool: cargo install cross)
.PHONY: cross-all
cross-all: cross-linux-amd64 cross-linux-arm64 cross-darwin-amd64 cross-darwin-arm64 cross-windows-amd64

.PHONY: cross-linux-amd64
cross-linux-amd64:
	cross build --release --target x86_64-unknown-linux-gnu
	mkdir -p dist
	cp target/x86_64-unknown-linux-gnu/release/$(BINARY_NAME) dist/$(BINARY_NAME)-linux-amd64

.PHONY: cross-linux-arm64
cross-linux-arm64:
	cross build --release --target aarch64-unknown-linux-gnu
	mkdir -p dist
	cp target/aarch64-unknown-linux-gnu/release/$(BINARY_NAME) dist/$(BINARY_NAME)-linux-arm64

.PHONY: cross-darwin-amd64
cross-darwin-amd64:
	cross build --release --target x86_64-apple-darwin
	mkdir -p dist
	cp target/x86_64-apple-darwin/release/$(BINARY_NAME) dist/$(BINARY_NAME)-darwin-amd64

.PHONY: cross-darwin-arm64
cross-darwin-arm64:
	cross build --release --target aarch64-apple-darwin
	mkdir -p dist
	cp target/aarch64-apple-darwin/release/$(BINARY_NAME) dist/$(BINARY_NAME)-darwin-arm64

.PHONY: cross-windows-amd64
cross-windows-amd64:
	cross build --release --target x86_64-pc-windows-gnu
	mkdir -p dist
	cp target/x86_64-pc-windows-gnu/release/$(BINARY_NAME).exe dist/$(BINARY_NAME)-windows-amd64.exe

.PHONY: clean
clean:
	cargo clean
	rm -rf dist

.PHONY: check
check:
	cargo check

.PHONY: fmt
fmt:
	cargo fmt
