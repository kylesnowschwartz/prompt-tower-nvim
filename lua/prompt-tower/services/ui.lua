-- lua/prompt-tower/services/ui.lua
-- UI service for managing the visual file selection interface
-- Incorporates visual enhancements adapted from lir.nvim

local config = require('prompt-tower.config')
local workspace = require('prompt-tower.services.workspace')

-- Devicons integration (adapted from lir.nvim)
local has_devicons, devicons = pcall(require, 'nvim-web-devicons')
local devicons_ns = vim.api.nvim_create_namespace('prompt_tower_devicons')

local M = {}

-- UI state
local state = {
  windows = {
    tree = nil, -- File tree window
    selection = nil, -- Selection list window
    top_text = nil, -- Top text input window
    bottom_text = nil, -- Bottom text input window
  },
  buffers = {
    tree = nil,
    selection = nil,
    top_text = nil,
    bottom_text = nil,
  },
  layout = {
    width = nil,
    height = nil,
    tree_width = nil,
    selection_width = nil,
  },
  is_open = false,
  current_tree_node = nil,
  tree_lines = {},
  cursor_line = 1,
}

--- Setup devicons and highlight groups (adapted from lir.nvim)
local function setup_devicons()
  if not has_devicons then
    return false
  end

  local folder_icon = devicons.get_icon('lir_folder_icon')
  if folder_icon == nil then
    devicons.set_icon({
      lir_folder_icon = {
        icon = '󰉋',
        color = '#7ebae4',
        name = 'LirFolderNode',
      },
    })
  end

  -- Setup highlight groups
  vim.api.nvim_set_hl(0, 'LirDir', { link = 'Directory' })
  vim.api.nvim_set_hl(0, 'PromptTowerSelected', { bg = '#3d4220', fg = '#a6da95' })

  return true
end

--- Get icon and highlight for file (adapted from lir.nvim)
--- @param filename string
--- @param is_dir boolean
--- @return string icon, string highlight_name
local function get_file_icon(filename, is_dir)
  if not has_devicons then
    return is_dir and '📁' or '📄', ''
  end

  if is_dir then
    return devicons.get_icon('lir_folder_icon', '', { default = true })
  else
    return devicons.get_icon(filename, string.match(filename, '%a+$'), { default = true })
  end
end

--- Update highlight groups for icons and directories in tree buffer (adapted from lir.nvim)
--- @param line_data table[] Array of line data with icon information
local function update_tree_highlights(line_data)
  if not state.buffers.tree then
    return
  end

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(state.buffers.tree, devicons_ns, 0, -1)

  for i, line_info in ipairs(line_data) do
    -- Highlight directories with LirDir highlight group
    if line_info.is_directory then
      vim.api.nvim_buf_add_highlight(state.buffers.tree, devicons_ns, 'LirDir', i - 1, 0, -1)
    end

    -- Highlight file icons if devicons available
    if has_devicons and line_info.icon_highlight and line_info.icon_highlight ~= '' then
      local icon_start = string.find(line_info.text, line_info.icon) or 0
      local icon_end = icon_start + vim.fn.strlen(line_info.icon)

      vim.api.nvim_buf_add_highlight(
        state.buffers.tree,
        devicons_ns,
        line_info.icon_highlight,
        i - 1,
        icon_start,
        icon_end
      )
    end

    -- Highlight selected files
    if line_info.is_selected then
      vim.api.nvim_buf_add_highlight(state.buffers.tree, devicons_ns, 'PromptTowerSelected', i - 1, 0, -1)
    end
  end
end

--- Calculate window layout dimensions
--- @return table Layout configuration
local function calculate_layout()
  local ui_width = vim.o.columns
  local ui_height = vim.o.lines

  -- Reserve space for command line and status
  local available_height = ui_height - 6
  local available_width = ui_width - 6

  -- Text input areas: make them taller and more usable
  local text_input_height = 8 -- Give more space for actual content
  local gap_between = 2 -- Gap between tree area and text inputs
  local tree_height = available_height - text_input_height - gap_between

  -- Split width: 55% tree, 45% selection for better balance
  local tree_width = math.floor(available_width * 0.55)
  local selection_width = available_width - tree_width - 2 -- Account for borders

  return {
    width = available_width,
    height = available_height,
    tree_width = tree_width,
    selection_width = selection_width,
    tree_height = tree_height,
    text_input_height = text_input_height,
    gap_between = gap_between,
  }
