-- lua/prompt-tower/health.lua
-- Health check support for prompt-tower.nvim
-- Run with :checkhealth prompt-tower

local M = {}

--- Main health check function
function M.check()
  vim.health.start('prompt-tower.nvim')

  -- Check Neovim version compatibility
  if vim.fn.has('nvim-0.8') == 1 then
    vim.health.ok('Neovim version >= 0.8 (required)')
  else
    vim.health.error('Neovim 0.8+ required, current version is older')
    return -- Don't continue if version is incompatible
  end

  -- Check clipboard support
  if vim.fn.has('clipboard') == 1 then
    vim.health.ok('Clipboard support available')
  else
    vim.health.warn('No clipboard support detected - context copying may not work')
  end

  -- Check for plenary.nvim (testing dependency)
  local plenary_ok = pcall(require, 'plenary')
  if plenary_ok then
    vim.health.ok('plenary.nvim found (testing dependency)')
  else
    vim.health.info('plenary.nvim not found (only needed for testing/development)')
  end

  -- Check plugin initialization
  local config_ok, config = pcall(require, 'prompt-tower.config')
  if config_ok then
    vim.health.ok('Configuration module loaded successfully')

    -- Check if plugin has been set up
    if config.is_initialized() then
      vim.health.ok('Plugin has been initialized')
    else
      vim.health.info('Plugin not yet initialized (will auto-initialize on first use)')
    end
  else
    vim.health.error('Failed to load configuration module: ' .. tostring(config))
    return
  end

  -- Check workspace detection
  local workspace_ok, workspace = pcall(require, 'prompt-tower.services.workspace')
  if workspace_ok then
    vim.health.ok('Workspace service loaded successfully')

    -- Try to detect current workspace
    local current_workspace = workspace.get_current_workspace()
    if current_workspace and current_workspace ~= '' then
      vim.health.ok('Current workspace detected: ' .. current_workspace)
    else
      vim.health.warn('No workspace detected from current directory or buffers')
    end
  else
    vim.health.error('Failed to load workspace service: ' .. tostring(workspace))
  end

  -- Check file discovery
  local discovery_ok, file_discovery = pcall(require, 'prompt-tower.services.file_discovery')
  if discovery_ok then
    vim.health.ok('File discovery service loaded successfully')
  else
    vim.health.error('Failed to load file discovery service: ' .. tostring(file_discovery))
  end

  -- Check template engine
  local template_ok, template_engine = pcall(require, 'prompt-tower.services.template_engine')
  if template_ok then
    vim.health.ok('Template engine loaded successfully')

    -- Check available template formats
    local formats = config.get_available_formats()
    if formats and #formats > 0 then
      vim.health.ok('Available template formats: ' .. table.concat(formats, ', '))
    else
      vim.health.warn('No template formats available')
    end
  else
    vim.health.error('Failed to load template engine: ' .. tostring(template_engine))
  end

  -- Check user commands registration
  local commands =
    { 'PromptTower', 'PromptTowerSelect', 'PromptTowerGenerate', 'PromptTowerClear', 'PromptTowerToggle' }
  local missing_commands = {}

  for _, cmd in ipairs(commands) do
    if vim.fn.exists(':' .. cmd) ~= 2 then
      table.insert(missing_commands, cmd)
    end
  end

  if #missing_commands == 0 then
    vim.health.ok('All user commands registered successfully')
  else
    vim.health.error('Missing user commands: ' .. table.concat(missing_commands, ', '))
  end

  vim.health.info('Run :PromptTower to test the plugin interface')
end

return M
