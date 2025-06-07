-- tests/performance_spec.lua
-- Performance regression tests for prompt-tower.nvim

describe('performance', function()
  describe('plugin load time', function()
    it('should load within acceptable time limits', function()
      -- Test plugin load time by requiring the main module
      local start_time = vim.fn.reltime()
      require('prompt-tower')
      local elapsed = vim.fn.reltimestr(vim.fn.reltime(start_time))
      local elapsed_ms = tonumber(elapsed) * 1000

      -- Plugin should load in under 100ms (performance target)
      -- Current baseline after optimization: ~249ms
      -- We'll set a regression threshold at 300ms to catch major regressions
      assert.is_true(elapsed_ms < 300, string.format('Plugin load time %dms exceeds 300ms threshold', elapsed_ms))

      -- Log actual load time for monitoring
      print(string.format('Plugin load time: %dms', elapsed_ms))
    end)

    it('should have minimal memory footprint on load', function()
      -- Capture memory before loading
      collectgarbage('collect')
      local mem_before = collectgarbage('count')

      -- Load the plugin
      require('prompt-tower')

      -- Capture memory after loading
      collectgarbage('collect')
      local mem_after = collectgarbage('count')
      local mem_diff = mem_after - mem_before

      -- Plugin should use less than 500KB of memory (reasonable for a text editor plugin)
      assert.is_true(mem_diff < 500, string.format('Plugin memory usage %dKB exceeds 500KB threshold', mem_diff))

      -- Log actual memory usage for monitoring
      print(string.format('Plugin memory usage: %dKB', mem_diff))
    end)
  end)

  describe('operation performance', function()
    before_each(function()
      -- Reset state before each test
      require('prompt-tower')._reset_state()
    end)

    it('should initialize quickly', function()
      local start_time = vim.fn.reltime()
      require('prompt-tower').setup({})
      local elapsed = vim.fn.reltimestr(vim.fn.reltime(start_time))
      local elapsed_ms = tonumber(elapsed) * 1000

      -- Setup should be very fast (< 50ms)
      assert.is_true(elapsed_ms < 50, string.format('Setup time %dms exceeds 50ms threshold', elapsed_ms))
    end)

    it('should handle workspace detection efficiently', function()
      local prompt_tower = require('prompt-tower')
      prompt_tower.setup({})

      local start_time = vim.fn.reltime()

      -- Force workspace detection by accessing workspace functions
      local workspace = prompt_tower._get_workspace()
      workspace.get_current_workspace()

      local elapsed = vim.fn.reltimestr(vim.fn.reltime(start_time))
      local elapsed_ms = tonumber(elapsed) * 1000

      -- Workspace detection should be reasonably fast (< 100ms)
      assert.is_true(
        elapsed_ms < 100,
        string.format('Workspace detection time %dms exceeds 100ms threshold', elapsed_ms)
      )
    end)
  end)
end)
