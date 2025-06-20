-- lua/prompt-tower/models/file_node.lua
-- File node model for representing files and directories in the file tree

local M = {}

--- File node types
M.TYPE = {
  FILE = 'file',
  DIRECTORY = 'directory',
}

--- Create a new file node
--- @param opts table Options for creating the file node
--- @param opts.path string Absolute path to the file/directory
--- @param opts.type? string Type of node (file|directory), auto-detected if not provided
--- @param opts.name? string Display name, defaults to basename
--- @param opts.parent? FileNode Parent node
--- @param opts.selected? boolean Whether the node is selected
--- @param opts.size? number File size in bytes
--- @param opts.modified? number Last modified timestamp
--- @return FileNode
function M.new(opts)
  vim.validate('opts', opts, 'table')
  vim.validate('opts.path', opts.path, 'string')

  local path = opts.path
  local stat = vim.loop.fs_stat(path)

  local node = {
    path = path,
    name = opts.name or vim.fn.fnamemodify(path, ':t'),
    type = opts.type or (stat and stat.type or M.TYPE.FILE),
    parent = opts.parent,
    children = {},
    selected = opts.selected or false,
    size = opts.size or (stat and stat.size or 0),
    modified = opts.modified or (stat and stat.mtime.sec or 0),
    expanded = opts.expanded or false, -- For directory tree display
  }

  -- Set metatable for methods
  setmetatable(node, { __index = M })

  return node
end

--- Check if the node is a file
--- @return boolean
function M:is_file()
  return self.type == M.TYPE.FILE
end

--- Check if the node is a directory
--- @return boolean
function M:is_directory()
  return self.type == M.TYPE.DIRECTORY
end

--- Get the file extension
--- @return string? File extension without the dot, or nil if no extension
function M:get_extension()
  if not self:is_file() then
    return nil
  end

  local ext = vim.fn.fnamemodify(self.path, ':e')
  return ext ~= '' and ext or nil
end

