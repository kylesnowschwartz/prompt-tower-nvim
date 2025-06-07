# Prompt Tower Neovim Feature Parity Roadmap

## Executive Summary

Based on our comprehensive analysis, prompt-tower-nvim currently provides ~30% of prompt-tower-vscode's functionality. This roadmap outlines a structured approach to achieve feature parity and add Neovim-specific enhancements.

**Current State**: Basic file selection, simple XML output, single workspace support
**Target State**: Full feature parity with advanced template system, multi-workspace, GitHub integration, plus Neovim-specific enhancements

---

## Phase 1: Foundation

_Core architectural improvements that enable advanced features_

### 🎯 **Primary Goals**

- Establish configurable template system
- Add file tree generation utilities
- Enhance configuration management
- Implement token counting foundation

### 📋 **Features**

#### 1.1 Configurable Template System (HIGH PRIORITY)

**Current**: Fixed `<file path="...">content</file>` format
**Target**: VSCode-style template system with placeholders

**Implementation:**

- **New file**: `lua/prompt-tower/services/template_engine.lua`
- **Modify**: `lua/prompt-tower/config.lua` - Add template configuration schema
- **Modify**: `init.lua` and `ui.lua` - Replace hardcoded formatting

**Templates to support:**

```lua
-- Block template with placeholders
blockTemplate = '<file name="{fileName}" path="{filePath}">\n{fileContent}\n</file>'

-- Wrapper template
wrapperTemplate = '<context>\n{projectTree}{fileBlocks}\n</context>'

-- Placeholders: {fileName}, {filePath}, {fileContent}, {fileExtension}, etc.
```

#### 1.2 File Tree Generation (HIGH PRIORITY)

**Current**: No project tree in output
**Target**: ASCII tree generation like VSCode

**Implementation:**

- **New file**: `lua/prompt-tower/services/tree_generator.lua`
- **New file**: `lua/prompt-tower/utils/ascii_tree.lua`

**Features:**

```lua
-- Three tree types
tree_types = {
  "fullFilesAndDirectories",  -- Complete structure
  "fullDirectoriesOnly",      -- Directories only
  "selectedFilesOnly"         -- Selected files in tree format
}
```

#### 1.3 Enhanced Configuration (MEDIUM PRIORITY)

**Current**: Basic config with limited validation
**Target**: Rich configuration schema like VSCode

**Implementation:**

- **Modify**: `lua/prompt-tower/config.lua` - Add comprehensive schema
- **Add**: Configuration validation and type checking
- **Add**: Runtime configuration updates

#### 1.4 Token Counting Foundation (LOW PRIORITY)

**Current**: No token estimation
**Target**: Basic token counting for prompt optimization

**Implementation:**

- **New file**: `lua/prompt-tower/services/token_counter.lua`
- **Integration**: Show token counts in UI

**Success Criteria**: Template system working, basic tree generation, enhanced config

---

## Phase 2: Enhanced Selection

_Hierarchical selection and multi-workspace support_

### 🎯 **Primary Goals**

- Implement hierarchical file selection with parent-child relationships
- Add multi-workspace support
- Enhance ignore pattern handling
- Improve UI interactions

### 📋 **Features**

#### 2.1 Hierarchical File Selection (HIGH PRIORITY)

**Current**: Simple individual file selection
**Target**: Directory selection auto-selects children, parent state reflects children

**Implementation:**

- **Modify**: `lua/prompt-tower/models/file_node.lua` - Add parent-child selection logic
- **Modify**: `lua/prompt-tower/services/workspace.lua` - Update selection algorithms
- **Modify**: `lua/prompt-tower/services/ui.lua` - Visual selection indicators

**Features:**

- Selecting directory auto-selects all children
- Deselecting child updates parent state
- Visual indicators for partial selection
- Keyboard shortcuts for bulk selection

#### 2.2 Multi-Workspace Support (HIGH PRIORITY)

**Current**: Single workspace focus
**Target**: Handle multiple workspace roots simultaneously

**Implementation:**

- **Modify**: `lua/prompt-tower/services/workspace.lua` - Support workspace list
- **Modify**: `lua/prompt-tower/services/ui.lua` - Multi-workspace tree view
- **New file**: `lua/prompt-tower/services/workspace_manager.lua`

