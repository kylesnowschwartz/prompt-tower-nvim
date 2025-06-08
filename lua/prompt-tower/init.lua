-- lua/prompt-tower/init.lua
-- Main entry point for the prompt-tower.nvim plugin

local M = {}

-- Plugin metadata
M._VERSION = '0.1.1'
M._NAME = 'prompt-tower.nvim'

-- Plugin version for compatibility checks (deprecated, use M._VERSION)
M.version = '0.1.1'

-- Lazy load dependencies to improve startup performance
local function get_config()
  return require('prompt-tower.config')
end

local function get_template_engine()
  return require('prompt-tower.services.template_engine')
end

local function get_ui()
  return require('prompt-tower.services.ui')
end

local function get_workspace()
  return require('prompt-tower.services.workspace')
end

-- Internal state (now using workspace service)
local state = {
  initialized = false,
  last_context = nil,
}

--- Initialize the plugin
--- @return boolean success True if initialization succeeded
function M.setup(opts)
  vim.validate('opts', opts or {}, 'table')

  -- Merge user options with defaults
  get_config().setup(opts)

  -- Initialize workspace management
  get_workspace().setup()

  -- Mark as initialized
  state.initialized = true

  return true
end

--- Check if plugin is initialized
--- @return boolean
local function ensure_initialized()
  if not state.initialized then
    -- Auto-initialize with defaults if not explicitly set up
    M.setup({})
  end
  return state.initialized
end

--- Run a command from the user command interface
--- @param args string? Command arguments
function M.run_command(args)
  if not ensure_initialized() then
    vim.notify('Failed to initialize prompt-tower', vim.log.levels.ERROR)
    return
  end

  -- Parse arguments
  args = args or ''
  args = args:gsub('^%s*(.-)%s*$', '%1') -- trim whitespace

  if args == '' or args == 'ui' then
    -- Open the visual UI interface
    M.open_ui()
  elseif args == 'select' then
    -- Select current file (legacy command)
    M.select_current_file()
  elseif args == 'generate' then
    -- Generate context (legacy command)
    M.generate_context()
  elseif args == 'clear' then
    -- Clear selections (legacy command)
    M.clear_selection()
  elseif args:match('^format%s') then
    -- Template format commands
    local format_arg = args:match('^format%s+(.+)')
    if format_arg then
      M.set_template_format(format_arg)
    else
      M.show_current_format()
    end
  else
    vim.notify(
      'Unknown command: ' .. args .. '. Use ui, select, generate, clear, or format <name>.',
      vim.log.levels.WARN
    )
  end
end

