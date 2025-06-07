# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

prompt-tower.nvim is a Neovim plugin for creating AI-ready context from codebases. It allows users to select files and generate structured prompts for AI assistants, inspired by the VSCode Prompt Tower extension.

## Development Commands

Use these Make commands for development workflow:

```bash
# Testing
make test                    # Run all tests using plenary.nvim
make test-verbose           # Run tests with verbose output
make test-file FILE=path    # Run specific test file

# Code Quality
make lint                   # Run Selene linting
make format                 # Format code with StyLua
make format-check          # Check formatting without changes
make ci                    # Run all CI checks (format + lint + test)

# Development Setup
make dev-setup             # Setup development environment
make install-deps          # Show dependency installation info
```

## Architecture Overview

### Core Architecture Pattern

The plugin follows a layered architecture:

1. **Plugin Layer** (`plugin/prompt-tower.lua`): Registers Neovim user commands
2. **Main Interface** (`lua/prompt-tower/init.lua`): Primary API and command handlers
3. **Configuration** (`lua/prompt-tower/config.lua`): Centralized configuration management with validation
4. **Services Layer** (`lua/prompt-tower/services/`): Business logic for workspace and file operations
5. **Models Layer** (`lua/prompt-tower/models/`): Data structures and domain objects

### Key Components

#### Configuration System (`config.lua`)
- Centralized configuration with deep merging of user options
- Built-in validation for all configuration values
- Supports dot notation for nested config access (`config.get_value('ui.width')`)
- Default configuration covers ignore patterns, output formatting, UI settings, and clipboard behavior

#### Workspace Management (`services/workspace.lua`)
- Automatically detects project roots using common markers (`.git`, `package.json`, `Makefile`, etc.)
- Manages multiple workspaces and file selection state
- Integrates with file discovery service for scanning directories
- Handles relative path calculation and workspace switching

#### File Node Model (`models/file_node.lua`)
- Tree structure for representing files and directories
- Supports selection state, metadata (size, modified time), and hierarchy traversal
- Provides utility methods for path operations and tree manipulation
- Includes export/import functionality for serialization

### State Management

- Plugin maintains minimal global state in `init.lua`
- Workspace service manages file trees and selection state
- File nodes track their own selection and metadata
- Configuration is global but validated and immutable during runtime

### Testing Architecture

- Uses plenary.nvim as testing framework
- Tests are organized by module (`tests/config_spec.lua`, `tests/models/file_node_spec.lua`)
- Minimal init setup in `tests/minimal_init.lua` handles plenary discovery
- Comprehensive test script (`scripts/test.sh`) with performance monitoring

## Dependencies

### Required Runtime Dependencies
- **plenary.nvim**: Required for file operations and testing framework
- **Neovim 0.8+**: Minimum version requirement

### Development Dependencies
- **StyLua**: Lua code formatter (`cargo install stylua`)
- **Selene**: Lua linter (`cargo install selene`) - configured in `selene.toml`
- **luac**: Lua syntax checker (usually included with Lua)

### Plugin Integration Notes

When adding new functionality:

1. **Follow the layered architecture**: New business logic goes in services, data structures in models
2. **Configuration changes**: Always add validation in `config.lua` and update defaults
3. **State management**: Use the workspace service for file-related state, avoid global state
4. **Testing**: Write tests for new modules following the existing naming pattern (`*_spec.lua`)
5. **Error handling**: Use `vim.validate()` for parameter validation and `pcall()` for error-prone operations

## File Selection Workflow

The plugin's core workflow:
1. **Workspace Detection**: Auto-detects project roots from current buffers and working directory
2. **File Discovery**: Scans workspace respecting gitignore and custom ignore patterns
3. **Selection Management**: Tracks selected files using file node objects
4. **Context Generation**: Creates structured output with configurable templates
5. **Clipboard Integration**: Copies generated context to system clipboard

## Testing Conventions

- Test files must end with `_spec.lua`
- Use plenary's `describe` and `it` blocks for test organization
- Reset plugin state between tests using `_reset_state()` methods
- Mock external dependencies when necessary
- Test both success and error paths for critical functions

## Performance Considerations

- File scanning is cached per workspace (refresh with `force_refresh` parameter)
- Large files are subject to `max_file_size_kb` limit (default 1MB)
- Plugin load time is monitored in test runs (target <100ms)
- Use lazy loading for services that aren't immediately needed
