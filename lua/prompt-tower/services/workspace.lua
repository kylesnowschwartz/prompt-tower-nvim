-- lua/prompt-tower/services/workspace.lua
-- Workspace management service for handling project roots and file discovery

local config = require('prompt-tower.config')
local file_discovery = require('prompt-tower.services.file_discovery')

local M = {}

-- Internal state
local state = {
  workspaces = {}, -- List of workspace root paths
  file_trees = {}, -- Cached file trees by workspace
  selected_files = {}, -- Selected file nodes by path
  current_workspace = nil,
  workspaces_detected = false, -- Track if workspaces have been detected
}

--- Initialize workspace management
function M.setup()
  -- Clear state
  state = {
    workspaces = {},
    file_trees = {},
    selected_files = {},
    current_workspace = nil,
    workspaces_detected = false,
  }

  -- Note: Workspace detection is now lazy - will happen on first access
end

--- Ensure workspaces are detected (lazy initialization)
local function ensure_workspaces_detected()
  if not state.workspaces_detected then
    M._detect_workspaces()
    state.workspaces_detected = true
  end
end

--- Detect workspaces from current Neovim session
function M._detect_workspaces()
  local workspaces = {}

  -- Get current working directory
  local cwd = vim.fn.getcwd()
  if cwd and cwd ~= '' then
    table.insert(workspaces, cwd)
  end

  -- Get all listed buffers and extract unique directories
  local buffer_dirs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name and buf_name ~= '' then
        local dir = vim.fn.fnamemodify(buf_name, ':h')
        if dir and dir ~= '' and not buffer_dirs[dir] then
          buffer_dirs[dir] = true
        end
      end
    end
  end

  -- Find project roots for buffer directories
  for dir, _ in pairs(buffer_dirs) do
    local project_root = M._find_project_root(dir)
    if project_root and not vim.tbl_contains(workspaces, project_root) then
      table.insert(workspaces, project_root)
    end
  end

  state.workspaces = workspaces
  state.current_workspace = workspaces[1] -- Default to first workspace
end

--- Find project root by looking for common project files
--- @param start_dir string Starting directory
--- @return string? Project root or nil if not found
function M._find_project_root(start_dir)
  local root_markers = {
    '.git',
    '.gitignore',
    'package.json',
    'Cargo.toml',
    'pyproject.toml',
    'setup.py',
    'Makefile',
    '.towerignore',
  }

  local dir = start_dir
  while dir and dir ~= '/' do
    for _, marker in ipairs(root_markers) do
      local marker_path = dir .. '/' .. marker
      if vim.fn.filereadable(marker_path) == 1 or vim.fn.isdirectory(marker_path) == 1 then
        return dir
      end
    end

    -- Move up one directory
    local parent = vim.fn.fnamemodify(dir, ':h')
    if parent == dir then
      break -- Reached root
    end
    dir = parent
  end

  return nil
end

--- Get list of all workspaces
--- @return string[] List of workspace paths
function M.get_workspaces()
  ensure_workspaces_detected()
  return vim.deepcopy(state.workspaces)
end

--- Get current workspace
--- @return string? Current workspace path
function M.get_current_workspace()
  ensure_workspaces_detected()
  return state.current_workspace
end

--- Set current workspace
--- @param workspace_path string Workspace path to set as current
--- @return boolean Success
function M.set_current_workspace(workspace_path)
  ensure_workspaces_detected()
  vim.validate('workspace_path', workspace_path, 'string')

  if not vim.tbl_contains(state.workspaces, workspace_path) then
    return false
  end

  state.current_workspace = workspace_path
  return true
end

--- Add a workspace
--- @param workspace_path string Path to add as workspace
--- @return boolean Success
function M.add_workspace(workspace_path)
  vim.validate('workspace_path', workspace_path, 'string')

  -- Ensure path exists and is a directory
  local stat = vim.loop.fs_stat(workspace_path)
  if not stat or stat.type ~= 'directory' then
    return false
  end

  local normalized_path = vim.fn.fnamemodify(workspace_path, ':p:h')
  if not vim.tbl_contains(state.workspaces, normalized_path) then
    table.insert(state.workspaces, normalized_path)
    if not state.current_workspace then
      state.current_workspace = normalized_path
    end
  end

  return true
end