**Features:**

- Detect multiple project roots
- Switch between workspaces
- Unified file selection across workspaces
- Workspace-specific configuration

#### 2.3 Advanced Ignore Patterns (MEDIUM PRIORITY)

**Current**: Basic .gitignore support
**Target**: Sophisticated pattern matching like VSCode

**Implementation:**

- **Modify**: `lua/prompt-tower/services/file_discovery.lua` - Enhanced pattern matching
- **Add**: Support for .towerignore files
- **Add**: Real-time ignore file watching

#### 2.4 File Size Warnings (LOW PRIORITY)

**Current**: No large file detection
**Target**: Warn users about large files that might impact performance

**Implementation:**

- **Add**: File size checking in selection process
- **Add**: User confirmation for large files
- **Add**: Configurable size thresholds

**Success Criteria**: Directory selection works, multi-workspace functional, improved ignore handling

---

## Phase 3: Rich Output

_Advanced prompt generation and formatting_

### 🎯 **Primary Goals**

- Integrate project tree into prompt output
- Implement rich metadata support
- Add advanced formatting options
- Enhance template placeholder system

### 📋 **Features**

#### 3.1 Project Tree Integration (HIGH PRIORITY)

**Current**: No project tree in output
**Target**: Configurable project tree inclusion like VSCode

**Implementation:**

- **Integrate**: tree_generator.lua with template system
- **Add**: Tree type configuration (full/directories/selected)
- **Add**: File size display options

**Output example:**

```xml
<context>
<project_tree>
├── src/
│   ├── components/
│   └── utils/
└── package.json
</project_tree>
<project_files>
<!-- files here -->
</project_files>
</context>
```

#### 3.2 Rich Metadata Placeholders (HIGH PRIORITY)

**Current**: Basic path and content
**Target**: Comprehensive placeholder system

**Implementation:**

- **Extend**: template_engine.lua with full placeholder support
- **Add**: File metadata extraction

**Placeholders:**

- `{fileName}` - filename without extension
- `{fileNameWithExtension}` - full filename
- `{fileExtension}` - file extension
- `{rawFilePath}` - workspace-relative path
- `{fullPath}` - absolute path
- `{fileContent}` - file contents
- `{timestamp}` - generation timestamp
- `{fileCount}` - number of selected files

#### 3.3 Advanced Template Options (MEDIUM PRIORITY)

**Current**: No template customization
**Target**: Full template configurability

**Implementation:**

- **Add**: Block separator configuration
- **Add**: Line trimming options
- **Add**: Wrapper template disable option
- **Add**: Custom template import/export

#### 3.4 Output Validation (LOW PRIORITY)

**Current**: No output validation
**Target**: Validate generated output for common issues

**Implementation:**

- **Add**: XML/template validation
- **Add**: Size limit warnings
- **Add**: Content sanitization options

**Success Criteria**: Project tree in output, rich metadata working, configurable templates

---

## Phase 4: Advanced Features

_GitHub integration and sophisticated capabilities_

### 🎯 **Primary Goals**

- Implement GitHub issues integration
- Add cross-session persistence
- Implement real-time file watching
- Add advanced UI features

### 📋 **Features**

#### 4.1 GitHub Issues Integration (HIGH PRIORITY)

**Current**: No GitHub integration
**Target**: Select and include GitHub issues in prompts

**Implementation:**

- **New file**: `lua/prompt-tower/services/github_client.lua`
- **New file**: `lua/prompt-tower/models/github_issue.lua`
- **Modify**: UI to show GitHub issues tree
- **Add**: Authentication token management

**Features:**

- List repository issues
- Select issues for inclusion
- Rich issue formatting (title, body, comments, metadata)
- Issue search and filtering

**Output format:**

```xml
<github_issue number="123" state="open">
<title>Fix authentication bug</title>
<author>username</author>
<body>Issue description...</body>
<comments>
<comment author="reviewer">Comment text</comment>
</comments>
</github_issue>
```

#### 4.2 Cross-Session Persistence (MEDIUM PRIORITY)

**Current**: No persistence between sessions
**Target**: Save and restore selections across Neovim sessions

