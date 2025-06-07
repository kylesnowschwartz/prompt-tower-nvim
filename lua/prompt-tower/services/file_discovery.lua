-- lua/prompt-tower/services/file_discovery.lua
-- Service for discovering and scanning files in a workspace

local FileNode = require('prompt-tower.models.file_node')
local config = require('prompt-tower.config')

local M = {}

--- Recursively scan a directory
--- @param parent_node FileNode Parent directory node
--- @param current_depth number Current scanning depth
--- @param max_depth number Maximum depth to scan
--- @param ignore_patterns table Ignore patterns to apply
--- @param opts table Scanning options
local function _scan_recursive(parent_node, current_depth, max_depth, ignore_patterns, opts)
  if current_depth >= max_depth then
    return
  end

  local handle = vim.loop.fs_scandir(parent_node.path)
  if not handle then
    -- Cannot read directory (permission issues, etc.)
    return
  end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end

    -- Skip hidden files unless requested
    if not opts.include_hidden and name:sub(1, 1) == '.' then
      goto continue
    end

    -- Properly join paths, avoiding double slashes
    local full_path
    if parent_node.path:sub(-1) == '/' then
      full_path = parent_node.path .. name
    else
      full_path = parent_node.path .. '/' .. name
    end

    -- Create child node
    local child_node = FileNode.new({
      path = full_path,
      name = name,
      type = type == 'directory' and FileNode.TYPE.DIRECTORY or FileNode.TYPE.FILE,
    })

    -- Check ignore patterns
    if M._should_ignore(child_node, ignore_patterns) then
      goto continue
    end

    -- Check file size limits for files
    if child_node:is_file() then
      local max_size_bytes = config.get_value('max_file_size_kb') * 1024
      if child_node.size > max_size_bytes then
        goto continue
      end
    end

    -- Add to parent
    parent_node:add_child(child_node)

    -- Recursively scan directories
    if child_node:is_directory() then
      _scan_recursive(child_node, current_depth + 1, max_depth, ignore_patterns, opts)
    end

    ::continue::
  end
end

--- Scan a directory and return a file tree
--- @param root_path string Root directory to scan
--- @param opts? table Options for scanning
--- @param opts.max_depth? number Maximum depth to scan (default: 10)
--- @param opts.include_hidden? boolean Include hidden files (default: false)
--- @param opts.respect_gitignore? boolean Respect .gitignore files (default: true)
--- @param opts.custom_ignore? table Custom ignore patterns
--- @return FileNode Root file node
function M.scan_directory(root_path, opts)
  vim.validate('root_path', root_path, 'string')
  vim.validate('opts', opts or {}, 'table')

  opts = vim.tbl_extend('force', {
    max_depth = 10,
    include_hidden = false,
    respect_gitignore = true,
    custom_ignore = {},
  }, opts or {})

  -- Ensure root path exists
  local stat = vim.loop.fs_stat(root_path)
  if not stat then
    error(string.format('Directory does not exist: %s', root_path))
  end

  if stat.type ~= 'directory' then
    error(string.format('Path is not a directory: %s', root_path))
  end

  -- Create root node
  local root_node = FileNode.new({
    path = vim.fn.fnamemodify(root_path, ':p'),
    type = FileNode.TYPE.DIRECTORY,
  })

  -- Load ignore patterns
  local ignore_patterns = M._load_ignore_patterns(root_path, opts)

  -- Scan recursively
  _scan_recursive(root_node, 0, opts.max_depth, ignore_patterns, opts)

  return root_node
end

--- Load ignore patterns from various sources
--- @param root_path string Root directory path
--- @param opts table Scanning options
--- @return table Combined ignore patterns
function M._load_ignore_patterns(root_path, opts)
  local patterns = {}

  -- Add default ignore patterns from config
  local default_patterns = config.get_value('ignore_patterns') or {}
  vim.list_extend(patterns, default_patterns)

  -- Add custom patterns from options
  if opts.custom_ignore then
    vim.list_extend(patterns, opts.custom_ignore)
  end

  -- Load .gitignore if requested
  if opts.respect_gitignore and config.get_value('use_gitignore') then
    local gitignore_patterns = M._load_gitignore(root_path)
    vim.list_extend(patterns, gitignore_patterns)
  end

  -- Load .towerignore if exists
  if config.get_value('use_towerignore') then
    local towerignore_patterns = M._load_towerignore(root_path)
    vim.list_extend(patterns, towerignore_patterns)
  end

  return patterns
end

--- Load patterns from .gitignore file
--- @param root_path string Root directory path
--- @return table List of ignore patterns
function M._load_gitignore(root_path)
  local gitignore_path = root_path .. '/.gitignore'
  return M._load_ignore_file(gitignore_path)