end

--- Create a floating window
--- @param buf number Buffer number
--- @param opts table Window options
--- @return number Window handle
local function create_float_win(buf, opts)
  local win_opts = vim.tbl_extend('force', {
    relative = 'editor',
    style = 'minimal',
    border = 'rounded',
    focusable = true,
  }, opts)

  return vim.api.nvim_open_win(buf, false, win_opts)
end

--- Create all UI buffers
local function create_buffers()
  -- Tree buffer
  state.buffers.tree = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.buffers.tree, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(state.buffers.tree, 'filetype', 'prompt-tower-tree')
  vim.api.nvim_buf_set_option(state.buffers.tree, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(state.buffers.tree, 'buflisted', false)
  vim.api.nvim_buf_set_option(state.buffers.tree, 'swapfile', false)

  -- Selection buffer
  state.buffers.selection = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.buffers.selection, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(state.buffers.selection, 'filetype', 'prompt-tower-selection')

  -- Top text buffer
  state.buffers.top_text = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.buffers.top_text, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(state.buffers.top_text, 'filetype', 'markdown')

  -- Bottom text buffer
  state.buffers.bottom_text = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(state.buffers.bottom_text, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(state.buffers.bottom_text, 'filetype', 'markdown')

  -- Set placeholder text
  vim.api.nvim_buf_set_lines(state.buffers.top_text, 0, -1, false, {
    '<!-- Top context (appears before files) -->',
    '',
    '',
  })

  vim.api.nvim_buf_set_lines(state.buffers.bottom_text, 0, -1, false, {
    '<!-- Bottom context (appears after files) -->',
    '',
    '',
  })
end

--- Create all UI windows
local function create_windows()
  local layout = calculate_layout()
  state.layout = layout

  -- Tree window (left side)
  state.windows.tree = create_float_win(state.buffers.tree, {
    row = 2,
    col = 2,
    width = layout.tree_width,
    height = layout.tree_height,
    title = ' File Tree ',
  })

  -- Set tree window options (adapted from lir.nvim)
  vim.api.nvim_win_set_option(state.windows.tree, 'wrap', false)
  vim.api.nvim_win_set_option(state.windows.tree, 'cursorline', true)
  vim.api.nvim_win_set_option(state.windows.tree, 'number', false)
  vim.api.nvim_win_set_option(state.windows.tree, 'relativenumber', false)
  vim.api.nvim_win_set_option(state.windows.tree, 'signcolumn', 'no')

  -- Selection window (right side)
  state.windows.selection = create_float_win(state.buffers.selection, {
    row = 2,
    col = layout.tree_width + 4,
    width = layout.selection_width,
    height = layout.tree_height,
    title = ' Selected Files ',
  })

  -- Calculate text input positioning to align with tree/selection divider
  local text_start_row = layout.tree_height + layout.gap_between + 2
  local center_divider = layout.tree_width + 4 -- Same as selection window column

  -- Top text window (left bottom) - matches tree width
  state.windows.top_text = create_float_win(state.buffers.top_text, {
    row = text_start_row,
    col = 2,
    width = layout.tree_width,
    height = layout.text_input_height,
    title = ' Context (Top) ',
  })

  -- Bottom text window (right bottom) - matches selection width
  state.windows.bottom_text = create_float_win(state.buffers.bottom_text, {
    row = text_start_row,
    col = center_divider,
    width = layout.selection_width,
    height = layout.text_input_height,
    title = ' Context (Bottom) ',
  })
end

--- Set up key mappings for UI buffers
local function setup_keymaps()
  local function map(buf, mode, key, action, desc)
    vim.keymap.set(mode, key, action, {
      buffer = buf,
      noremap = true,
      silent = true,
      desc = desc,
    })
  end

  -- Tree buffer mappings
  map(state.buffers.tree, 'n', '<CR>', M.tree_select_file, 'Select/Toggle file')
  map(state.buffers.tree, 'n', '<Space>', M.tree_select_file, 'Select/Toggle file')
  map(state.buffers.tree, 'n', 'o', M.tree_toggle_folder, 'Toggle folder')
  map(state.buffers.tree, 'n', 'j', M.tree_move_down, 'Move down')
  map(state.buffers.tree, 'n', 'k', M.tree_move_up, 'Move up')
  map(state.buffers.tree, 'n', 'q', M.close_ui, 'Close UI')
  map(state.buffers.tree, 'n', '<C-g>', M.generate_prompt, 'Generate prompt')

  -- Selection buffer mappings
  map(state.buffers.selection, 'n', '<CR>', M.remove_from_selection, 'Remove from selection')
  map(state.buffers.selection, 'n', 'd', M.remove_from_selection, 'Remove from selection')
  map(state.buffers.selection, 'n', 'q', M.close_ui, 'Close UI')
  map(state.buffers.selection, 'n', '<C-g>', M.generate_prompt, 'Generate prompt')

  -- Text buffer mappings
  map(state.buffers.top_text, 'n', 'q', M.close_ui, 'Close UI')
  map(state.buffers.top_text, 'n', '<C-g>', M.generate_prompt, 'Generate prompt')
  map(state.buffers.bottom_text, 'n', 'q', M.close_ui, 'Close UI')
  map(state.buffers.bottom_text, 'n', '<C-g>', M.generate_prompt, 'Generate prompt')
end

--- Open the UI interface
function M.open()
  if state.is_open then
    return
  end

  -- Ensure workspace is available
  local current_workspace = workspace.get_current_workspace()
  if not current_workspace then
    vim.notify('No workspace found. Open a file in a project directory.', vim.log.levels.WARN)
    return
  end

  -- Scan workspace if needed
  workspace.scan_workspace(current_workspace)

  -- Setup devicons
  setup_devicons()

  create_buffers()
  create_windows()
  setup_keymaps()

  -- Populate initial content
  M.refresh_tree()
  M.refresh_selection()

  -- Focus tree window
  vim.api.nvim_set_current_win(state.windows.tree)

  state.is_open = true

  -- Show help message
  vim.notify('Prompt Tower UI opened. Press q to close, Ctrl+g to generate prompt.', vim.log.levels.INFO)
end

--- Close the UI interface
function M.close_ui()
  if not state.is_open then
    return
  end

  -- Close windows
  for _, win in pairs(state.windows) do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  -- Clear state
  state.windows = {}
  state.buffers = {}
  state.is_open = false
  state.tree_lines = {}
  state.cursor_line = 1

  vim.notify('Prompt Tower UI closed.', vim.log.levels.INFO)
end

--- Check if UI is currently open
--- @return boolean
function M.is_open()
  return state.is_open
end

--- Refresh the file tree display
function M.refresh_tree()
  if not state.buffers.tree then
    return
  end

  local current_workspace = workspace.get_current_workspace()
  if not current_workspace then
    return
  end

  local file_tree = workspace.get_file_tree(current_workspace)
  if not file_tree then
    return
  end

  state.tree_lines = {}
  state.current_tree_node = file_tree

  -- Build tree display lines with enhanced icons
  local function build_tree_lines(node, depth, is_last, prefix)
    depth = depth or 0
    is_last = is_last or true
    prefix = prefix or ''

    if depth > 0 then -- Skip root node in display
      local icon, icon_highlight = get_file_icon(node.name, node:is_directory())
      local selected_mark = ''

      -- For files, show selection status
      if not node:is_directory() then
        selected_mark = workspace.is_file_selected(node.path) and ' ✓' or ''
      end

      local line_prefix = prefix
      if depth > 1 then
        line_prefix = line_prefix .. (is_last and '└── ' or '├── ')
      end

      local display_name = node.name .. selected_mark
      -- Add spacing like lir.nvim (adapted from lir's readdir function)
      local prefix_space = ' ' -- Space for better cursor appearance
      local line = prefix_space .. line_prefix .. icon .. ' ' .. display_name

      table.insert(state.tree_lines, {
        text = line,
        node = node,
        depth = depth,
        is_directory = node:is_directory(),
        is_selected = workspace.is_file_selected(node.path),
        icon = icon,
        icon_highlight = icon_highlight,
      })
    end

    -- Add children if directory is expanded or is root
    if node:is_directory() and (node.expanded or depth == 0) then
      for i, child in ipairs(node.children) do
        local child_is_last = (i == #node.children)
        local child_prefix = prefix
        if depth > 0 then
          child_prefix = child_prefix .. (is_last and '    ' or '│   ')
        end
        build_tree_lines(child, depth + 1, child_is_last, child_prefix)
      end
    end
  end

  build_tree_lines(file_tree)

  -- Update buffer content
  local display_lines = {}
  for _, line_data in ipairs(state.tree_lines) do
    table.insert(display_lines, line_data.text)
  end

  if #display_lines == 0 then
    display_lines = { 'No files found in workspace' }
  end

  vim.api.nvim_buf_set_lines(state.buffers.tree, 0, -1, false, display_lines)

  -- Apply icon highlighting
  update_tree_highlights(state.tree_lines)

  -- Ensure cursor is in bounds
  if state.cursor_line > #state.tree_lines then
    state.cursor_line = math.max(1, #state.tree_lines)
  end

  -- Set cursor position
  if vim.api.nvim_win_is_valid(state.windows.tree) then
    vim.api.nvim_win_set_cursor(state.windows.tree, { state.cursor_line, 0 })
  end
end

--- Refresh the selection display
function M.refresh_selection()
  if not state.buffers.selection then
    return
  end

  local selected_files = workspace.get_selected_files()
  local current_workspace = workspace.get_current_workspace()

  local display_lines = {}

  if #selected_files == 0 then
    table.insert(display_lines, 'No files selected')
    table.insert(display_lines, '')
    table.insert(display_lines, 'Navigate the tree and press <Enter>')
    table.insert(display_lines, 'or <Space> to select files.')
  else
    table.insert(display_lines, string.format('Selected Files (%d):', #selected_files))
    table.insert(display_lines, string.rep('─', 30))

    for _, node in ipairs(selected_files) do
      local display_path = current_workspace and node:get_relative_path(current_workspace) or node.path
      local icon, _ = get_file_icon(node.name, false)
      table.insert(display_lines, icon .. ' ' .. display_path)
    end

    table.insert(display_lines, '')
    table.insert(display_lines, 'Press <Enter> or d to remove')
  end

  vim.api.nvim_buf_set_lines(state.buffers.selection, 0, -1, false, display_lines)
end

--- Handle tree navigation - move cursor down
function M.tree_move_down()
  if #state.tree_lines == 0 then
    return
  end

  state.cursor_line = math.min(state.cursor_line + 1, #state.tree_lines)
  vim.api.nvim_win_set_cursor(state.windows.tree, { state.cursor_line, 0 })
end

--- Handle tree navigation - move cursor up
function M.tree_move_up()
  if #state.tree_lines == 0 then
    return
  end

  state.cursor_line = math.max(state.cursor_line - 1, 1)
  vim.api.nvim_win_set_cursor(state.windows.tree, { state.cursor_line, 0 })
end

--- Handle tree selection/toggle
function M.tree_select_file()
  if #state.tree_lines == 0 or state.cursor_line > #state.tree_lines then
    return
  end

  local line_data = state.tree_lines[state.cursor_line]
  local node = line_data.node

  if node:is_directory() then
    M.tree_toggle_folder()
  else
    -- Toggle file selection
    workspace.toggle_file_selection(node.path)
    M.refresh_tree()
    M.refresh_selection()
  end
end

--- Toggle folder expansion in tree
function M.tree_toggle_folder()
  if #state.tree_lines == 0 or state.cursor_line > #state.tree_lines then
    return
  end

  local line_data = state.tree_lines[state.cursor_line]
  local node = line_data.node

  if node:is_directory() then
    node.expanded = not node.expanded
    M.refresh_tree()
  end
end

--- Remove file from selection
function M.remove_from_selection()
  if not vim.api.nvim_win_is_valid(state.windows.selection) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.windows.selection)
  local line_num = cursor[1]

  local selected_files = workspace.get_selected_files()

  -- Account for header lines (2 lines before file list starts)
  local file_index = line_num - 2

  if file_index > 0 and file_index <= #selected_files then
    local file_node = selected_files[file_index]
    workspace.deselect_file(file_node.path)
    M.refresh_tree()
    M.refresh_selection()
  end
end

--- Generate prompt with current selection and custom text
function M.generate_prompt()
  local selected_files = workspace.get_selected_files()

  if #selected_files == 0 then
    vim.notify('No files selected for prompt generation', vim.log.levels.WARN)
    return
  end

  -- Get custom text from input buffers
  local top_text_lines = vim.api.nvim_buf_get_lines(state.buffers.top_text, 0, -1, false)
  local bottom_text_lines = vim.api.nvim_buf_get_lines(state.buffers.bottom_text, 0, -1, false)

  -- Filter out placeholder comments
  local function filter_placeholder(lines)
    local filtered = {}
    for _, line in ipairs(lines) do
      if not line:match('^%s*<!%-%-.*%-%->%s*$') then
        table.insert(filtered, line)
      end
    end
    return filtered
  end

  local top_text = table.concat(filter_placeholder(top_text_lines), '\n'):gsub('^%s*(.-)%s*$', '%1')
  local bottom_text = table.concat(filter_placeholder(bottom_text_lines), '\n'):gsub('^%s*(.-)%s*$', '%1')

  -- Build the prompt
  local context_parts = {}
  local current_workspace = workspace.get_current_workspace()

  -- Add top text if provided
  if top_text and top_text ~= '' then
    table.insert(context_parts, top_text)
    table.insert(context_parts, '')
  end

  -- Add header
  table.insert(context_parts, '<!-- Generated by prompt-tower.nvim -->')
  table.insert(context_parts, string.format('<!-- %d files selected -->', #selected_files))
  table.insert(context_parts, '')

  -- Add workspace info
  if current_workspace then
    table.insert(context_parts, string.format('<!-- Workspace: %s -->', current_workspace))
    table.insert(context_parts, '')
  end

  -- Add each file
  for _, file_node in ipairs(selected_files) do
    -- Read file content using the existing helper
    local file_content = M._read_file(file_node.path)
    if file_content then
      local relative_path = current_workspace and file_node:get_relative_path(current_workspace) or file_node.path
      table.insert(context_parts, string.format('<file path="%s">', relative_path))
      table.insert(context_parts, file_content)
      table.insert(context_parts, '</file>')
      table.insert(context_parts, '')
    end
  end

  -- Add bottom text if provided
  if bottom_text and bottom_text ~= '' then
    table.insert(context_parts, bottom_text)
  end

  local context = table.concat(context_parts, '\n')

  -- Copy to clipboard
  local clipboard_register = config.get_value('clipboard.register') or '+'
  vim.fn.setreg(clipboard_register, context)

  vim.notify(
    string.format('Generated context with %d files and copied to clipboard', #selected_files),
    vim.log.levels.INFO
  )

  -- Close UI after generation
  M.close_ui()
end

--- Internal helper to read file content (borrowed from init.lua)
--- @param filepath string Path to the file
--- @return string? content File content or nil if error
function M._read_file(filepath)
  local file = io.open(filepath, 'r')
  if not file then
    vim.notify(string.format('Could not read file: %s', filepath), vim.log.levels.ERROR)
    return nil
  end

  local content = file:read('*all')
  file:close()

  return content
end

--- Get UI state for testing
--- @return table
function M._get_state()
  return state
end

--- Reset UI state for testing
function M._reset_state()
  M.close_ui()
  state = {
    windows = {},
    buffers = {},
    layout = {},
    is_open = false,
    current_tree_node = nil,
    tree_lines = {},
    cursor_line = 1,
  }
end

return M
