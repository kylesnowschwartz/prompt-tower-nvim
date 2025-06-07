# Makefile for prompt-tower.nvim development

# Default test directory
TEST_DIR ?= tests
# Default Neovim binary
NVIM ?= nvim

.PHONY: test test-file lint format clean install-deps ci check pre-commit help

# Run all tests using script
test:
	@scripts/test.sh

# Run tests with verbose output
test-verbose:
	@scripts/test.sh --verbose

# Run a specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=<test_file>"; \
		echo "Example: make test-file FILE=tests/config_spec.lua"; \
		exit 1; \
	fi
	@echo "Running test file: $(FILE)"
	@$(NVIM) --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedFile $(FILE)"

# Run linting checks using script
lint:
	@scripts/lint.sh

# Format code using script
format:
	@scripts/format.sh

# Check formatting without making changes
format-check:
	@scripts/format.sh --check

# Run CI checks (format + lint + test)
ci: format-check lint test
	@echo "✅ All CI checks passed!"

# Alias for ci
check: ci

# Run pre-commit checks manually
pre-commit:
	@.git/hooks/pre-commit

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@find . -name "*.tmp" -delete
	@find . -name "*.log" -delete
	@find . -name "*~" -delete

# Install development dependencies
install-deps:
	@echo "📦 Installing development dependencies..."
	@echo ""
	@echo "Required tools:"
	@echo "  1. plenary.nvim - Testing framework"
	@echo "     Install in your Neovim config (e.g., via plugin manager)"
	@echo ""
	@echo "  2. StyLua - Lua formatter"
	@echo "     cargo install stylua"
	@echo ""
	@echo "  3. Selene - Lua linter (optional)"
	@echo "     cargo install selene"
	@echo ""
	@echo "  4. luac - Lua syntax checker"
	@echo "     Usually comes with Lua installation"
	@echo ""
	@echo "✅ Run 'make check' after installing to verify setup"

# Setup development environment
dev-setup:
	@echo "🔧 Setting up development environment..."
	@chmod +x scripts/*.sh .git/hooks/pre-commit
	@echo "✅ Made scripts executable"
	@echo "✅ Pre-commit hook installed"
	@echo ""
	@echo "🎯 Next steps:"
	@echo "  1. Run 'make install-deps' for dependency info"
	@echo "  2. Run 'make check' to verify everything works"

# Show help
help:
	@echo "🔧 prompt-tower.nvim Development Commands"
	@echo ""
	@echo "Testing:"
	@echo "  test         - Run all tests"
	@echo "  test-verbose - Run tests with verbose output"
	@echo "  test-file    - Run specific test file (usage: make test-file FILE=path/to/test.lua)"
	@echo ""
	@echo "Code Quality:"
	@echo "  lint         - Run linting checks"
	@echo "  format       - Format code"
	@echo "  format-check - Check formatting without changes"
	@echo "  ci/check     - Run all CI checks (format + lint + test)"
	@echo "  pre-commit   - Run pre-commit checks manually"
	@echo ""
	@echo "Maintenance:"
	@echo "  clean        - Clean temporary files"
	@echo "  install-deps - Show dependency installation info"
	@echo "  dev-setup    - Setup development environment"
	@echo "  help         - Show this help message"