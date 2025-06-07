-- lua/prompt-tower/services/ui.lua
-- UI service for managing the visual file selection interface
-- Incorporates visual enhancements adapted from lir.nvim

local config = require('prompt-tower.config')
local template_engine = require('prompt-tower.services.template_engine')
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
  current_focus_index = 1, -- Track which window is currently focused (1=tree, 2=selection, 3=top_text, 4=bottom_text)
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
  vim.api.nvim_set_hl(0, 'PromptTowerOversized', { fg = '#ed8796', bold = true })

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

    -- Highlight oversized files in red
    if line_info.is_oversized then
      vim.api.nvim_buf_add_highlight(state.buffers.tree, devicons_ns, 'PromptTowerOversized', i - 1, 0, -1)
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

  -- Set top text window options
  vim.api.nvim_win_set_option(state.windows.top_text, 'number', false)
  vim.api.nvim_win_set_option(state.windows.top_text, 'relativenumber', false)
  vim.api.nvim_win_set_option(state.windows.top_text, 'signcolumn', 'no')

  -- Bottom text window (right bottom) - matches selection width
  state.windows.bottom_text = create_float_win(state.buffers.bottom_text, {
    row = text_start_row,
    col = center_divider,
    width = layout.selection_width,
    height = layout.text_input_height,
    title = ' Context (Bottom) ',
  })

  -- Set bottom text window options
  vim.api.nvim_win_set_option(state.windows.bottom_text, 'number', false)
  vim.api.nvim_win_set_option(state.windows.bottom_text, 'relativenumber', false)
  vim.api.nvim_win_set_option(state.windows.bottom_text, 'signcolumn', 'no')
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

  -- Tree buffer mappings (NeoTree-inspired)
  -- Primary actions
  map(state.buffers.tree, 'n', '<CR>', M.tree_open_or_select, 'Open/Select item')
  map(state.buffers.tree, 'n', '<Space>', M.tree_toggle_node, 'Toggle node selection')

  -- Directory operations
  map(state.buffers.tree, 'n', 'C', M.tree_close_node, 'Close directory')
  map(state.buffers.tree, 'n', 'z', M.tree_close_all_nodes, 'Close all directories')

  -- Selection operations
  map(state.buffers.tree, 'n', 'a', M.tree_select_all_in_dir, 'Select all in directory')
  map(state.buffers.tree, 'n', 'A', M.tree_select_all_recursive, 'Select all recursively')
  map(state.buffers.tree, 'n', 'x', M.tree_clear_selection, 'Clear all selections')

  -- Navigation
  map(state.buffers.tree, 'n', 'j', M.tree_move_down, 'Move down')
  map(state.buffers.tree, 'n', 'k', M.tree_move_up, 'Move up')
  map(state.buffers.tree, 'n', '<Tab>', M.cycle_focus, 'Cycle to next window')
  map(state.buffers.tree, 'n', '<S-Tab>', M.cycle_focus_reverse, 'Cycle to previous window')

  -- Utility
  map(state.buffers.tree, 'n', 'R', M.refresh_tree, 'Refresh tree')
  map(state.buffers.tree, 'n', '?', M.show_help, 'Show help')
  map(state.buffers.tree, 'n', 'q', M.close_ui, 'Close UI')
  map(state.buffers.tree, 'n', '<C-g>', M.generate_prompt, 'Generate prompt')

  -- Selection buffer mappings
  map(state.buffers.selection, 'n', '<CR>', M.remove_from_selection, 'Remove from selection')
  map(state.buffers.selection, 'n', 'd', M.remove_from_selection, 'Remove from selection')
  map(state.buffers.selection, 'n', '<Tab>', M.cycle_focus, 'Cycle to next window')
  map(state.buffers.selection, 'n', '<S-Tab>', M.cycle_focus_reverse, 'Cycle to previous window')
  map(state.buffers.selection, 'n', '?', M.show_help, 'Show help')
  map(state.buffers.selection, 'n', 'q', M.close_ui, 'Close UI')
  map(state.buffers.selection, 'n', '<C-g>', M.generate_prompt, 'Generate prompt')

  -- Text buffer mappings
  map(state.buffers.top_text, 'n', '<Tab>', M.cycle_focus, 'Cycle to next window')
  map(state.buffers.top_text, 'n', '<S-Tab>', M.cycle_focus_reverse, 'Cycle to previous window')
  map(state.buffers.top_text, 'n', '?', M.show_help, 'Show help')
  map(state.buffers.top_text, 'n', 'q', M.close_ui, 'Close UI')
  map(state.buffers.top_text, 'n', '<C-g>', M.generate_prompt, 'Generate prompt')
  map(state.buffers.bottom_text, 'n', '<Tab>', M.cycle_focus, 'Cycle to next window')
  map(state.buffers.bottom_text, 'n', '<S-Tab>', M.cycle_focus_reverse, 'Cycle to previous window')
  map(state.buffers.bottom_text, 'n', '?', M.show_help, 'Show help')
  map(state.buffers.bottom_text, 'n', 'q', M.close_ui, 'Close UI')
  map(state.buffers.bottom_text, 'n', '<C-g>', M.generate_prompt, 'Generate prompt')
