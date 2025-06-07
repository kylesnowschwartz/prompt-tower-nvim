-- tests/services/ui_spec.lua
-- Tests for the UI service

local FileNode = require('prompt-tower.models.file_node')
local ui = require('prompt-tower.services.ui')
local workspace = require('prompt-tower.services.workspace')

describe('UI service', function()
  before_each(function()
    -- Reset UI state before each test
    ui._reset_state()
    workspace._reset_state()
  end)

  describe('tree_select_file', function()
    local mock_tree_window
    local file_node, dir_node
    local original_win_get_cursor, original_win_is_valid

    before_each(function()
      -- Create mock nodes
      file_node = FileNode.new({
        path = '/test/file.txt',
        name = 'file.txt',
        type = FileNode.TYPE.FILE,
      })

      dir_node = FileNode.new({
        path = '/test/dir',
        name = 'dir',
        type = FileNode.TYPE.DIRECTORY,
      })

      -- Mock window handle
      mock_tree_window = 123

      -- Store original functions
      original_win_get_cursor = vim.api.nvim_win_get_cursor
      original_win_is_valid = vim.api.nvim_win_is_valid

      -- Mock vim.api functions
      vim.api.nvim_win_get_cursor = function(win)
        if win == mock_tree_window then
          return { 2, 0 } -- Cursor on line 2
        end
        return { 1, 0 }
      end

      vim.api.nvim_win_is_valid = function(win)
        return win == mock_tree_window
      end

      -- Set up UI state with mock data
      local state = ui._get_state()
      state.windows.tree = mock_tree_window
      state.tree_lines = {
        {
          text = ' 📁 dir',
          node = dir_node,
          depth = 1,
          is_directory = true,
          is_selected = false,
        },
        {
          text = ' 📄 file.txt',
          node = file_node,
          depth = 1,
          is_directory = false,
          is_selected = false,
        },
      }
      state.cursor_line = 1 -- Initially out of sync
    end)

    after_each(function()
      -- Restore original functions
      vim.api.nvim_win_get_cursor = original_win_get_cursor
      vim.api.nvim_win_is_valid = original_win_is_valid
    end)

    it('should sync cursor position and select files', function()
      -- Spy on workspace.toggle_file_selection
      local toggle_called = false
      local toggle_path = nil
      local original_toggle = workspace.toggle_file_selection
      workspace.toggle_file_selection = function(path)
        toggle_called = true
        toggle_path = path
        return true
      end

      -- Mock refresh functions to avoid UI operations
      local refresh_tree_called = false
      local refresh_selection_called = false
      local original_refresh_tree = ui.refresh_tree
      local original_refresh_selection = ui.refresh_selection
      ui.refresh_tree = function()
        refresh_tree_called = true
      end
      ui.refresh_selection = function()
        refresh_selection_called = true
      end

      -- Call tree_select_file (cursor should be on line 2 = file.txt)
      ui.tree_select_file()

      -- Verify cursor position was synced
      local state = ui._get_state()
      assert.equals(2, state.cursor_line)

      -- Verify file selection was called
      assert.is_true(toggle_called)
      assert.equals('/test/file.txt', toggle_path)

      -- Verify UI was refreshed
      assert.is_true(refresh_tree_called)
      assert.is_true(refresh_selection_called)

      -- Restore functions
      workspace.toggle_file_selection = original_toggle
      ui.refresh_tree = original_refresh_tree
      ui.refresh_selection = original_refresh_selection
    end)

    it('should sync cursor position and toggle directories', function()
      -- Mock cursor to be on line 1 (directory)
      vim.api.nvim_win_get_cursor = function(win)
        if win == mock_tree_window then
          return { 1, 0 } -- Cursor on line 1 (directory)
        end
        return { 1, 0 }
      end

      -- Mock refresh_tree to avoid UI operations
      local refresh_tree_called = false
      local original_refresh_tree = ui.refresh_tree
      ui.refresh_tree = function()
        refresh_tree_called = true
      end

      -- Directory should start unexpanded
      assert.is_falsy(dir_node.expanded)

      -- Call tree_select_file (cursor should be on line 1 = dir)
      ui.tree_select_file()

      -- Verify cursor position was synced
      local state = ui._get_state()
      assert.equals(1, state.cursor_line)

      -- Verify directory was expanded
      assert.is_true(dir_node.expanded)

      -- Verify UI was refreshed
      assert.is_true(refresh_tree_called)

      -- Restore function
      ui.refresh_tree = original_refresh_tree
    end)

    it('should handle empty tree gracefully', function()
      -- Set up empty tree
      local state = ui._get_state()
      state.tree_lines = {}

      -- Should not error when tree is empty
      assert.has_no_error(function()
        ui.tree_select_file()
      end)
    end)

    it('should handle cursor beyond tree bounds', function()
      -- Mock cursor to be beyond tree bounds
      vim.api.nvim_win_get_cursor = function(win)
        if win == mock_tree_window then
          return { 10, 0 } -- Cursor beyond tree_lines length
        end
        return { 1, 0 }
      end

      -- Should not error when cursor is out of bounds
      assert.has_no_error(function()
        ui.tree_select_file()
      end)

      -- Cursor position should still be updated
      local state = ui._get_state()
      assert.equals(10, state.cursor_line)
    end)
  end)

  describe('tree_toggle_folder', function()
    local mock_tree_window
    local dir_node
    local original_win_get_cursor, original_win_is_valid

    before_each(function()
      -- Create mock directory node
      dir_node = FileNode.new({
        path = '/test/dir',
        name = 'dir',
        type = FileNode.TYPE.DIRECTORY,
      })

      -- Mock window handle
      mock_tree_window = 123

      -- Store and mock vim.api functions
      original_win_get_cursor = vim.api.nvim_win_get_cursor
      original_win_is_valid = vim.api.nvim_win_is_valid

      vim.api.nvim_win_get_cursor = function(win)
        if win == mock_tree_window then
          return { 1, 0 } -- Cursor on line 1
        end
        return { 1, 0 }
      end

      vim.api.nvim_win_is_valid = function(win)
        return win == mock_tree_window
      end

      -- Set up UI state
      local state = ui._get_state()
      state.windows.tree = mock_tree_window
      state.tree_lines = {
        {
          text = ' 📁 dir',
          node = dir_node,
          depth = 1,
          is_directory = true,
          is_selected = false,
        },
      }
      state.cursor_line = 2 -- Initially out of sync
    end)

    after_each(function()
      vim.api.nvim_win_get_cursor = original_win_get_cursor
      vim.api.nvim_win_is_valid = original_win_is_valid
    end)

    it('should sync cursor position and toggle directory expansion', function()
      -- Mock refresh_tree to avoid UI operations
      local refresh_tree_called = false
      local original_refresh_tree = ui.refresh_tree
      ui.refresh_tree = function()
        refresh_tree_called = true
      end

      -- Directory should start unexpanded
      assert.is_falsy(dir_node.expanded)

      -- Call tree_toggle_folder
      ui.tree_toggle_folder()

      -- Verify cursor position was synced
      local state = ui._get_state()
      assert.equals(1, state.cursor_line)

      -- Verify directory was expanded
      assert.is_true(dir_node.expanded)

      -- Verify UI was refreshed
      assert.is_true(refresh_tree_called)

      -- Call again to test collapse
      ui.tree_toggle_folder()
      assert.is_false(dir_node.expanded)

      -- Restore function
      ui.refresh_tree = original_refresh_tree
    end)
  end)
end)
