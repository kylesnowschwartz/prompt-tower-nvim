-- lua/prompt-tower/services/tree_generator.lua
-- Service for generating ASCII project trees

local config = require('prompt-tower.config')

local M = {}

-- Tree generation types
M.TREE_TYPES = {
  FULL_FILES_AND_DIRECTORIES = 'fullFilesAndDirectories',
  FULL_DIRECTORIES_ONLY = 'fullDirectoriesOnly',
  SELECTED_FILES_ONLY = 'selectedFilesOnly',
  NONE = 'none',
}

-- ASCII tree characters
local TREE_CHARS = {
  LAST_ITEM = '└─ ',
  MIDDLE_ITEM = '├─ ',
  VERTICAL_LINE = '│  ',
  EMPTY_SPACE = '   ',
}

-- Convert bytes to human-readable string (matches VSCode implementation)
local function format_file_size(bytes)
  if not bytes then
    return nil
  end

  -- Handle 0 byte files (VSCode shows [0 KB])
  if bytes == 0 then
    return '0 KB'
  end

  local size, unit
  if bytes > 1048576 then
    -- Use 10485.76 for exact VSCode compatibility (1024*1024/100)
    size = math.floor(bytes / 10485.76 + 0.5) / 100 -- Manual rounding since Lua lacks math.round
    unit = 'MB'
  else
    -- Use 10.24 for exact VSCode compatibility (1024/100)
    size = math.floor(bytes / 10.24 + 0.5) / 100 -- Manual rounding since Lua lacks math.round
    unit = 'KB'
  end

  -- VSCode uses no decimal places for display
  return string.format('%.0f %s', size, unit)
end

-- Calculate directory statistics
local function calculate_directory_stats(node)
  local file_count = 0
  local total_size = 0

  for _, child in ipairs(node.children) do
    if child:is_file() then
      file_count = file_count + 1
      if child.size then
        total_size = total_size + child.size
      end
    elseif child:is_directory() then
      local child_stats = calculate_directory_stats(child)
      file_count = file_count + child_stats.file_count
      total_size = total_size + child_stats.total_size
    end
  end

  return {
    file_count = file_count,
    total_size = total_size,
  }
end

-- Generate tree line for a single node
local function generate_tree_line(node, prefix, is_last, show_file_size, base_path)
  local lines = {}
  local connector = is_last and TREE_CHARS.LAST_ITEM or TREE_CHARS.MIDDLE_ITEM
  local display_name = node:get_display_name(base_path)

  -- Format the main line
  local line = prefix .. connector .. display_name

  -- Add file size if enabled and available
  if show_file_size and node:is_file() and node.size then
    local size_str = format_file_size(node.size)
    if size_str then
      line = line .. ' [' .. size_str .. ']'
    end
  end

  -- Add directory info if it's a directory (matches VSCode format exactly)
  if node:is_directory() then
    local stats = calculate_directory_stats(node)
    local file_text = stats.file_count == 1 and 'file' or 'files'

    -- Add trailing slash if not already present, then add file count in parentheses
    if not display_name:match('/$') then
      line = line .. '/'
    end
    line = line .. ' (' .. stats.file_count .. ' ' .. file_text .. ')'

    -- Only add size if showFileSize is enabled and we have valid size data
    if show_file_size and stats.total_size > 0 then
      local size_str = format_file_size(stats.total_size)
      if size_str then
        line = line .. ' [' .. size_str .. ']'
      end
    end
  end

  table.insert(lines, line)
  return lines
end

-- Sort children with files before directories, both alphabetically
local function sort_children(children)
  local files = {}
  local directories = {}

  for _, child in ipairs(children) do
    if child:is_file() then
      table.insert(files, child)
    else
      table.insert(directories, child)
    end
  end

  -- Sort both lists alphabetically
  table.sort(files, function(a, b)
    return a.name < b.name
  end)
  table.sort(directories, function(a, b)
    return a.name < b.name
  end)

  -- Return files first, then directories
  local sorted = {}
  for _, file in ipairs(files) do
    table.insert(sorted, file)
  end
  for _, dir in ipairs(directories) do
    table.insert(sorted, dir)
  end

  return sorted
end