--- Complete command arguments
--- @param arg_lead string The leading portion of the argument being completed
--- @param cmd_line string The entire command line
--- @param cursor_pos number The cursor position in the command line
--- @return table List of completion candidates
function M.complete_command(arg_lead, cmd_line, _cursor_pos)
  local matches = {}

  -- If we're completing a format command
  if cmd_line:match('^%s*PromptTower%s+format%s') then
    local formats = get_config().get_available_formats()
    for _, format in ipairs(formats) do
      if format:sub(1, #arg_lead) == arg_lead then
        table.insert(matches, format)
      end
    end
    return matches
  end

  -- Regular command completion
  local commands = { 'ui', 'select', 'generate', 'clear', 'format' }
  for _, cmd in ipairs(commands) do
    if cmd:sub(1, #arg_lead) == arg_lead then
      table.insert(matches, cmd)
    end
  end

  return matches
end

--- Add current file to selection
function M.select_current_file()
  if not ensure_initialized() then
    vim.notify('Failed to initialize prompt-tower', vim.log.levels.ERROR)
    return
  end

  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == '' then
    vim.notify('No file in current buffer', vim.log.levels.WARN)
    return
  end

  -- Use workspace service for selection
  local success = get_workspace().select_file(current_file)
  if success then
    vim.notify(
      string.format('Added "%s" to Prompt Tower selection', vim.fn.fnamemodify(current_file, ':t')),
      vim.log.levels.INFO
    )
  else
    vim.notify(
      string.format('Could not select "%s" - file not found in workspace', vim.fn.fnamemodify(current_file, ':t')),
      vim.log.levels.WARN
    )
  end
end

--- Generate context from selected files
function M.generate_context()
  if not ensure_initialized() then
    vim.notify('Failed to initialize prompt-tower', vim.log.levels.ERROR)
    return
  end

  local selected_files = get_workspace().get_selected_files()
  if #selected_files == 0 then
    vim.notify('No files selected for context generation', vim.log.levels.WARN)
    return
  end

  -- Get current workspace and template configuration
  local current_workspace = get_workspace().get_current_workspace()
  local template_config = get_config().get_template_config()

  -- Get root node for tree generation
  local root_node = get_workspace().get_file_tree(current_workspace)

  -- Generate context using template engine
  local context = get_template_engine().generate_context(selected_files, current_workspace, template_config, root_node)
  state.last_context = context

  -- Copy to clipboard
  local clipboard_register = get_config().get_value('clipboard.register') or '+'
  vim.fn.setreg(clipboard_register, context)

  local current_format = get_config().get_current_format()
  vim.notify(
    string.format('Generated %s context with %d files and copied to clipboard', current_format, #selected_files),
    vim.log.levels.INFO
  )
end

--- Clear all selected files
function M.clear_selection()
  if not ensure_initialized() then
    vim.notify('Failed to initialize prompt-tower', vim.log.levels.ERROR)
    return
  end

  local count = get_workspace().get_selection_count()
  get_workspace().clear_selections()

  vim.notify(string.format('Cleared %d files from selection', count), vim.log.levels.INFO)
end

--- Toggle file selection
--- @param filepath string? File path to toggle, defaults to current file
function M.toggle_selection(filepath)
  if not ensure_initialized() then
    vim.notify('Failed to initialize prompt-tower', vim.log.levels.ERROR)
    return
  end

  local target_file = filepath or vim.api.nvim_buf_get_name(0)
  if target_file == '' then
    vim.notify('No file specified or in current buffer', vim.log.levels.WARN)
    return
  end

  local was_selected = get_workspace().is_file_selected(target_file)
  local new_state = get_workspace().toggle_file_selection(target_file)

  if new_state and not was_selected then
    vim.notify(string.format('Added "%s" to selection', vim.fn.fnamemodify(target_file, ':t')), vim.log.levels.INFO)
  elseif not new_state and was_selected then
    vim.notify(string.format('Removed "%s" from selection', vim.fn.fnamemodify(target_file, ':t')), vim.log.levels.INFO)
  else
    vim.notify(
      string.format('Could not toggle selection for "%s"', vim.fn.fnamemodify(target_file, ':t')),
      vim.log.levels.WARN
    )
  end
end

--- Get current state for testing
--- @return table Internal state
function M._get_state()
  return state
end

--- Reset state for testing
function M._reset_state()
  state = {
    initialized = false,
    last_context = nil,
  }
  get_workspace()._reset_state()
end

--- Open the visual UI interface
function M.open_ui()
  if not ensure_initialized() then
    vim.notify('Failed to initialize prompt-tower', vim.log.levels.ERROR)
    return
  end

  get_ui().open()
end

--- Check if UI is open
--- @return boolean
function M.is_ui_open()
  return get_ui().is_open()
end

--- Close UI interface
function M.close_ui()
  get_ui().close_ui()
end

--- Get workspace service for testing
--- @return table Workspace service
function M._get_workspace()
  return get_workspace()
end

--- Get UI service for testing
--- @return table UI service
function M._get_ui()
  return get_ui()
end

--- Set template format (hot-swap)
--- @param format string Template format name
function M.set_template_format(format)
  if not ensure_initialized() then
    vim.notify('Failed to initialize prompt-tower', vim.log.levels.ERROR)
    return
  end

  local success, err = pcall(get_config().set_current_format, format)
  if success then
    vim.notify(string.format('Switched to %s template format', format), vim.log.levels.INFO)
  else
    vim.notify(string.format('Failed to set format: %s', err), vim.log.levels.ERROR)
  end
end

--- Show current template format
function M.show_current_format()
  if not ensure_initialized() then
    vim.notify('Failed to initialize prompt-tower', vim.log.levels.ERROR)
    return
  end

  local current_format = get_config().get_current_format()
  local available_formats = get_config().get_available_formats()

  vim.notify(
    string.format('Current format: %s\nAvailable formats: %s', current_format, table.concat(available_formats, ', ')),
    vim.log.levels.INFO
  )
end

return M