--- Remove a workspace
--- @param workspace_path string Path to remove
--- @return boolean Success
function M.remove_workspace(workspace_path)
  vim.validate('workspace_path', workspace_path, 'string')

  for i, path in ipairs(state.workspaces) do
    if path == workspace_path then
      table.remove(state.workspaces, i)

      -- Clear cached tree
      state.file_trees[workspace_path] = nil

      -- Update current workspace if needed
      if state.current_workspace == workspace_path then
        state.current_workspace = state.workspaces[1]
      end

      return true
    end
  end

  return false
end

--- Scan workspace for files
--- @param workspace_path? string Workspace to scan, defaults to current
--- @param force_refresh? boolean Force refresh of cached tree
--- @return FileNode? Root file node or nil if error
function M.scan_workspace(workspace_path, force_refresh)
  workspace_path = workspace_path or state.current_workspace
  if not workspace_path then
    return nil
  end

  -- Return cached tree if available and not forcing refresh
  if not force_refresh and state.file_trees[workspace_path] then
    return state.file_trees[workspace_path]
  end

  -- Scan directory
  local scan_opts = {
    max_depth = config.get_value('file_discovery.max_depth') or 10,
    include_hidden = config.get_value('file_discovery.include_hidden') or false,
    respect_gitignore = config.get_value('use_gitignore'),
    custom_ignore = config.get_value('ignore_patterns') or {},
  }

  local success, result = pcall(file_discovery.scan_directory, workspace_path, scan_opts)
  if not success then
    vim.notify(string.format('Failed to scan workspace: %s', result), vim.log.levels.ERROR)
    return nil
  end

  -- Cache the result
  state.file_trees[workspace_path] = result

  return result
end

--- Get file tree for workspace
--- @param workspace_path? string Workspace path, defaults to current
--- @return FileNode? Root file node or nil if not scanned
function M.get_file_tree(workspace_path)
  workspace_path = workspace_path or state.current_workspace
  if not workspace_path then
    return nil
  end

  return state.file_trees[workspace_path]
end

--- Find file node by path
--- @param file_path string File path to find
--- @param workspace_path? string Workspace to search in, defaults to current
--- @return FileNode? File node or nil if not found
function M.find_file_node(file_path, workspace_path)
  vim.validate('file_path', file_path, 'string')

  workspace_path = workspace_path or state.current_workspace
  local file_tree = M.get_file_tree(workspace_path)

  if not file_tree then
    return nil
  end

  local function search_tree(node)
    if node.path == file_path then
      return node
    end

    for _, child in ipairs(node.children) do
      local found = search_tree(child)
      if found then
        return found
      end
    end

    return nil
  end

  return search_tree(file_tree)
end

--- Select a file
--- @param file_path string File path to select
--- @return boolean Success
function M.select_file(file_path)
  ensure_workspaces_detected()
  vim.validate('file_path', file_path, 'string')

  -- Ensure workspace is scanned before trying to find file
  local current_workspace = state.current_workspace
  if current_workspace and not state.file_trees[current_workspace] then
    M.scan_workspace(current_workspace)
  end

  -- Find the file node
  local file_node = M.find_file_node(file_path)
  if not file_node then
    return false
  end

  -- Only select files, not directories
  if not file_node:is_file() then
    return false
  end

  -- Don't allow selection of oversized files
  if file_node.size_exceeded then
    return false
  end

  state.selected_files[file_path] = file_node
  file_node:set_selected(true)

  return true
end

--- Select a directory and all its files recursively
--- @param dir_path string Directory path to select
--- @return boolean Success
function M.select_directory_recursive(dir_path)
  ensure_workspaces_detected()
  vim.validate('dir_path', dir_path, 'string')

  -- Ensure workspace is scanned
  local current_workspace = state.current_workspace
  if current_workspace and not state.file_trees[current_workspace] then
    M.scan_workspace(current_workspace)
  end

  -- Find the directory node
  local dir_node = M.find_file_node(dir_path)
  if not dir_node then
    return false
  end

  -- Only work with directories
  if not dir_node:is_directory() then
    return false
  end

  -- Select all files in the directory recursively
  dir_node:select_recursive()

  -- Update selected_files tracking
  local all_files = dir_node:get_all_files()
  for _, file in ipairs(all_files) do
    state.selected_files[file.path] = file
  end

  return true
end

