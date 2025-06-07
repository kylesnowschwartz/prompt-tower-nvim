-- tests/models/file_node_spec.lua
-- Tests for the FileNode model

local FileNode = require('prompt-tower.models.file_node')

describe('FileNode', function()
  describe('new', function()
    it('should create a file node with required parameters', function()
      local node = FileNode.new({ path = '/tmp/test.txt' })

      assert.equals('/tmp/test.txt', node.path)
      assert.equals('test.txt', node.name)
      assert.equals(FileNode.TYPE.FILE, node.type)
      assert.is_false(node.selected)
      assert.is_table(node.children)
      assert.equals(0, #node.children)
    end)

    it('should accept optional parameters', function()
      local node = FileNode.new({
        path = '/tmp/custom.txt',
        name = 'Custom Name',
        type = FileNode.TYPE.DIRECTORY,
        selected = true,
        size = 1024,
        modified = 1234567890,
      })

      assert.equals('/tmp/custom.txt', node.path)
      assert.equals('Custom Name', node.name)
      assert.equals(FileNode.TYPE.DIRECTORY, node.type)
      assert.is_true(node.selected)
      assert.equals(1024, node.size)
      assert.equals(1234567890, node.modified)
    end)

    it('should validate required path parameter', function()
      assert.has_error(function()
        FileNode.new({})
      end)

      assert.has_error(function()
        FileNode.new({ path = 123 })
      end)
    end)
  end)

  describe('type checking', function()
    it('should correctly identify files', function()
      local file_node = FileNode.new({ path = '/tmp/file.txt', type = FileNode.TYPE.FILE })

      assert.is_true(file_node:is_file())
      assert.is_false(file_node:is_directory())
    end)

    it('should correctly identify directories', function()
      local dir_node = FileNode.new({ path = '/tmp/dir', type = FileNode.TYPE.DIRECTORY })

      assert.is_false(dir_node:is_file())
      assert.is_true(dir_node:is_directory())
    end)
  end)

  describe('get_extension', function()
    it('should return extension for files', function()
      local node = FileNode.new({ path = '/tmp/test.txt', type = FileNode.TYPE.FILE })
      assert.equals('txt', node:get_extension())

      local node2 = FileNode.new({ path = '/tmp/script.lua', type = FileNode.TYPE.FILE })
      assert.equals('lua', node2:get_extension())
    end)

    it('should return nil for files without extension', function()
      local node = FileNode.new({ path = '/tmp/README', type = FileNode.TYPE.FILE })
      assert.is_nil(node:get_extension())
    end)

    it('should return nil for directories', function()
      local node = FileNode.new({ path = '/tmp/dir.ext', type = FileNode.TYPE.DIRECTORY })
      assert.is_nil(node:get_extension())
    end)
  end)

  describe('get_relative_path', function()
    it('should return relative path when under base', function()
      local node = FileNode.new({ path = '/home/user/project/src/file.lua' })
      local relative = node:get_relative_path('/home/user/project')

      assert.equals('src/file.lua', relative)
    end)

    it('should return absolute path when not under base', function()
      local node = FileNode.new({ path = '/tmp/file.txt' })
      local result = node:get_relative_path('/home/user/project')

      -- Should return absolute path when not under base
      assert.is_true(result:match('^/'))
    end)
  end)

  describe('get_display_name', function()
    it('should return name when no base path provided', function()
      local node = FileNode.new({ path = '/tmp/test.txt' })
      assert.equals('test.txt', node:get_display_name())
    end)

    it('should return relative path when base path provided', function()
      local node = FileNode.new({ path = '/home/user/project/src/file.lua' })
      local display = node:get_display_name('/home/user/project')

      assert.equals('src/file.lua', display)
    end)
  end)

  describe('matches_ignore_patterns', function()
    it('should match simple patterns', function()
      local node = FileNode.new({ path = '/tmp/test.txt' })

      assert.is_true(node:matches_ignore_patterns({ 'test%.txt' }))
      assert.is_false(node:matches_ignore_patterns({ 'other%.txt' }))
    end)

    it('should match path patterns', function()
      local node = FileNode.new({ path = '/tmp/node_modules/package.json' })

      assert.is_true(node:matches_ignore_patterns({ 'node_modules' }))
    end)

    it('should handle empty patterns', function()
      local node = FileNode.new({ path = '/tmp/test.txt' })

      assert.is_false(node:matches_ignore_patterns({}))
    end)
  end)

  describe('child management', function()
    local parent, child1, child2

    before_each(function()
      parent = FileNode.new({ path = '/tmp/dir', type = FileNode.TYPE.DIRECTORY })
      child1 = FileNode.new({ path = '/tmp/dir/file1.txt' })
      child2 = FileNode.new({ path = '/tmp/dir/file2.txt' })
    end)

    it('should add children to directory nodes', function()
      parent:add_child(child1)

      assert.equals(1, #parent.children)
      assert.equals(child1, parent.children[1])
      assert.equals(parent, child1.parent)
    end)

    it('should error when adding children to file nodes', function()
      local file_node = FileNode.new({ path = '/tmp/file.txt', type = FileNode.TYPE.FILE })

      assert.has_error(function()
        file_node:add_child(child1)
      end)
    end)

    it('should sort children with directories first', function()
      local file_child = FileNode.new({ path = '/tmp/dir/file.txt', type = FileNode.TYPE.FILE })
      local dir_child = FileNode.new({ path = '/tmp/dir/subdir', type = FileNode.TYPE.DIRECTORY })

      parent:add_child(file_child)
      parent:add_child(dir_child)

      assert.equals(2, #parent.children)
      assert.equals(dir_child, parent.children[1]) -- Directory first
      assert.equals(file_child, parent.children[2]) -- File second
    end)

    it('should remove children', function()
      parent:add_child(child1)
      parent:add_child(child2)

      local removed = parent:remove_child(child1)

      assert.is_true(removed)
      assert.equals(1, #parent.children)
      assert.equals(child2, parent.children[1])
      assert.is_nil(child1.parent)
    end)

    it('should return false when removing non-existent child', function()
      local other_child = FileNode.new({ path = '/tmp/other.txt' })

      local removed = parent:remove_child(other_child)

      assert.is_false(removed)
    end)

    it('should find children by name', function()
      parent:add_child(child1)
      parent:add_child(child2)

      local found = parent:find_child('file1.txt')
      assert.equals(child1, found)

      local not_found = parent:find_child('nonexistent.txt')
      assert.is_nil(not_found)
    end)
  end)

  describe('tree traversal', function()
    local root, subdir, file1, file2, file3

    before_each(function()
      -- Create tree structure:
      -- root/
      --   file1.txt
      --   subdir/
      --     file2.txt
      --     file3.txt
      root = FileNode.new({ path = '/tmp/root', type = FileNode.TYPE.DIRECTORY })
      subdir = FileNode.new({ path = '/tmp/root/subdir', type = FileNode.TYPE.DIRECTORY })
      file1 = FileNode.new({ path = '/tmp/root/file1.txt' })
      file2 = FileNode.new({ path = '/tmp/root/subdir/file2.txt' })
      file3 = FileNode.new({ path = '/tmp/root/subdir/file3.txt' })

      root:add_child(file1)
      root:add_child(subdir)
      subdir:add_child(file2)
      subdir:add_child(file3)
    end)

    it('should get all files recursively', function()
      local all_files = root:get_all_files()

      assert.equals(3, #all_files)
      assert.is_true(vim.tbl_contains(all_files, file1))
      assert.is_true(vim.tbl_contains(all_files, file2))
      assert.is_true(vim.tbl_contains(all_files, file3))
    end)

    it('should return single file for file nodes', function()
      local files = file1:get_all_files()

      assert.equals(1, #files)
      assert.equals(file1, files[1])
    end)

    it('should calculate depth correctly', function()
      assert.equals(0, root:get_depth())
      assert.equals(1, file1:get_depth())
      assert.equals(1, subdir:get_depth())
      assert.equals(2, file2:get_depth())
      assert.equals(2, file3:get_depth())
    end)

    it('should find root node', function()
      assert.equals(root, root:get_root())
      assert.equals(root, file1:get_root())
      assert.equals(root, subdir:get_root())
      assert.equals(root, file2:get_root())
      assert.equals(root, file3:get_root())
    end)
  end)

  describe('selection', function()
    local node

    before_each(function()
      node = FileNode.new({ path = '/tmp/test.txt' })
    end)

    it('should toggle selection state', function()
      assert.is_false(node.selected)

      node:toggle_selection()
      assert.is_true(node.selected)

      node:toggle_selection()
      assert.is_false(node.selected)
    end)

    it('should set selection state', function()
      node:set_selected(true)
      assert.is_true(node.selected)

      node:set_selected(false)
      assert.is_false(node.selected)
    end)
  end)

  describe('serialization', function()
    it('should export node data', function()
      local node = FileNode.new({
        path = '/tmp/test.txt',
        selected = true,
        size = 1024,
      })

      local exported = node:export()

      assert.equals('/tmp/test.txt', exported.path)
      assert.equals('test.txt', exported.name)
      assert.equals(FileNode.TYPE.FILE, exported.type)
      assert.is_true(exported.selected)
      assert.equals(1024, exported.size)
      assert.is_table(exported.children)
    end)

    it('should export with children', function()
      local parent = FileNode.new({ path = '/tmp/dir', type = FileNode.TYPE.DIRECTORY })
      local child = FileNode.new({ path = '/tmp/dir/file.txt' })
      parent:add_child(child)

      local exported = parent:export()

      assert.equals(1, #exported.children)
      assert.equals('/tmp/dir/file.txt', exported.children[1].path)
    end)

    it('should reconstruct from exported data', function()
      local original = FileNode.new({
        path = '/tmp/test.txt',
        selected = true,
        size = 1024,
      })

      local exported = original:export()
      local reconstructed = FileNode.from_export(exported)

      assert.equals(original.path, reconstructed.path)
      assert.equals(original.name, reconstructed.name)
      assert.equals(original.type, reconstructed.type)
      assert.equals(original.selected, reconstructed.selected)
      assert.equals(original.size, reconstructed.size)
    end)
  end)

  describe('to_string', function()
    it('should provide readable string representation', function()
      local file_node = FileNode.new({ path = '/tmp/test.txt', selected = true })
      local dir_node = FileNode.new({ path = '/tmp/dir', type = FileNode.TYPE.DIRECTORY })

      local file_str = file_node:to_string()
      local dir_str = dir_node:to_string()

      assert.is_true(file_str:match('%[f%*%]')) -- file, selected
      assert.is_true(dir_str:match('%[d %]')) -- directory, not selected
    end)
  end)
end)
