# Makefile for axorc helper

# Define the output binary name
BINARY_NAME = axorc
UNIVERSAL_BINARY_PATH = ./$(BINARY_NAME)
RELEASE_BUILD_DIR := ./.build/arm64-apple-macosx/release
RELEASE_BUILD_DIR_X86 := ./.build/x86_64-apple-macosx/release

# Build for arm64 and x86_64, then lipo them together
# -Xswiftc -Osize: Optimize for size
# -Xlinker -Wl,-dead_strip: Remove dead code
# strip -x: Strip symbol table and debug info
# Ensure old binary is removed first
all:
	@echo "Cleaning old binary and build artifacts..."
	rm -f $(UNIVERSAL_BINARY_PATH)
	swift package clean
	@echo "Building for arm64..."
	swift build --arch arm64 -c release -Xswiftc -Osize -Xlinker -dead_strip
	@echo "Building for x86_64..."
	swift build --arch x86_64 -c release -Xswiftc -Osize -Xlinker -dead_strip
	@echo "Creating universal binary..."
	lipo -create -output $(UNIVERSAL_BINARY_PATH) $(RELEASE_BUILD_DIR)/$(BINARY_NAME) $(RELEASE_BUILD_DIR_X86)/$(BINARY_NAME)
	@echo "Stripping symbols from universal binary..."
	strip -x $(UNIVERSAL_BINARY_PATH)
	@echo "Build complete: $(UNIVERSAL_BINARY_PATH)"
	@ls -l $(UNIVERSAL_BINARY_PATH)
	@codesign -s - $(UNIVERSAL_BINARY_PATH)
	@echo "Codesigned $(UNIVERSAL_BINARY_PATH)"


clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -f $(UNIVERSAL_BINARY_PATH)
	@echo "Clean complete."

# Format code with SwiftFormat
format:
	@echo "Formatting code with SwiftFormat..."
	swiftformat .
	@echo "Code formatting complete."

# Check code formatting (for CI)
format-check:
	@echo "Checking code formatting with SwiftFormat..."
	swiftformat --lint .
	@echo "Code formatting check complete."

# Lint code with SwiftLint
lint:
	@echo "Linting code with SwiftLint..."
	swiftlint lint --strict
	@echo "Code linting complete."

# Run both formatting and linting
check: format-check lint
	@echo "All code checks complete."

# Default target
.DEFAULT_GOAL := all
