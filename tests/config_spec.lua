-- tests/config_spec.lua
-- Tests for the configuration module

local config = require('prompt-tower.config')
local helpers = require('tests.helpers')

describe('prompt-tower.config', function()
  before_each(function()
    helpers.setup.reset_config()
  end)

  describe('setup', function()
    it('should accept empty options', function()
      assert.has_no_error(function()
        config.setup({})
      end)
    end)

    it('should accept nil options', function()
      assert.has_no_error(function()
        config.setup()
      end)
    end)

    it('should merge user options with defaults', function()
      config.setup({
        max_file_size_kb = 2048,
        ui = {
          title = 'Custom Title',
        },
      })

      local cfg = config.get()
      assert.equals(2048, cfg.max_file_size_kb)
      assert.equals('Custom Title', cfg.ui.title)
      -- Should preserve other defaults
      assert.equals(true, cfg.use_gitignore)
    end)

    it('should validate invalid options', function()
      assert.has_error(function()
        config.setup({ ignore_patterns = 'not_a_table' })
      end)
    end)
  end)

  describe('get_value', function()
    it('should return top-level values', function()
      local value = config.get_value('use_gitignore')
      assert.equals(true, value)
    end)

    it('should return nested values with dot notation', function()
      local value = config.get_value('clipboard.register')
      assert.equals('+', value)
    end)

    it('should return nil for non-existent keys', function()
      local value = config.get_value('non.existent.key')
      assert.is_nil(value)
    end)

    it('should validate key parameter', function()
      assert.has_error(function()
        config.get_value(123)
      end)
    end)
  end)

  describe('set_value', function()
    it('should set top-level values', function()
      config.set_value('use_gitignore', false)
      assert.equals(false, config.get_value('use_gitignore'))
    end)

    it('should set nested values with dot notation', function()
      config.set_value('ui.title', 'New Title')
      assert.equals('New Title', config.get_value('ui.title'))
    end)

    it('should create missing nested structure', function()
      config.set_value('new.nested.value', 'test')
      assert.equals('test', config.get_value('new.nested.value'))
    end)

    it('should validate the updated configuration', function()
      assert.has_error(function()
        config.set_value('max_file_size_kb', -1)
      end)
    end)
  end)

  describe('validate', function()
    it('should pass with default configuration', function()
      assert.is_true(config.validate())
    end)

    it('should fail with invalid ignore_patterns', function()
      assert.has_error(function()
        config.set_value('ignore_patterns', 'not_a_table')
      end)
    end)

    it('should fail with negative max_file_size_kb', function()
      assert.has_error(function()
        config.setup({ max_file_size_kb = -1 })
      end)
    end)

    it('should fail with invalid UI dimensions', function()
      assert.has_error(function()
        config.setup({ ui = { width = 1.5 } })
      end)

      assert.has_error(function()
        config.setup({ ui = { height = -0.1 } })
      end)
    end)

    it('should fail with invalid clipboard register', function()
      assert.has_error(function()
        config.setup({ clipboard = { register = 'invalid!' } })
      end)
    end)
  end)

  describe('get_defaults', function()
    it('should return a copy of defaults', function()
      local defaults1 = config.get_defaults()
      local defaults2 = config.get_defaults()

      -- Should be equal but not the same reference
      assert.are.same(defaults1, defaults2)
      assert.are_not.equal(defaults1, defaults2)
    end)

    it('should not affect current config when modified', function()
      local defaults = config.get_defaults()
      defaults.use_gitignore = false

      -- Current config should remain unchanged
      assert.equals(true, config.get_value('use_gitignore'))
    end)
  end)

  describe('reset', function()
    it('should restore defaults', function()
      config.set_value('use_gitignore', false)
      config.set_value('clipboard.register', '*')

      config.reset()

      assert.equals(true, config.get_value('use_gitignore'))
      assert.equals('+', config.get_value('clipboard.register'))
    end)
  end)

  describe('export', function()
    it('should return a string representation', function()
      local exported = config.export()
      assert.is_string(exported)
      assert.is_true(string.len(exported) > 0)
    end)
  end)

  describe('file discovery configuration regression tests', function()
    it('should have include_hidden enabled by default', function()
      config.setup()

      local include_hidden = config.get_value('file_discovery.include_hidden')
      assert.equals(true, include_hidden)
    end)

    it('should have max_depth configured in file_discovery section', function()
      config.setup()

      local max_depth = config.get_value('file_discovery.max_depth')
      assert.equals(10, max_depth)
    end)

    it('should use specific .git pattern that only matches exact .git directory', function()
      config.setup()

      local ignore_patterns = config.get_value('ignore_patterns')
      assert.is_true(vim.tbl_contains(ignore_patterns, '^%.git$'))

      -- Should not contain the old broad pattern
      assert.is_false(vim.tbl_contains(ignore_patterns, '.git'))
    end)

    it('should allow customization of file_discovery settings', function()
      config.setup({
        file_discovery = {
          include_hidden = false,
          max_depth = 5,
        },
      })

      assert.equals(false, config.get_value('file_discovery.include_hidden'))
      assert.equals(5, config.get_value('file_discovery.max_depth'))
    end)
  end)
end)
