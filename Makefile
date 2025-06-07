# Makefile for prompt-tower.nvim development

# Default test directory
TEST_DIR ?= tests
# Default Neovim binary
NVIM ?= nvim

.PHONY: test test-file lint format clean install-deps help

# Run all tests
test:
	@echo "Running all tests..."
	@$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory $(TEST_DIR) { minimal_init = 'tests/minimal_init.lua' }"

# Run a specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=<test_file>"; \
		echo "Example: make test-file FILE=tests/config_spec.lua"; \
		exit 1; \
	fi
	@echo "Running test file: $(FILE)"
	@$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedFile $(FILE)"

# Check Lua syntax and style
lint:
	@echo "Checking Lua syntax..."
	@find lua/ -name "*.lua" -exec luac -p {} \; 2>&1 || echo "luac not found, skipping syntax check"
	@echo "Checking with selene (if available)..."
	@selene lua/ || echo "selene not found, skipping linting"

# Format Lua code
format:
	@echo "Formatting Lua code..."
	@stylua lua/ tests/ || echo "stylua not found, skipping formatting"

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@find . -name "*.tmp" -delete
	@find . -name "*.log" -delete

# Install development dependencies
install-deps:
	@echo "This would install development dependencies..."
	@echo "Please ensure you have:"
	@echo "  - plenary.nvim installed in your Neovim setup"
	@echo "  - luac (for syntax checking)"
	@echo "  - stylua (for formatting)"
	@echo "  - selene (for linting)"

# Show help
help:
	@echo "Available targets:"
	@echo "  test       - Run all tests"
	@echo "  test-file  - Run a specific test file (usage: make test-file FILE=path/to/test.lua)"
	@echo "  lint       - Check Lua syntax and style"
	@echo "  format     - Format Lua code with stylua"
	@echo "  clean      - Clean temporary files"
	@echo "  install-deps - Show information about required dependencies"
	@echo "  help       - Show this help message"