--- Get relative path from a base directory
--- @param base_path string Base directory path
--- @return string Relative path
function M:get_relative_path(base_path)
  vim.validate('base_path', base_path, 'string')

  -- Normalize paths
  local abs_path = vim.fn.fnamemodify(self.path, ':p')
  local abs_base = vim.fn.fnamemodify(base_path, ':p')

  -- Remove trailing slash from base
  abs_base = abs_base:gsub('/$', '')

  -- Check if path is under base
  if abs_path:sub(1, #abs_base + 1) == abs_base .. '/' then
    return abs_path:sub(#abs_base + 2)
  end

  -- Fallback to absolute path if not under base
  return abs_path
end

--- Get display name with optional relative path
--- @param base_path? string Base directory for relative path calculation
--- @return string Display name
function M:get_display_name(base_path)
  if base_path then
    return self:get_relative_path(base_path)
  end
  return self.name
end

--- Check if the file should be ignored based on patterns
--- @param patterns table List of ignore patterns
--- @return boolean True if file should be ignored
function M:matches_ignore_patterns(patterns)
  vim.validate('patterns', patterns, 'table')

  for _, pattern in ipairs(patterns) do
    -- Simple pattern matching - can be enhanced later
    if self.name:match(pattern) or self.path:match(pattern) then
      return true
    end
  end

  return false
end

--- Add a child node
--- @param child FileNode Child node to add
function M:add_child(child)
  vim.validate('child', child, 'table')

  if not self:is_directory() then
    error('Cannot add child to non-directory node')
  end

  child.parent = self
  table.insert(self.children, child)

  -- Sort children: directories first, then alphabetically
  table.sort(self.children, function(a, b)
    if a:is_directory() and not b:is_directory() then
      return true
    elseif not a:is_directory() and b:is_directory() then
      return false
    else
      return a.name < b.name
    end
  end)
end

--- Remove a child node
--- @param child FileNode Child node to remove
--- @return boolean True if child was found and removed
function M:remove_child(child)
  vim.validate('child', child, 'table')

  for i, existing_child in ipairs(self.children) do
    if existing_child == child then
      table.remove(self.children, i)
      child.parent = nil
      return true
    end
  end

  return false
end

--- Find a child by name
--- @param name string Name to search for
--- @return FileNode? Child node or nil if not found
function M:find_child(name)
  vim.validate('name', name, 'string')

  for _, child in ipairs(self.children) do
    if child.name == name then
      return child
    end
  end

  return nil
end

--- Get all descendant files (recursively)
--- @return FileNode[] List of all file nodes in the subtree
function M:get_all_files()
  local files = {}

  if self:is_file() then
    table.insert(files, self)
  else
    for _, child in ipairs(self.children) do
      vim.list_extend(files, child:get_all_files())
    end
  end

  return files
end

--- Get depth of the node in the tree
--- @return number Depth (root = 0)
function M:get_depth()
  local depth = 0
  local current = self.parent

  while current do
    depth = depth + 1
    current = current.parent
  end

  return depth
end

--- Get root node of the tree
--- @return FileNode Root node
function M:get_root()
  local current = self
  while current.parent do
    current = current.parent
  end
  return current
end

--- Toggle selection state
function M:toggle_selection()
  self.selected = not self.selected
end

--- Set selection state
--- @param selected boolean Whether the node should be selected
function M:set_selected(selected)
  vim.validate('selected', selected, 'boolean')
  self.selected = selected
end

--- Recursively select/deselect this node and all descendants
--- @param selected boolean Whether to select or deselect
function M:set_selected_recursive(selected)
  vim.validate('selected', selected, 'boolean')

  -- Set selection for this node (if it's a file and not oversized)
  if self:is_file() and not self.size_exceeded then
    self.selected = selected
  end

  -- Set directory selection state for directories
  if self:is_directory() then
    self.directory_selected = selected
  end

  -- Recursively set selection for all children
  for _, child in ipairs(self.children) do
    child:set_selected_recursive(selected)
  end
end

--- Get selection state of directory considering children
--- @return string One of: 'none', 'partial', 'all'
function M:get_selection_state()
  if self:is_file() then
    return self.selected and 'all' or 'none'
  end

  -- For directories, check children
  local all_files = self:get_all_files()
  if #all_files == 0 then
    -- Empty directory: check if it was explicitly selected
    return (self.directory_selected == true) and 'all' or 'none'
  end

  local selected_count = 0
  for _, file in ipairs(all_files) do
    if file.selected then
      selected_count = selected_count + 1
    end
  end

  if selected_count == 0 then
    return 'none'
  elseif selected_count == #all_files then
    return 'all'
  else
    return 'partial'
  end
end

--- Select all descendants (files only)
function M:select_recursive()
  self:set_selected_recursive(true)
  -- Mark directory as explicitly selected (important for empty directories)
  if self:is_directory() then
    self.directory_selected = true
  end
end

--- Deselect all descendants (files only)
function M:deselect_recursive()
  self:set_selected_recursive(false)
  -- Mark directory as explicitly deselected
  if self:is_directory() then
    self.directory_selected = false
  end
end

--- Toggle recursive selection
--- If fully selected, deselect all. If partially or not selected, select all.
function M:toggle_recursive_selection()
  local state = self:get_selection_state()
  if state == 'all' then
    self:deselect_recursive()
  else
    self:select_recursive()
  end
end

--- Convert to string representation for debugging
--- @return string String representation
function M:to_string()
  local type_char = self:is_directory() and 'd' or 'f'
  local selected_char = self.selected and '*' or ' '
  return string.format('[%s%s] %s', type_char, selected_char, self.path)
end

--- Export node data for serialization
--- @return table Serializable data
function M:export()
  return {
    path = self.path,
    name = self.name,
    type = self.type,
    selected = self.selected,
    size = self.size,
    modified = self.modified,
    expanded = self.expanded,
    children = vim.tbl_map(function(child)
      return child:export()
    end, self.children),
  }
end

--- Create node from exported data
--- @param data table Exported node data
--- @param parent? FileNode Parent node
--- @return FileNode Reconstructed node
function M.from_export(data, parent)
  vim.validate('data', data, 'table')

  local node = M.new({
    path = data.path,
    name = data.name,
    type = data.type,
    parent = parent,
    selected = data.selected,
    size = data.size,
    modified = data.modified,
    expanded = data.expanded,
  })

  -- Reconstruct children
  for _, child_data in ipairs(data.children or {}) do
    local child = M.from_export(child_data, node)
    table.insert(node.children, child)
  end

  return node
end

return M
