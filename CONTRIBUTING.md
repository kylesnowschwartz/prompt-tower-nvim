# Contributing to prompt-tower.nvim

Thank you for your interest in contributing to prompt-tower.nvim!

## Development Setup

### Requirements

**Runtime:**
- Neovim 0.8+

**Development/Testing:**
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) for the testing framework

### Development Dependencies

- **StyLua**: Lua code formatter (`cargo install stylua`)
- **Selene**: Lua linter (`cargo install selene`) - configured in `selene.toml`
- **luac**: Lua syntax checker (usually included with Lua)

### Running Tests

```bash
# Run all tests
make test

# Run specific test file
make test-file FILE=tests/config_spec.lua

# Check syntax and style
make lint

# Format code
make format

# Run all CI checks
make ci
```

## Project Structure

```
prompt-tower-nvim/
├── lua/prompt-tower/
│   ├── init.lua              # Main entry point
│   ├── config.lua            # Configuration management
│   ├── services/             # Business logic
│   │   ├── file_discovery.lua    # File scanning and filtering
│   │   ├── template_engine.lua   # Context generation
│   │   ├── tree_generator.lua    # Project tree creation
│   │   ├── ui.lua               # User interface
│   │   └── workspace.lua        # Workspace management
│   └── models/               # Data structures
│       └── file_node.lua         # File tree node model
├── plugin/prompt-tower.lua   # Plugin registration
├── tests/                    # Comprehensive test suite
└── Makefile                  # Development tasks
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

## Development Guidelines

### Adding New Functionality

When adding new functionality:

1. **Follow the layered architecture**: New business logic goes in services, data structures in models
2. **Configuration changes**: Always add validation in `config.lua` and update defaults
3. **State management**: Use the workspace service for file-related state, avoid global state
4. **Testing**: Write tests for new modules following the existing naming pattern (`*_spec.lua`)
5. **Error handling**: Use `vim.validate()` for parameter validation and `pcall()` for error-prone operations

### Testing Conventions

- Test files must end with `_spec.lua`
- Use plenary's `describe` and `it` blocks for test organization
- Reset plugin state between tests using `_reset_state()` methods
- Mock external dependencies when necessary
- Test both success and error paths for critical functions

### Performance Considerations

- File scanning is cached per workspace (refresh with `force_refresh` parameter)
- Large files are subject to `max_file_size_kb` limit (default 500KB)
- Plugin load time is monitored in test runs (target <100ms)
- Use lazy loading for services that aren't immediately needed

## Contributing Process

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Run tests (`make test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Commit Conventions

We use conventional commits:

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `style:` - Code style changes (formatting, etc.)
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests
- `perf:` - Performance improvements

## Code Style

- Follow the existing code style in the project
- Use StyLua for formatting (`make format`)
- Run Selene for linting (`make lint`)
- Write clear, descriptive function and variable names
- Add comments for complex logic

## Questions?

Feel free to open an issue for questions about contributing or architecture decisions.