--- Deselect a directory and all its files recursively
--- @param dir_path string Directory path to deselect
--- @return boolean Success
function M.deselect_directory_recursive(dir_path)
  ensure_workspaces_detected()
  vim.validate('dir_path', dir_path, 'string')

  -- Find the directory node
  local dir_node = M.find_file_node(dir_path)
  if not dir_node then
    return false
  end

  -- Only work with directories
  if not dir_node:is_directory() then
    return false
  end

  -- Deselect all files in the directory recursively
  dir_node:deselect_recursive()

  -- Update selected_files tracking
  local all_files = dir_node:get_all_files()
  for _, file in ipairs(all_files) do
    state.selected_files[file.path] = nil
  end

  return true
end

--- Toggle directory selection recursively
--- @param dir_path string Directory path to toggle
--- @return boolean New selection state (true if now selected)
function M.toggle_directory_selection(dir_path)
  ensure_workspaces_detected()
  vim.validate('dir_path', dir_path, 'string')

  -- Find the directory node
  local dir_node = M.find_file_node(dir_path)
  if not dir_node then
    return false
  end

  -- Only work with directories
  if not dir_node:is_directory() then
    return false
  end

  -- Get current selection state and toggle accordingly
  local selection_state = dir_node:get_selection_state()

  if selection_state == 'all' then
    -- Fully selected, so deselect all
    M.deselect_directory_recursive(dir_path)
    return false
  else
    -- Partially or not selected, so select all
    M.select_directory_recursive(dir_path)
    return true
  end
end

--- Get directory selection state
--- @param dir_path string Directory path to check
--- @return string One of: 'none', 'partial', 'all', or 'not_found'
function M.get_directory_selection_state(dir_path)
  ensure_workspaces_detected()
  vim.validate('dir_path', dir_path, 'string')

  local dir_node = M.find_file_node(dir_path)
  if not dir_node then
    return 'not_found'
  end

  return dir_node:get_selection_state()
end

--- Deselect a file
--- @param file_path string File path to deselect
--- @return boolean Success
function M.deselect_file(file_path)
  vim.validate('file_path', file_path, 'string')

  local file_node = state.selected_files[file_path]
  if file_node then
    state.selected_files[file_path] = nil
    file_node:set_selected(false)
    return true
  end

  return false
end

--- Toggle file selection
--- @param file_path string File path to toggle
--- @return boolean New selection state
function M.toggle_file_selection(file_path)
  vim.validate('file_path', file_path, 'string')

  if state.selected_files[file_path] then
    M.deselect_file(file_path)
    return false
  else
    M.select_file(file_path)
    return true
  end
end

--- Check if file is selected
--- @param file_path string File path to check
--- @return boolean Whether file is selected
function M.is_file_selected(file_path)
  ensure_workspaces_detected()
  vim.validate('file_path', file_path, 'string')
  return state.selected_files[file_path] ~= nil
end

--- Get all selected files
--- @return FileNode[] List of selected file nodes
function M.get_selected_files()
  local selected = {}
  for _, node in pairs(state.selected_files) do
    table.insert(selected, node)
  end

  -- Sort by path for consistent ordering
  table.sort(selected, function(a, b)
    return a.path < b.path
  end)

  return selected
end

--- Clear all selections
function M.clear_selections()
  for _, node in pairs(state.selected_files) do
    node:set_selected(false)
  end
  state.selected_files = {}
end

--- Get selection count
--- @return number Number of selected files
function M.get_selection_count()
  return vim.tbl_count(state.selected_files)
end

--- Get workspace statistics
--- @param workspace_path? string Workspace path, defaults to current
--- @return table? Statistics or nil if no tree
function M.get_workspace_stats(workspace_path)
  workspace_path = workspace_path or state.current_workspace
  local file_tree = M.get_file_tree(workspace_path)

  if not file_tree then
    return nil
  end

  return file_discovery.get_statistics(file_tree)
end

--- Export selected files as list
--- @param relative? boolean Whether to use relative paths
--- @return string[] List of file paths
function M.export_selected_files(relative)
  local selected_files = M.get_selected_files()
  local file_paths = {}

  local base_path = relative and state.current_workspace or nil

  for _, node in ipairs(selected_files) do
    local path = base_path and node:get_relative_path(base_path) or node.path
    table.insert(file_paths, path)
  end

  return file_paths
end

--- Get internal state for testing
--- @return table Internal state
function M._get_state()
  return state
end

--- Reset state for testing
function M._reset_state()
  state = {
    workspaces = {},
    file_trees = {},
    selected_files = {},
    current_workspace = nil,
    workspaces_detected = false,
  }
end

return M
