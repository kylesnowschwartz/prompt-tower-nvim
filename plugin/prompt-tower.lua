-- plugin/prompt-tower.lua
-- Plugin registration for prompt-tower.nvim
-- This file is automatically loaded by Neovim when the plugin is installed

-- Prevent loading the plugin multiple times
if vim.g.loaded_prompt_tower == 1 then
  return
end
vim.g.loaded_prompt_tower = 1

-- Check Neovim version compatibility
if vim.fn.has('nvim-0.8') == 0 then
  vim.api.nvim_err_writeln('prompt-tower.nvim requires Neovim 0.8 or later')
  return
end

-- Register user commands
vim.api.nvim_create_user_command('PromptTower', function(opts)
  require('prompt-tower').run_command(opts.args)
end, {
  nargs = '?',
  desc = 'Open Prompt Tower file selection interface',
  complete = function(arg_lead, cmd_line, cursor_pos)
    return require('prompt-tower').complete_command(arg_lead, cmd_line, cursor_pos)
  end,
})

vim.api.nvim_create_user_command('PromptTowerSelect', function(opts)
  require('prompt-tower').select_current_file()
end, {
  desc = 'Add current file to Prompt Tower selection',
})

vim.api.nvim_create_user_command('PromptTowerGenerate', function(opts)
  require('prompt-tower').generate_context()
end, {
  desc = 'Generate context from selected files and copy to clipboard',
})

vim.api.nvim_create_user_command('PromptTowerClear', function(opts)
  require('prompt-tower').clear_selection()
end, {
  desc = 'Clear all selected files from Prompt Tower',
})

vim.api.nvim_create_user_command('PromptTowerToggle', function(opts)
  require('prompt-tower').toggle_selection(opts.args)
end, {
  nargs = '?',
  desc = 'Toggle file selection in Prompt Tower',
  complete = 'file',
})