end

--- Set window options for text input windows to disable line numbers
--- @param window_name string The name of the window (top_text or bottom_text)
local function set_text_window_options(window_name)
  if window_name == 'top_text' or window_name == 'bottom_text' then
    local win = state.windows[window_name]
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_option(win, 'number', false)
      vim.api.nvim_win_set_option(win, 'relativenumber', false)
      vim.api.nvim_win_set_option(win, 'signcolumn', 'no')
    end
  end
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

  -- Ensure text windows have correct options
  set_text_window_options('top_text')
  set_text_window_options('bottom_text')

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
      local is_selected = false

      if node:is_directory() then
        -- For directories, show selection state
        local selection_state = workspace.get_directory_selection_state(node.path)
        if selection_state == 'all' then
          selected_mark = ' ●' -- Fully selected
          is_selected = true
        elseif selection_state == 'partial' then
          selected_mark = ' ◑' -- Partially selected
          is_selected = true
        end
        -- No mark for 'none' state
      else
        -- For files, show selection status
        is_selected = workspace.is_file_selected(node.path)
        selected_mark = is_selected and ' ✓' or ''
      end

      local line_prefix = prefix
      if depth > 1 then
        line_prefix = line_prefix .. (is_last and '└── ' or '├── ')
      end

      local display_name = node.name .. selected_mark

      -- Add size indicator for oversized files
      local size_indicator = ''
      local is_oversized = false
      if node:is_file() and node.size_exceeded then
        local size_kb = math.floor(node.size / 1024)
        size_indicator = string.format(' [%dKB - TOO LARGE]', size_kb)
        is_oversized = true
      end

      -- Add spacing like lir.nvim (adapted from lir's readdir function)
      local prefix_space = ' ' -- Space for better cursor appearance
      local line = prefix_space .. line_prefix .. icon .. ' ' .. display_name .. size_indicator

      table.insert(state.tree_lines, {
        text = line,
        node = node,
        depth = depth,
        is_directory = node:is_directory(),
        is_selected = is_selected,
        is_oversized = is_oversized,
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

--- Handle tree open/select (Enter key - NeoTree style)
--- Files: Toggle selection, Directories: Expand/collapse
function M.tree_open_or_select()
  if #state.tree_lines == 0 then
    return
  end

  -- Get actual cursor position from window to handle user navigation
  local cursor_pos = vim.api.nvim_win_get_cursor(state.windows.tree)
  local actual_line = cursor_pos[1]

  -- Update our tracked position
  state.cursor_line = actual_line

  if actual_line > #state.tree_lines then
    return
  end

  local line_data = state.tree_lines[actual_line]
  local node = line_data.node

  if node:is_directory() then
    -- For directories: expand/collapse
    node.expanded = not node.expanded
    M.refresh_tree()
  else
    -- For files: check if oversized before toggling selection
    if node.size_exceeded then
      local size_kb = math.floor(node.size / 1024)
      local max_size_kb = config.get_value('max_file_size_kb')
      vim.notify(
        string.format('Cannot select "%s" - file size (%dKB) exceeds limit (%dKB)', node.name, size_kb, max_size_kb),
        vim.log.levels.WARN
      )
    else
      -- For normal files: toggle selection
      workspace.toggle_file_selection(node.path)
      M.refresh_tree()
      M.refresh_selection()
    end
  end
end

--- Handle tree node toggle (Space key - NeoTree style)
--- Files: Toggle selection, Directories: Toggle recursive selection
function M.tree_toggle_node()
  if #state.tree_lines == 0 then
    return
  end

  -- Get actual cursor position from window to handle user navigation
  local cursor_pos = vim.api.nvim_win_get_cursor(state.windows.tree)
  local actual_line = cursor_pos[1]

  -- Update our tracked position
  state.cursor_line = actual_line

  if actual_line > #state.tree_lines then
    return
  end

  local line_data = state.tree_lines[actual_line]
  local node = line_data.node

  if node:is_directory() then
    -- For directories: toggle recursive selection
    workspace.toggle_directory_selection(node.path)
    M.refresh_tree()
    M.refresh_selection()
  else
    -- For files: check if oversized before toggling selection
    if node.size_exceeded then
      local size_kb = math.floor(node.size / 1024)
      local max_size_kb = config.get_value('max_file_size_kb')
      vim.notify(
        string.format('Cannot select "%s" - file size (%dKB) exceeds limit (%dKB)', node.name, size_kb, max_size_kb),
        vim.log.levels.WARN
      )
    else
      -- For normal files: toggle selection
      workspace.toggle_file_selection(node.path)
      M.refresh_tree()
      M.refresh_selection()
    end
  end
end

--- Close current directory node (C key)
function M.tree_close_node()
  if #state.tree_lines == 0 then
    return
  end

  -- Get actual cursor position from window to handle user navigation
  local cursor_pos = vim.api.nvim_win_get_cursor(state.windows.tree)
  local actual_line = cursor_pos[1]

  -- Update our tracked position
  state.cursor_line = actual_line

  if actual_line > #state.tree_lines then
    return
  end

  local line_data = state.tree_lines[actual_line]
  local node = line_data.node

  if node:is_directory() and node.expanded then
    node.expanded = false
    M.refresh_tree()
  end
end

--- Close all directory nodes (z key)
function M.tree_close_all_nodes()
  local current_workspace = workspace.get_current_workspace()
  if not current_workspace then
    return
  end

  local file_tree = workspace.get_file_tree(current_workspace)
  if not file_tree then
    return
  end

  -- Recursively close all directories
  local function close_all_recursive(node)
    if node:is_directory() then
      node.expanded = false
      for _, child in ipairs(node.children) do
        close_all_recursive(child)
      end
    end
  end

  close_all_recursive(file_tree)
  M.refresh_tree()
end

--- Select all files in current directory (a key)
function M.tree_select_all_in_dir()
  if #state.tree_lines == 0 then
    return
  end

  -- Get actual cursor position from window to handle user navigation
  local cursor_pos = vim.api.nvim_win_get_cursor(state.windows.tree)
  local actual_line = cursor_pos[1]

  if actual_line > #state.tree_lines then
    return
  end

  local line_data = state.tree_lines[actual_line]
  local node = line_data.node

  -- Get the parent directory
  local target_dir = node:is_directory() and node or node.parent

  if target_dir then
    -- Select all files in the target directory (non-recursive)
    for _, child in ipairs(target_dir.children) do
      if child:is_file() then
        workspace.select_file(child.path)
      end
    end
    M.refresh_tree()
    M.refresh_selection()
  end
end

--- Select all files recursively (A key)
function M.tree_select_all_recursive()
  local current_workspace = workspace.get_current_workspace()
  if not current_workspace then
    return
  end

  local file_tree = workspace.get_file_tree(current_workspace)
  if not file_tree then
    return
  end

  -- Select all files in the entire tree
  workspace.select_directory_recursive(file_tree.path)
  M.refresh_tree()
  M.refresh_selection()
end

--- Clear all selections (x key)
function M.tree_clear_selection()
  workspace.clear_selections()
  M.refresh_tree()
  M.refresh_selection()
end

--- Show help window (? key)
function M.show_help()
  local help_lines = {
    'Prompt Tower - Key Bindings',
    '════════════════════════════',
    '',
    'Window Navigation:',
    '  <Tab>     Cycle to next window',
    '  <S-Tab>   Cycle to previous window',
    '',
    'Tree Navigation:',
    '  j/k       Move up/down',
    '  <Enter>   Open/Select item',
    '  <Space>   Toggle node selection',
    '',
    'Directory Operations:',
    '  C         Close directory',
    '  z         Close all directories',
    '',
    'Selection Operations:',
    '  a         Select all in directory',
    '  A         Select all recursively',
    '  x         Clear all selections',
    '',
    'Utility:',
    '  R         Refresh tree',
    '  ?         Show this help',
    '  q         Close UI',
    '  <C-g>     Generate prompt',
    '',
    'Selection Indicators:',
    '  ✓         Selected file',
    '  ●         Fully selected dir',
    '  ◑         Partially selected dir',
    '',
    'File Status:',
    '  Red text  Oversized file (cannot select)',
    '  [XKB - TOO LARGE]  Size indicator',
    '',
    'Press any key to close help...',
  }

  -- Create help buffer
  local help_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(help_buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(help_buf, 'filetype', 'prompt-tower-help')
  vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)

  -- Calculate centered position
  local ui_width = vim.o.columns
  local ui_height = vim.o.lines
  local width = math.min(50, ui_width - 4)
  local height = math.min(#help_lines + 2, ui_height - 4)
  local row = math.floor((ui_height - height) / 2)
  local col = math.floor((ui_width - width) / 2)

  -- Create help window
  local help_win = vim.api.nvim_open_win(help_buf, true, {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' Help ',
  })

  -- Set help window options
  vim.api.nvim_win_set_option(help_win, 'wrap', false)
  vim.api.nvim_win_set_option(help_win, 'cursorline', false)

  -- Close help on any key press
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(help_win, true)
  end, { buffer = help_buf, noremap = true, silent = true })

  -- Close help on any other key
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(help_win, true)
  end, { buffer = help_buf, noremap = true, silent = true })

  -- Generic fallback for any key
  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = help_buf,
    callback = function()
      if vim.api.nvim_win_is_valid(help_win) then
        vim.api.nvim_win_close(help_win, true)
      end
    end,
    once = true,
  })
