-- lua/prompt-tower/services/template_engine.lua
-- Template engine for generating formatted context output

local M = {}

--- Replace placeholders in a template string
--- @param template string Template string with placeholders
--- @param placeholders table Key-value pairs of placeholder values
--- @return string Processed template
local function replace_placeholders(template, placeholders)
  local result = template

  for key, value in pairs(placeholders) do
    -- Replace {key} placeholders
    local pattern = '{' .. key .. '}'
    result = result:gsub(pattern:gsub('([%(%)%.%+%-%*%?%[%]%^%$%%])', '%%%1'), tostring(value or ''))
  end

  return result
end

--- Extract file information for template placeholders
--- @param file_node table File node object
--- @param workspace_root string? Workspace root path
--- @return table Placeholder values for file
local function extract_file_placeholders(file_node, workspace_root)
  local file_path = file_node.path
  local file_name = vim.fn.fnamemodify(file_path, ':t')
  local file_name_without_ext = vim.fn.fnamemodify(file_path, ':t:r')
  local file_extension = vim.fn.fnamemodify(file_path, ':e')

  -- Calculate relative path
  local relative_path = workspace_root and file_node:get_relative_path(workspace_root) or file_path

  return {
    fileName = file_name_without_ext,
    fileNameWithExtension = file_name,
    rawFilePath = relative_path,
    fullPath = file_path,
    fileExtension = file_extension ~= '' and file_extension or 'txt',
  }
end

--- Generate formatted output using template system
--- @param selected_files table List of selected file nodes
--- @param workspace_root string? Current workspace root
--- @param template_config table Template configuration
--- @return string Formatted context
function M.generate_context(selected_files, workspace_root, template_config)
  vim.validate('selected_files', selected_files, 'table')
  vim.validate('template_config', template_config, 'table')

  local file_blocks = {}

  -- Generate individual file blocks
  for _, file_node in ipairs(selected_files) do
    -- Read file content
    local file_content = M._read_file(file_node.path)
    if file_content then
      -- Extract file placeholders
      local file_placeholders = extract_file_placeholders(file_node, workspace_root)
      file_placeholders.fileContent = file_content

      -- Apply block template
      local file_block = replace_placeholders(template_config.block_template, file_placeholders)
      table.insert(file_blocks, file_block)
    end
  end

  -- Combine file blocks with separator
  local combined_blocks = table.concat(file_blocks, template_config.separator)

  -- Apply wrapper template
  local wrapper_placeholders = {
    fileBlocks = combined_blocks,
    fileCount = #selected_files,
    timestamp = os.date('%Y-%m-%d %H:%M:%S'),
    workspaceRoot = workspace_root or 'Unknown',
    treeBlock = '', -- Will be populated when tree generation is implemented
  }

  local final_context = replace_placeholders(template_config.wrapper_template, wrapper_placeholders)

  return final_context
end

--- Read file content helper
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

return M