end

--- Load patterns from .towerignore file
--- @param root_path string Root directory path
--- @return table List of ignore patterns
function M._load_towerignore(root_path)
  local towerignore_path = root_path .. '/.towerignore'
  return M._load_ignore_file(towerignore_path)
end

--- Load patterns from an ignore file
--- @param file_path string Path to ignore file
--- @return table List of ignore patterns
function M._load_ignore_file(file_path)
  local patterns = {}

  local file = io.open(file_path, 'r')
  if not file then
    return patterns
  end

  for line in file:lines() do
    -- Trim whitespace
    line = line:match('^%s*(.-)%s*$')

    -- Skip empty lines and comments
    if line ~= '' and not line:match('^#') then
      -- Convert gitignore patterns to Lua patterns (basic implementation)
      local pattern = M._convert_gitignore_pattern(line)
      if pattern then
        table.insert(patterns, pattern)
      end
    end
  end

  file:close()
  return patterns
end

--- Convert gitignore pattern to Lua pattern (basic implementation)
--- @param gitignore_pattern string Gitignore pattern
--- @return string? Lua pattern or nil if invalid
function M._convert_gitignore_pattern(gitignore_pattern)
  -- This is a simplified implementation
  -- A full implementation would need more complex glob pattern handling

  local pattern = gitignore_pattern

  -- Handle trailing slash (directories only) - remove trailing slash for pattern matching
  if pattern:sub(-1) == '/' then
    pattern = pattern:sub(1, -2)
  end

  -- Escape special Lua pattern characters except * and ?
  pattern = pattern:gsub('[%(%)%.%+%-%^%$%%%[%]]', '%%%1')

  -- Convert glob patterns
  pattern = pattern:gsub('%*', '.*') -- * -> .*
  pattern = pattern:gsub('%?', '.') -- ? -> .

  -- Handle leading slash (absolute path)
  if pattern:sub(1, 1) == '/' then
    pattern = '^' .. pattern:sub(2)
  end

  return pattern
end

--- Check if a file node should be ignored
--- @param node FileNode File node to check
--- @param patterns table List of ignore patterns
--- @return boolean True if should be ignored
function M._should_ignore(node, patterns)
  -- Always ignore .git directories
  if node.name == '.git' and node:is_directory() then
    return true
  end

  -- Check against patterns
  for _, pattern in ipairs(patterns) do
    if node.name:match(pattern) or node.path:match(pattern) then
      return true
    end
  end

  return false
end

--- Find all files matching a pattern in a file tree
--- @param root_node FileNode Root node to search from
--- @param pattern string Lua pattern to match against file names
--- @return FileNode[] List of matching file nodes
function M.find_files(root_node, pattern)
  vim.validate('root_node', root_node, 'table')
  vim.validate('pattern', pattern, 'string')

  local matches = {}

  local function search_recursive(node)
    if node:is_file() and node.name:match(pattern) then
      table.insert(matches, node)
    end

    for _, child in ipairs(node.children) do
      search_recursive(child)
    end
  end

  search_recursive(root_node)
  return matches
end

--- Get file tree statistics
--- @param root_node FileNode Root node
--- @return table Statistics about the file tree
function M.get_statistics(root_node)
  vim.validate('root_node', root_node, 'table')

  local stats = {
    total_files = 0,
    total_directories = 0,
    total_size = 0,
    max_depth = 0,
    file_types = {},
  }

  local function collect_stats(node, depth)
    depth = depth or 0
    stats.max_depth = math.max(stats.max_depth, depth)

    if node:is_file() then
      stats.total_files = stats.total_files + 1
      stats.total_size = stats.total_size + (node.size or 0)

      local ext = node:get_extension()
      if ext then
        stats.file_types[ext] = (stats.file_types[ext] or 0) + 1
      end
    else
      stats.total_directories = stats.total_directories + 1
    end

    for _, child in ipairs(node.children) do
      collect_stats(child, depth + 1)
    end
  end

  collect_stats(root_node)
  return stats
end

--- Export file tree to a simple list of paths
--- @param root_node FileNode Root node
--- @param relative_to? string Base path for relative paths
--- @return table List of file paths
function M.export_file_list(root_node, relative_to)
  vim.validate('root_node', root_node, 'table')

  local file_list = {}

  local function collect_files(node)
    if node:is_file() then
      local path = relative_to and node:get_relative_path(relative_to) or node.path
      table.insert(file_list, path)
    end

    for _, child in ipairs(node.children) do
      collect_files(child)
    end
  end

  collect_files(root_node)
  table.sort(file_list)

  return file_list
end

return M