end

--- Cycle focus between UI windows (Tab functionality)
function M.cycle_focus()
  if not state.is_open then
    return
  end

  -- Define window order: tree -> selection -> top_text -> bottom_text -> repeat
  local windows_order = { 'tree', 'selection', 'top_text', 'bottom_text' }

  -- Move to next window
  state.current_focus_index = state.current_focus_index + 1
  if state.current_focus_index > #windows_order then
    state.current_focus_index = 1
  end

  local next_window_name = windows_order[state.current_focus_index]
  local next_window = state.windows[next_window_name]

  if next_window and vim.api.nvim_win_is_valid(next_window) then
    vim.api.nvim_set_current_win(next_window)
    -- Ensure line numbers are disabled in text windows
    set_text_window_options(next_window_name)
  end
end

--- Cycle focus in reverse direction (Shift+Tab functionality)
function M.cycle_focus_reverse()
  if not state.is_open then
    return
  end

  -- Define window order: tree -> selection -> top_text -> bottom_text -> repeat
  local windows_order = { 'tree', 'selection', 'top_text', 'bottom_text' }

  -- Move to previous window
  state.current_focus_index = state.current_focus_index - 1
  if state.current_focus_index < 1 then
    state.current_focus_index = #windows_order
  end

  local prev_window_name = windows_order[state.current_focus_index]
  local prev_window = state.windows[prev_window_name]

  if prev_window and vim.api.nvim_win_is_valid(prev_window) then
    vim.api.nvim_set_current_win(prev_window)
    -- Ensure line numbers are disabled in text windows
    set_text_window_options(prev_window_name)
  end
