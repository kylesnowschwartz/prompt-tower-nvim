-- tests/helpers.lua
-- Shared test utilities and helpers to reduce code duplication

local FileNode = require('prompt-tower.models.file_node')

local M = {}

-- Test constants to replace magic strings
M.TEST_PATHS = {
  workspace = '/tmp/test_workspace',
  test_file = '/test/file.txt',
  test_dir = '/test/dir',
  readme = 'README.md',
  makefile = 'Makefile',
}

-- Common module setup utilities
M.setup = {}

function M.setup.reset_all_modules()
  local config = require('prompt-tower.config')
  local workspace = require('prompt-tower.services.workspace')
  local ui = require('prompt-tower.services.ui')

  config.reset()
  workspace._reset_state()
  ui._reset_state()
end

function M.setup.reset_config()
  local config = require('prompt-tower.config')
  config.reset()
end

function M.setup.reset_workspace()
  local workspace = require('prompt-tower.services.workspace')
  workspace._reset_state()
  workspace.setup()
end

function M.setup.reset_ui()
  local ui = require('prompt-tower.services.ui')
  workspace = require('prompt-tower.services.workspace')
  ui._reset_state()
  workspace._reset_state()
end

-- Mock creation factories
M.mocks = {}

function M.mocks.create_file_node(opts)
  opts = opts or {}
  return FileNode.new({
    path = opts.path or M.TEST_PATHS.test_file,
    name = opts.name or 'file.txt',
    type = opts.type or FileNode.TYPE.FILE,
  })
end

function M.mocks.create_dir_node(opts)
  opts = opts or {}
  return FileNode.new({
    path = opts.path or M.TEST_PATHS.test_dir,
    name = opts.name or 'dir',
    type = FileNode.TYPE.DIRECTORY,
  })
end

function M.mocks.create_empty_dir(path, name)
  return FileNode.new({
    path = path,
    name = name or 'empty',
    type = FileNode.TYPE.DIRECTORY,
  })
end

function M.mocks.create_workspace_tree(workspace_path)
  workspace_path = workspace_path or M.TEST_PATHS.workspace

  -- Create standard test workspace structure:
  -- workspace/
  --   file1.txt
  --   src/
  --     file2.js
  --     utils/
  --       file3.js
  --   docs/
  --     file4.md

  local root = FileNode.new({
    path = workspace_path,
    type = FileNode.TYPE.DIRECTORY,
  })

  local file1 = FileNode.new({ path = workspace_path .. '/file1.txt' })
  local src_dir = FileNode.new({
    path = workspace_path .. '/src',
    type = FileNode.TYPE.DIRECTORY,
  })
  local file2 = FileNode.new({ path = workspace_path .. '/src/file2.js' })
  local utils_dir = FileNode.new({
    path = workspace_path .. '/src/utils',
    type = FileNode.TYPE.DIRECTORY,
  })
  local file3 = FileNode.new({ path = workspace_path .. '/src/utils/file3.js' })
  local docs_dir = FileNode.new({
    path = workspace_path .. '/docs',
    type = FileNode.TYPE.DIRECTORY,
  })
  local file4 = FileNode.new({ path = workspace_path .. '/docs/file4.md' })

  root:add_child(file1)
  root:add_child(src_dir)
  root:add_child(docs_dir)
  src_dir:add_child(file2)
  src_dir:add_child(utils_dir)
  utils_dir:add_child(file3)
  docs_dir:add_child(file4)

  return root
end

function M.mocks.setup_workspace_state(tree, workspace_path)
  workspace_path = workspace_path or M.TEST_PATHS.workspace

  local workspace = require('prompt-tower.services.workspace')
  local state = workspace._get_state()
  state.current_workspace = workspace_path
  state.workspaces = { workspace_path }
  state.file_trees = { [workspace_path] = tree }
  state.workspaces_detected = true -- Prevent lazy detection from overriding mocks
end

-- File system utilities for tests
M.fs = {}

function M.fs.get_real_workspace_file(filename)
  return vim.fn.getcwd() .. '/' .. filename
end

function M.fs.create_test_buffer(filepath)
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(buf, filepath)
  vim.api.nvim_set_current_buf(buf)
  return buf
end

-- Assertion helpers
M.assert = {}

function M.assert.file_selected(workspace_service, filepath)
  assert.is_true(
    workspace_service.is_file_selected(filepath),
    string.format('Expected file %s to be selected', filepath)
  )
end

function M.assert.file_not_selected(workspace_service, filepath)
  assert.is_false(
    workspace_service.is_file_selected(filepath),
    string.format('Expected file %s to not be selected', filepath)
  )
end

function M.assert.selection_count(workspace_service, expected_count)
  local actual_count = workspace_service.get_selection_count()
  assert.equals(
    expected_count,
    actual_count,
    string.format('Expected %d selected files, got %d', expected_count, actual_count)
  )
end

return M
