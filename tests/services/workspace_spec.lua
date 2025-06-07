-- tests/services/workspace_spec.lua
-- Tests for the workspace service directory selection functionality

local FileNode = require('prompt-tower.models.file_node')
local workspace = require('prompt-tower.services.workspace')

describe('workspace directory selection', function()
  local test_workspace = '/tmp/test_workspace'
  local mock_tree

  before_each(function()
    -- Reset workspace state
    workspace._reset_state()
    workspace.setup()

    -- Create mock file tree structure:
    -- test_workspace/
    --   file1.txt
    --   src/
    --     file2.js
    --     utils/
    --       file3.js
    --   docs/
    --     file4.md
    mock_tree = FileNode.new({ path = test_workspace, type = FileNode.TYPE.DIRECTORY })

    local file1 = FileNode.new({ path = test_workspace .. '/file1.txt' })
    local src_dir = FileNode.new({ path = test_workspace .. '/src', type = FileNode.TYPE.DIRECTORY })
    local file2 = FileNode.new({ path = test_workspace .. '/src/file2.js' })
    local utils_dir = FileNode.new({ path = test_workspace .. '/src/utils', type = FileNode.TYPE.DIRECTORY })
    local file3 = FileNode.new({ path = test_workspace .. '/src/utils/file3.js' })
    local docs_dir = FileNode.new({ path = test_workspace .. '/docs', type = FileNode.TYPE.DIRECTORY })
    local file4 = FileNode.new({ path = test_workspace .. '/docs/file4.md' })

    mock_tree:add_child(file1)
    mock_tree:add_child(src_dir)
    mock_tree:add_child(docs_dir)
    src_dir:add_child(file2)
    src_dir:add_child(utils_dir)
    utils_dir:add_child(file3)
    docs_dir:add_child(file4)

    -- Mock the workspace state with our test tree
    local state = workspace._get_state()
    state.current_workspace = test_workspace
    state.workspaces = { test_workspace }
    state.file_trees = { [test_workspace] = mock_tree }
    state.workspaces_detected = true -- Prevent lazy detection from overriding mocks
  end)

  after_each(function()
    workspace._reset_state()
  end)

  describe('select_directory_recursive', function()
    it('should select all files in directory recursively', function()
      local success = workspace.select_directory_recursive(test_workspace .. '/src')

      assert.is_true(success)
      assert.is_true(workspace.is_file_selected(test_workspace .. '/src/file2.js'))
      assert.is_true(workspace.is_file_selected(test_workspace .. '/src/utils/file3.js'))
      assert.is_false(workspace.is_file_selected(test_workspace .. '/file1.txt'))
      assert.is_false(workspace.is_file_selected(test_workspace .. '/docs/file4.md'))
    end)

    it('should select all files in root directory', function()
      local success = workspace.select_directory_recursive(test_workspace)

      assert.is_true(success)
      assert.is_true(workspace.is_file_selected(test_workspace .. '/file1.txt'))
      assert.is_true(workspace.is_file_selected(test_workspace .. '/src/file2.js'))
      assert.is_true(workspace.is_file_selected(test_workspace .. '/src/utils/file3.js'))
      assert.is_true(workspace.is_file_selected(test_workspace .. '/docs/file4.md'))
    end)

    it('should return false for non-existent directory', function()
      local success = workspace.select_directory_recursive('/non/existent/path')
      assert.is_false(success)
    end)

    it('should return false for file path (not directory)', function()
      local success = workspace.select_directory_recursive(test_workspace .. '/file1.txt')
      assert.is_false(success)
    end)

    it('should handle empty directories', function()
      local empty_dir = FileNode.new({ path = test_workspace .. '/empty', type = FileNode.TYPE.DIRECTORY })
      mock_tree:add_child(empty_dir)

      local success = workspace.select_directory_recursive(test_workspace .. '/empty')
      assert.is_true(success)
      -- No files to select, but operation should succeed
    end)
  end)

  describe('deselect_directory_recursive', function()
    it('should deselect all files in directory recursively', function()
      -- First select all files in src
      workspace.select_directory_recursive(test_workspace .. '/src')

      -- Then deselect them
      local success = workspace.deselect_directory_recursive(test_workspace .. '/src')

      assert.is_true(success)
      assert.is_false(workspace.is_file_selected(test_workspace .. '/src/file2.js'))
      assert.is_false(workspace.is_file_selected(test_workspace .. '/src/utils/file3.js'))
    end)

    it('should only deselect files in target directory', function()
      -- Select files in both src and docs
      workspace.select_directory_recursive(test_workspace .. '/src')
      workspace.select_directory_recursive(test_workspace .. '/docs')

      -- Deselect only src
      workspace.deselect_directory_recursive(test_workspace .. '/src')

      assert.is_false(workspace.is_file_selected(test_workspace .. '/src/file2.js'))
      assert.is_false(workspace.is_file_selected(test_workspace .. '/src/utils/file3.js'))
      assert.is_true(workspace.is_file_selected(test_workspace .. '/docs/file4.md'))
    end)

    it('should return false for non-existent directory', function()
      local success = workspace.deselect_directory_recursive('/non/existent/path')
      assert.is_false(success)
    end)

    it('should return false for file path (not directory)', function()
      local success = workspace.deselect_directory_recursive(test_workspace .. '/file1.txt')
      assert.is_false(success)
    end)
  end)

  describe('toggle_directory_selection', function()
    it('should select all when directory is unselected', function()
      local result = workspace.toggle_directory_selection(test_workspace .. '/src')

      assert.is_true(result)
      assert.is_true(workspace.is_file_selected(test_workspace .. '/src/file2.js'))
      assert.is_true(workspace.is_file_selected(test_workspace .. '/src/utils/file3.js'))
    end)

    it('should deselect all when directory is fully selected', function()
      -- First select all
      workspace.select_directory_recursive(test_workspace .. '/src')

      -- Then toggle (should deselect)
      local result = workspace.toggle_directory_selection(test_workspace .. '/src')

      assert.is_false(result)
      assert.is_false(workspace.is_file_selected(test_workspace .. '/src/file2.js'))
      assert.is_false(workspace.is_file_selected(test_workspace .. '/src/utils/file3.js'))
    end)

    it('should select all when directory is partially selected', function()
      -- Select only one file in src directory
      workspace.select_file(test_workspace .. '/src/file2.js')

      -- Toggle should select all files in directory
      local result = workspace.toggle_directory_selection(test_workspace .. '/src')

      assert.is_true(result)
      assert.is_true(workspace.is_file_selected(test_workspace .. '/src/file2.js'))
      assert.is_true(workspace.is_file_selected(test_workspace .. '/src/utils/file3.js'))
    end)

    it('should return false for non-existent directory', function()
      local result = workspace.toggle_directory_selection('/non/existent/path')
      assert.is_false(result)
    end)

    it('should return false for file path (not directory)', function()
      local result = workspace.toggle_directory_selection(test_workspace .. '/file1.txt')
      assert.is_false(result)
    end)
  end)

  describe('get_directory_selection_state', function()
    it('should return "none" when no files are selected', function()
      local state = workspace.get_directory_selection_state(test_workspace .. '/src')
      assert.equals('none', state)
    end)

    it('should return "all" when all files are selected', function()
      workspace.select_directory_recursive(test_workspace .. '/src')

      local state = workspace.get_directory_selection_state(test_workspace .. '/src')
      assert.equals('all', state)
    end)

    it('should return "partial" when some files are selected', function()
      workspace.select_file(test_workspace .. '/src/file2.js')
      -- file3.js remains unselected

      local state = workspace.get_directory_selection_state(test_workspace .. '/src')
      assert.equals('partial', state)
    end)

    it('should return "not_found" for non-existent directory', function()
      local state = workspace.get_directory_selection_state('/non/existent/path')
      assert.equals('not_found', state)
    end)

    it('should handle nested directory states correctly', function()
      -- Select one file in utils subdirectory
      workspace.select_file(test_workspace .. '/src/utils/file3.js')

      local utils_state = workspace.get_directory_selection_state(test_workspace .. '/src/utils')
      local src_state = workspace.get_directory_selection_state(test_workspace .. '/src')
      local root_state = workspace.get_directory_selection_state(test_workspace)

      assert.equals('all', utils_state) -- utils has all its files selected
      assert.equals('partial', src_state) -- src has some files selected
      assert.equals('partial', root_state) -- root has some files selected
    end)

    it('should handle empty directories', function()
      local empty_dir = FileNode.new({ path = test_workspace .. '/empty', type = FileNode.TYPE.DIRECTORY })
      mock_tree:add_child(empty_dir)

      local state = workspace.get_directory_selection_state(test_workspace .. '/empty')
      assert.equals('none', state)
    end)
  end)

  describe('integration with existing selection methods', function()
    it('should work correctly with individual file selection', function()
      -- Mix directory and individual file selection
      workspace.select_directory_recursive(test_workspace .. '/docs')
      workspace.select_file(test_workspace .. '/file1.txt')

      assert.is_true(workspace.is_file_selected(test_workspace .. '/file1.txt'))
      assert.is_true(workspace.is_file_selected(test_workspace .. '/docs/file4.md'))
      assert.is_false(workspace.is_file_selected(test_workspace .. '/src/file2.js'))

      -- Check selection count
      assert.equals(2, workspace.get_selection_count())
    end)

    it('should maintain selection consistency when clearing', function()
      workspace.select_directory_recursive(test_workspace)
      assert.equals(4, workspace.get_selection_count())

      workspace.clear_selections()
      assert.equals(0, workspace.get_selection_count())

      -- Verify all directory states are now 'none'
      assert.equals('none', workspace.get_directory_selection_state(test_workspace))
      assert.equals('none', workspace.get_directory_selection_state(test_workspace .. '/src'))
      assert.equals('none', workspace.get_directory_selection_state(test_workspace .. '/docs'))
    end)

    it('should handle overlapping directory selections correctly', function()
      -- Select root directory (all files)
      workspace.select_directory_recursive(test_workspace)

      -- Then deselect a subdirectory
      workspace.deselect_directory_recursive(test_workspace .. '/src')

      assert.is_true(workspace.is_file_selected(test_workspace .. '/file1.txt'))
      assert.is_false(workspace.is_file_selected(test_workspace .. '/src/file2.js'))
      assert.is_false(workspace.is_file_selected(test_workspace .. '/src/utils/file3.js'))
      assert.is_true(workspace.is_file_selected(test_workspace .. '/docs/file4.md'))

      assert.equals('partial', workspace.get_directory_selection_state(test_workspace))
      assert.equals('none', workspace.get_directory_selection_state(test_workspace .. '/src'))
      assert.equals('all', workspace.get_directory_selection_state(test_workspace .. '/docs'))
    end)
  end)
end)