end

--- Legacy function for backward compatibility
function M.tree_select_file()
  M.tree_open_or_select()
end

--- Toggle folder expansion in tree
function M.tree_toggle_folder()
  if #state.tree_lines == 0 then
    return
  end

  -- Get actual cursor position from window to handle user navigation
  local cursor_pos = vim.api.nvim_win_get_cursor(state.windows.tree)
  local actual_line = cursor_pos[1]

  -- Update our tracked position
  state.cursor_line = actual_line

  if actual_line > #state.tree_lines then
    return
  end

  local line_data = state.tree_lines[actual_line]
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

  -- Get current workspace and template configuration
  local current_workspace = workspace.get_current_workspace()
  local template_config = config.get_template_config()

  -- Get root node for tree generation
  local root_node = workspace.get_file_tree(current_workspace)

  -- Generate context using template engine
  local context = template_engine.generate_context(selected_files, current_workspace, template_config, root_node)

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

  -- Add custom text to generated context
  local final_context_parts = {}

  -- Add top text if provided
  if top_text and top_text ~= '' then
    table.insert(final_context_parts, top_text)
    table.insert(final_context_parts, '')
  end

  -- Add generated context
  table.insert(final_context_parts, context)

  -- Add bottom text if provided
  if bottom_text and bottom_text ~= '' then
    table.insert(final_context_parts, '')
    table.insert(final_context_parts, bottom_text)
  end

  local final_context = table.concat(final_context_parts, '\n')

  -- Copy to clipboard
  local clipboard_register = config.get_value('clipboard.register') or '+'
  vim.fn.setreg(clipboard_register, final_context)

  local current_format = config.get_current_format()
  vim.notify(
    string.format('Generated %s context with %d files and copied to clipboard', current_format, #selected_files),
    vim.log.levels.INFO
  )

  -- Close UI after generation
  M.close_ui()
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
    current_focus_index = 1,
  }
end

return M
