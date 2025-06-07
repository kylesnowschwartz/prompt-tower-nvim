-- tests/minimal_init.lua
-- Minimal init file for running tests

-- Add current plugin to runtimepath
vim.opt.rtp:prepend('.')

-- Ensure plenary is available (assuming it's installed)
-- If using a plugin manager, you might need to adjust this
local plenary_ok, _ = pcall(require, 'plenary')
if not plenary_ok then
  error('plenary.nvim is required for running tests. Please install it.')
end

-- Set up a clean environment for testing
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.undofile = false

-- Disable some features that might interfere with testing
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set up error handling for tests
vim.api.nvim_set_option_value('verbosefile', 'test_output.log', {})

-- Initialize the plugin for testing
require('prompt-tower')
