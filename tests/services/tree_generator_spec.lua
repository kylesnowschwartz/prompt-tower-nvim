-- tests/services/tree_generator_spec.lua
-- Tests for the tree generator service

local tree_generator = require('prompt-tower.services.tree_generator')
local FileNode = require('prompt-tower.models.file_node')
local config = require('prompt-tower.config')

describe('tree_generator', function()
  before_each(function()
    -- Reset config before each test
    config.reset()
  end)

  describe('generate_project_tree', function()
    local root_node

    before_each(function()
      -- Create a test tree structure
      root_node = FileNode.new({
        path = '/project',
        name = 'project',
        type = FileNode.TYPE.DIRECTORY,
      })

      local file1 = FileNode.new({
        path = '/project/README.md',
        name = 'README.md',
        size = 1024,
      })

      local file2 = FileNode.new({
        path = '/project/package.json',
        name = 'package.json',
        size = 512,
      })

      local src_dir = FileNode.new({
        path = '/project/src',
        name = 'src',
        type = FileNode.TYPE.DIRECTORY,
      })

      local main_file = FileNode.new({
        path = '/project/src/main.js',
        name = 'main.js',
        size = 2048,
      })

      local utils_dir = FileNode.new({
        path = '/project/src/utils',
        name = 'utils',
        type = FileNode.TYPE.DIRECTORY,
      })

      local helper_file = FileNode.new({
        path = '/project/src/utils/helper.js',
        name = 'helper.js',
        size = 256,
      })

      -- Build the tree
      root_node:add_child(file1)
      root_node:add_child(file2)
      root_node:add_child(src_dir)
      src_dir:add_child(main_file)
      src_dir:add_child(utils_dir)
      utils_dir:add_child(helper_file)
    end)

    it('should generate tree with fullFilesAndDirectories type', function()
      local tree = tree_generator.generate_project_tree(root_node, {
        tree_type = 'fullFilesAndDirectories',
        show_file_size = false,
      })

      assert.is_string(tree)
      assert.is_true(string.find(tree, 'project') ~= nil)
      assert.is_true(string.find(tree, 'README.md') ~= nil)
      assert.is_true(string.find(tree, 'src/') ~= nil)
      assert.is_true(string.find(tree, 'main.js') ~= nil)
    end)

    it('should generate tree with file sizes when enabled', function()
      local tree = tree_generator.generate_project_tree(root_node, {
        tree_type = 'fullFilesAndDirectories',
        show_file_size = true,
      })

      assert.is_string(tree)
      assert.is_true(string.find(tree, '%[1 KB%]') ~= nil) -- README.md
      assert.is_true(string.find(tree, '%[2 KB%]') ~= nil) -- main.js
      assert.is_true(string.find(tree, 'src/ %(2 files%)') ~= nil) -- Directory info
    end)

    it('should generate tree with directories only', function()
      local tree = tree_generator.generate_project_tree(root_node, {
        tree_type = 'fullDirectoriesOnly',
        show_file_size = false,
      })

      assert.is_string(tree)
      assert.is_true(string.find(tree, 'project') ~= nil)
      assert.is_true(string.find(tree, 'src/') ~= nil)
      assert.is_true(string.find(tree, 'utils/') ~= nil)
      -- Should not contain files
      assert.is_false(string.find(tree, 'README.md') ~= nil)
      assert.is_false(string.find(tree, 'main.js') ~= nil)
    end)

    it('should generate tree with selected files only', function()
      -- Select specific files (need to check array indices)
      local readme_file = nil
      local src_dir = nil
      
      for _, child in ipairs(root_node.children) do
        if child.name == 'README.md' then
          readme_file = child
        elseif child.name == 'src' then
          src_dir = child
        end
      end
      
      assert.is_not_nil(readme_file)
      assert.is_not_nil(src_dir)
      
      readme_file.selected = true
      if src_dir and src_dir.children and #src_dir.children > 0 then
        for _, child in ipairs(src_dir.children) do
          if child.name == 'main.js' then
            child.selected = true
            break
          end
        end
      end

      local tree = tree_generator.generate_project_tree(root_node, {
        tree_type = 'selectedFilesOnly',
        show_file_size = false,
      })

      assert.is_string(tree)
      assert.is_true(string.find(tree, 'README.md') ~= nil)
      assert.is_true(string.find(tree, 'main.js') ~= nil)
      -- Should not contain unselected files
      assert.is_false(string.find(tree, 'package.json') ~= nil)
    end)

    it('should return empty string when type is none', function()
      local tree = tree_generator.generate_project_tree(root_node, {
        tree_type = 'none',
      })

      assert.equals('', tree)
    end)

    it('should handle zero-byte files correctly', function()
      local zero_file = FileNode.new({
        path = '/project/empty.txt',
        name = 'empty.txt',
        size = 0,
      })
      root_node:add_child(zero_file)

      local tree = tree_generator.generate_project_tree(root_node, {
        tree_type = 'fullFilesAndDirectories',
        show_file_size = true,
      })

      assert.is_true(string.find(tree, '%[0 KB%]') ~= nil)
    end)

    it('should not have double slashes in directory names', function()
      local tree = tree_generator.generate_project_tree(root_node, {
        tree_type = 'fullFilesAndDirectories',
        show_file_size = false,
      })

      -- Should not contain double slashes
      assert.is_false(string.find(tree, '//') ~= nil)
      -- Should contain single slashes for directories
      assert.is_true(string.find(tree, 'src/') ~= nil)
      assert.is_true(string.find(tree, 'utils/') ~= nil)
    end)

    it('should use correct ASCII tree characters', function()
      local tree = tree_generator.generate_project_tree(root_node, {
        tree_type = 'fullFilesAndDirectories',
        show_file_size = false,
      })

      -- Should contain proper tree characters
      assert.is_true(string.find(tree, '├─') ~= nil) -- Middle item connector
      assert.is_true(string.find(tree, '└─') ~= nil) -- Last item connector
      -- Note: Vertical line continuation might not always be present in simple trees
      -- So let's just check for the basic tree structure
      assert.is_true(string.find(tree, 'project') ~= nil) -- Root should be present
    end)

    it('should sort files before directories', function()
      local tree = tree_generator.generate_project_tree(root_node, {
        tree_type = 'fullFilesAndDirectories',
        show_file_size = false,
      })

      local lines = vim.split(tree, '\n')
      local files_before_dirs = true
      local found_dir = false

      for _, line in ipairs(lines) do
        if string.find(line, '/') and string.find(line, '%(') then
          -- This is a directory line
          found_dir = true
        elseif found_dir and not string.find(line, '/') and not string.find(line, '│') and not string.find(line, '   ') then
          -- This is a file line after we found a directory (at same level)
          files_before_dirs = false
          break
        end
      end

      assert.is_true(files_before_dirs)
    end)
  end)

  describe('get_tree_statistics', function()
    it('should calculate correct statistics', function()
      local root = FileNode.new({
        path = '/test',
        type = FileNode.TYPE.DIRECTORY,
      })

      local file1 = FileNode.new({
        path = '/test/file1.txt',
        name = 'file1.txt',
        size = 100,
      })

      local file2 = FileNode.new({
        path = '/test/file2.js',
        name = 'file2.js',
        size = 200,
      })

      local subdir = FileNode.new({
        path = '/test/subdir',
        name = 'subdir',
        type = FileNode.TYPE.DIRECTORY,
      })

      root:add_child(file1)
      root:add_child(file2)
      root:add_child(subdir)

      local stats = tree_generator.get_tree_statistics(root)

      assert.equals(2, stats.total_files)
      assert.equals(2, stats.total_directories) -- root + subdir
      assert.equals(300, stats.total_size)
      assert.equals(1, stats.max_depth) -- root(0) -> subdir(1)
      assert.equals(1, stats.file_types.txt)
      assert.equals(1, stats.file_types.js)
    end)
  end)

  describe('file size formatting', function()
    it('should format file sizes correctly', function()
      local root = FileNode.new({
        path = '/test',
        type = FileNode.TYPE.DIRECTORY,
      })

      -- Test different file sizes
      local small_file = FileNode.new({
        path = '/test/small.txt',
        name = 'small.txt',
        size = 1024, -- Should be 1 KB
      })

      local large_file = FileNode.new({
        path = '/test/large.pdf',
        name = 'large.pdf',
        size = 2097152, -- Should be 2 MB
      })

      local zero_file = FileNode.new({
        path = '/test/empty.txt',
        name = 'empty.txt',
        size = 0, -- Should be 0 KB
      })

      root:add_child(small_file)
      root:add_child(large_file)
      root:add_child(zero_file)

      local tree = tree_generator.generate_project_tree(root, {
        tree_type = 'fullFilesAndDirectories',
        show_file_size = true,
      })

      -- Check for correct file size formatting (no decimals)
      assert.is_true(string.find(tree, '%[1 KB%]') ~= nil)
      assert.is_true(string.find(tree, '%[2 MB%]') ~= nil)
      assert.is_true(string.find(tree, '%[0 KB%]') ~= nil)
      
      -- Should not have decimal places
      assert.is_false(string.find(tree, '%[%d+%.%d+ KB%]') ~= nil)
      assert.is_false(string.find(tree, '%[%d+%.%d+ MB%]') ~= nil)
    end)
  end)

  describe('validation', function()
    it('should validate required parameters', function()
      assert.has_error(function()
        tree_generator.generate_project_tree()
      end)

      assert.has_error(function()
        tree_generator.generate_project_tree('invalid')
      end)
    end)

    it('should handle nil options gracefully', function()
      local root = FileNode.new({
        path = '/test',
        type = FileNode.TYPE.DIRECTORY,
      })

      assert.has_no_error(function()
        tree_generator.generate_project_tree(root)
      end)

      assert.has_no_error(function()
        tree_generator.generate_project_tree(root, {})
      end)
    end)
  end)
end)