**Implementation:**

- **New file**: `lua/prompt-tower/services/persistence.lua`
- **Add**: Selection state serialization
- **Add**: Project-specific persistence
- **Add**: Cleanup of stale persisted data

#### 4.3 Real-time File Watching (MEDIUM PRIORITY)

**Current**: Manual refresh only
**Target**: Auto-refresh when files change

**Implementation:**

- **Add**: File system watching with `vim.loop.fs_event`
- **Add**: Smart refresh (only affected parts)
- **Add**: Debounced updates

#### 4.4 Advanced UI Features (LOW PRIORITY)

**Current**: Basic floating window UI
**Target**: Rich interactive interface

**Implementation:**

- **Add**: Search/filter functionality
- **Add**: Bulk selection operations
- **Add**: Keyboard shortcuts for all operations
- **Add**: Status indicators and progress bars

**Success Criteria**: GitHub integration working, selections persist, auto-refresh functional

---

## Phase 5: Neovim-Specific Enhancements

_Features that go beyond VSCode parity_

### 🎯 **Primary Goals**

- Leverage Neovim's unique capabilities
- Integrate with popular Neovim plugins
- Add terminal-optimized workflows
- Implement LSP integration

### 📋 **Features**

#### 5.1 Telescope Integration (HIGH PRIORITY)

**Current**: Basic file tree navigation
**Target**: Full Telescope.nvim integration for file selection

**Implementation:**

- **New file**: `lua/prompt-tower/telescope/extension.lua`
- **Add**: Custom Telescope picker for files
- **Add**: Multi-select with Telescope
- **Add**: Integration with existing Telescope workflows

#### 5.2 LSP Integration (HIGH PRIORITY)

**Current**: No language server integration
**Target**: Use LSP for intelligent file suggestions

**Implementation:**

- **Add**: LSP-based file relationship detection
- **Add**: Import/dependency-based file suggestions
- **Add**: Related file auto-selection

#### 5.3 Terminal Workflow Optimization (MEDIUM PRIORITY)

**Current**: UI-focused workflow
**Target**: Efficient command-line workflows

**Implementation:**

- **Add**: Command-line file selection with tab completion
- **Add**: Quick selection via file patterns
- **Add**: Integration with vim motions and text objects

#### 5.4 Plugin Ecosystem Integration (LOW PRIORITY)

**Current**: Standalone plugin
**Target**: Integration with other popular Neovim plugins

**Implementation:**

- **Add**: nvim-tree integration
- **Add**: fzf-lua integration
- **Add**: Which-key integration for discoverability
- **Add**: Lualine status integration

**Success Criteria**: Telescope integration working, LSP features functional, optimized workflows

---

## Implementation Strategy

### Development Approach

1. **Test-Driven Development**: Write tests for each new feature before implementation
2. **Incremental Delivery**: Each phase delivers working features that can be used independently
3. **Backward Compatibility**: Maintain existing API while adding new features
4. **Documentation**: Update README and add examples for each new feature

### Risk Mitigation

- **Complexity Risk**: Break large features into smaller, testable components
- **Performance Risk**: Profile and optimize file tree generation for large projects
- **Compatibility Risk**: Test with various Neovim configurations and plugin setups

### Success Metrics

- **Feature Parity**: 95%+ of VSCode features implemented
- **Performance**: <1s startup time, <500ms for tree generation in typical projects
- **User Adoption**: Positive community feedback and increased usage
- **Code Quality**: >90% test coverage, clean architecture

---

## Phase Summary

| Phase   | Key Deliverables                        | Cumulative Progress |
| ------- | --------------------------------------- | ------------------- |
| Phase 1 | Template system, tree generation        | 50%                 |
| Phase 2 | Hierarchical selection, multi-workspace | 70%                 |
| Phase 3 | Rich output, project tree integration   | 85%                 |
| Phase 4 | GitHub integration, persistence         | 95%                 |
| Phase 5 | Neovim-specific enhancements            | 110%                |

This roadmap transforms prompt-tower-nvim from a basic file selection tool into a comprehensive, feature-rich context management system that matches and exceeds the capabilities of the VSCode version while leveraging Neovim's unique strengths.