-- Generate tree recursively
local function generate_tree_recursive(node, prefix, tree_type, show_file_size, base_path)
  local lines = {}

  if not node or not node.children then
    return lines
  end

  local children = sort_children(node.children)

  -- Filter children based on tree type
  local filtered_children = {}
  for _, child in ipairs(children) do
    local should_include = false

    if tree_type == M.TREE_TYPES.FULL_FILES_AND_DIRECTORIES then
      should_include = true
    elseif tree_type == M.TREE_TYPES.FULL_DIRECTORIES_ONLY then
      should_include = child:is_directory()
    elseif tree_type == M.TREE_TYPES.SELECTED_FILES_ONLY then
      should_include = child.selected or (child:is_directory() and #child.children > 0)
    end

    if should_include then
      table.insert(filtered_children, child)
    end
  end

  for i, child in ipairs(filtered_children) do
    local is_last = (i == #filtered_children)
    local child_prefix = prefix .. (is_last and TREE_CHARS.EMPTY_SPACE or TREE_CHARS.VERTICAL_LINE)

    -- Generate line for this child
    local child_lines = generate_tree_line(child, prefix, is_last, show_file_size, base_path)
    for _, line in ipairs(child_lines) do
      table.insert(lines, line)
    end

    -- Recursively generate children if it's a directory
    if child:is_directory() then
      local recursive_lines = generate_tree_recursive(child, child_prefix, tree_type, show_file_size, base_path)
      for _, line in ipairs(recursive_lines) do
        table.insert(lines, line)
      end
    end
  end

  return lines
end

-- Generate project tree for a workspace root
function M.generate_project_tree(root_node, options)
  vim.validate({
    root_node = { root_node, 'table' },
    options = { options, 'table', true },
  })

  options = options or {}

  -- Get configuration
  local tree_config = config.get_value('project_tree') or {}
  local tree_type = options.tree_type or tree_config.type or M.TREE_TYPES.FULL_FILES_AND_DIRECTORIES
  local show_file_size = options.show_file_size
  if show_file_size == nil then
    show_file_size = tree_config.show_file_size or false
  end
  local base_path = options.base_path or root_node.path

  -- Return empty if tree generation is disabled
  if tree_type == M.TREE_TYPES.NONE then
    return ''
  end

  local lines = {}

  -- Add root node line
  local root_display = root_node:get_display_name()
  if root_display == '' or root_display == '.' then
    root_display = vim.fn.fnamemodify(root_node.path, ':t')
  end
  table.insert(lines, root_display)

  -- Generate tree for children
  local tree_lines = generate_tree_recursive(root_node, '', tree_type, show_file_size, base_path)
  for _, line in ipairs(tree_lines) do
    table.insert(lines, line)
  end

  return table.concat(lines, '\n')
end

-- Generate tree for selected files only
function M.generate_selected_files_tree(root_node, selected_files, options)
  vim.validate({
    root_node = { root_node, 'table' },
    selected_files = { selected_files, 'table' },
    options = { options, 'table', true },
  })

  options = options or {}
  options.tree_type = M.TREE_TYPES.SELECTED_FILES_ONLY

  -- Create a filtered tree with only selected files and their parent directories
  local function mark_selected_paths(node)
    if not node then
      return false
    end

    local has_selected_child = false

    -- Check if this node is selected
    if node.selected then
      has_selected_child = true
    end

    -- Recursively check children
    if node.children then
      for _, child in ipairs(node.children) do
        if mark_selected_paths(child) then
          has_selected_child = true
        end
      end
    end

    return has_selected_child
  end

  -- Mark the tree with selection info
  mark_selected_paths(root_node)

  return M.generate_project_tree(root_node, options)
end

-- Get tree statistics
function M.get_tree_statistics(root_node)
  vim.validate({
    root_node = { root_node, 'table' },
  })

  local stats = {
    total_files = 0,
    total_directories = 0,
    total_size = 0,
    max_depth = 0,
    file_types = {},
  }

  local function collect_stats(node, depth)
    stats.max_depth = math.max(stats.max_depth, depth)

    if node:is_file() then
      stats.total_files = stats.total_files + 1
      if node.size then
        stats.total_size = stats.total_size + node.size
      end

      local ext = node:get_extension()
      if ext then
        stats.file_types[ext] = (stats.file_types[ext] or 0) + 1
      end
    elseif node:is_directory() then
      stats.total_directories = stats.total_directories + 1
    end

    if node.children then
      for _, child in ipairs(node.children) do
        collect_stats(child, depth + 1)
      end
    end
  end

  collect_stats(root_node, 0)
  return stats
end

return M
