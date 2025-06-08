-- tests/health_spec.lua
-- Tests for health check functionality

local health = require('prompt-tower.health')

describe('prompt-tower.health', function()
  describe('check', function()
    it('should run health check without errors', function()
      -- This test ensures the health check function can be called without crashing
      -- We can't easily test the vim.health output in this test environment,
      -- but we can ensure the function doesn't error
      assert.has_no.errors(function()
        health.check()
      end)
    end)

    it('should load all required modules during health check', function()
      -- Ensure that health check can load all the modules it checks
      local config = require('prompt-tower.config')
      local workspace = require('prompt-tower.services.workspace')
      local file_discovery = require('prompt-tower.services.file_discovery')
      local template_engine = require('prompt-tower.services.template_engine')

      assert.is_not.Nil(config)
      assert.is_not.Nil(workspace)
      assert.is_not.Nil(file_discovery)
      assert.is_not.Nil(template_engine)
    end)

    it('should verify config module has is_initialized method', function()
      local config = require('prompt-tower.config')
      assert.is_function(config.is_initialized)

      -- Test that it returns a boolean
      local result = config.is_initialized()
      assert.is_boolean(result)
    end)

    it('should verify workspace module has required methods', function()
      local workspace = require('prompt-tower.services.workspace')
      assert.is_function(workspace.get_current_workspace)
    end)

    it('should verify config module has required methods for health check', function()
      local config = require('prompt-tower.config')
      assert.is_function(config.get_available_formats)

      -- Test that it returns a table
      local formats = config.get_available_formats()
      assert.is_table(formats)
      assert.is_true(#formats > 0) -- Should have at least one format
    end)
  end)
end)
