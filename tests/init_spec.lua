-- tests/init_spec.lua
-- Tests for the main init module

local prompt_tower = require('prompt-tower')

describe('prompt-tower.init', function()
  before_each(function()
    -- Reset state before each test
    prompt_tower._reset_state()
  end)

  describe('setup', function()
    it('should initialize successfully with default options', function()
      local success = prompt_tower.setup()
      assert.is_true(success)

      local state = prompt_tower._get_state()
      assert.is_true(state.initialized)
    end)

    it('should initialize successfully with custom options', function()
      local success = prompt_tower.setup({
        max_file_size_kb = 512,
        ui = { title = 'Custom Prompt Tower' },
      })
      assert.is_true(success)
    end)

    it('should validate setup options', function()
      assert.has_error(function()
        prompt_tower.setup('invalid_options')
      end)
    end)
  end)

  describe('select_current_file', function()
    it('should auto-initialize if not setup', function()
      -- Don't call setup first
      local state_before = prompt_tower._get_state()
      assert.is_false(state_before.initialized)

      -- Create a test buffer with a file
      local buf = vim.api.nvim_create_buf(false, false)
      vim.api.nvim_buf_set_name(buf, '/tmp/test_file.txt')
      vim.api.nvim_set_current_buf(buf)

      prompt_tower.select_current_file()

      local state_after = prompt_tower._get_state()
      assert.is_true(state_after.initialized)
    end)

    it('should add current file to selection', function()
      prompt_tower.setup()

      -- Create a test buffer with a file
      local buf = vim.api.nvim_create_buf(false, false)
      vim.api.nvim_buf_set_name(buf, '/tmp/test_file.txt')
      vim.api.nvim_set_current_buf(buf)

      prompt_tower.select_current_file()

      local state = prompt_tower._get_state()
      assert.is_true(state.selected_files['/tmp/test_file.txt'])
    end)

    it('should handle empty buffer name gracefully', function()
      prompt_tower.setup()

      -- Create a buffer without a name
      local buf = vim.api.nvim_create_buf(false, false)
      vim.api.nvim_set_current_buf(buf)

      -- Should not error, but should show warning
      assert.has_no_error(function()
        prompt_tower.select_current_file()
      end)

      local state = prompt_tower._get_state()
      assert.equals(0, vim.tbl_count(state.selected_files))
    end)
  end)

  describe('toggle_selection', function()
    before_each(function()
      prompt_tower.setup()
    end)

    it('should add file when not selected', function()
      prompt_tower.toggle_selection('/tmp/test.txt')

      local state = prompt_tower._get_state()
      assert.is_true(state.selected_files['/tmp/test.txt'])
    end)

    it('should remove file when already selected', function()
      -- First add the file
      prompt_tower.toggle_selection('/tmp/test.txt')
      local state = prompt_tower._get_state()
      assert.is_true(state.selected_files['/tmp/test.txt'])

      -- Then remove it
      prompt_tower.toggle_selection('/tmp/test.txt')
      state = prompt_tower._get_state()
      assert.is_nil(state.selected_files['/tmp/test.txt'])
    end)

    it('should use current file when no filepath provided', function()
      -- Create a test buffer
      local buf = vim.api.nvim_create_buf(false, false)
      vim.api.nvim_buf_set_name(buf, '/tmp/current_file.txt')
      vim.api.nvim_set_current_buf(buf)

      prompt_tower.toggle_selection()

      local state = prompt_tower._get_state()
      assert.is_true(state.selected_files['/tmp/current_file.txt'])
    end)
  end)

  describe('clear_selection', function()
    it('should remove all selected files', function()
      prompt_tower.setup()

      -- Add some files
      prompt_tower.toggle_selection('/tmp/file1.txt')
      prompt_tower.toggle_selection('/tmp/file2.txt')

      local state = prompt_tower._get_state()
      assert.equals(2, vim.tbl_count(state.selected_files))

      -- Clear selection
      prompt_tower.clear_selection()

      state = prompt_tower._get_state()
      assert.equals(0, vim.tbl_count(state.selected_files))
    end)
  end)

  describe('generate_context', function()
    before_each(function()
      prompt_tower.setup()

      -- Mock file reading for testing
      prompt_tower._read_file = function(filepath)
        if filepath == '/tmp/test1.txt' then
          return 'Content of test1'
        elseif filepath == '/tmp/test2.txt' then
          return 'Content of test2'
        end
        return nil
      end
    end)

    it('should generate context for selected files', function()
      -- Add some files
      prompt_tower.toggle_selection('/tmp/test1.txt')
      prompt_tower.toggle_selection('/tmp/test2.txt')

      prompt_tower.generate_context()

      local state = prompt_tower._get_state()
      assert.is_not_nil(state.last_context)
      assert.is_true(string.find(state.last_context, 'Content of test1') ~= nil)
      assert.is_true(string.find(state.last_context, 'Content of test2') ~= nil)
    end)

    it('should warn when no files selected', function()
      -- Don't add any files
      assert.has_no_error(function()
        prompt_tower.generate_context()
      end)

      local state = prompt_tower._get_state()
      assert.is_nil(state.last_context)
    end)

    it('should include proper XML structure', function()
      prompt_tower.toggle_selection('/tmp/test1.txt')
      prompt_tower.generate_context()

      local state = prompt_tower._get_state()
      assert.is_true(string.find(state.last_context, '<file path="/tmp/test1.txt">') ~= nil)
      assert.is_true(string.find(state.last_context, '</file>') ~= nil)
    end)
  end)

  describe('_read_file', function()
    it('should return nil for non-existent files', function()
      local content = prompt_tower._read_file('/non/existent/file.txt')
      assert.is_nil(content)
    end)
  end)

  describe('_get_state', function()
    it('should return current internal state', function()
      local state = prompt_tower._get_state()
      assert.is_table(state)
      assert.is_boolean(state.initialized)
      assert.is_table(state.selected_files)
    end)
  end)

  describe('_reset_state', function()
    it('should reset to initial state', function()
      prompt_tower.setup()
      prompt_tower.toggle_selection('/tmp/test.txt')

      local state_before = prompt_tower._get_state()
      assert.is_true(state_before.initialized)
      assert.equals(1, vim.tbl_count(state_before.selected_files))

      prompt_tower._reset_state()

      local state_after = prompt_tower._get_state()
      assert.is_false(state_after.initialized)
      assert.equals(0, vim.tbl_count(state_after.selected_files))
    end)
  end)
end)
