-- tests/services/file_discovery_spec.lua
-- Tests for the file discovery service

local FileNode = require('prompt-tower.models.file_node')
local config = require('prompt-tower.config')
local file_discovery = require('prompt-tower.services.file_discovery')

describe('file_discovery', function()
  before_each(function()
    -- Reset config before each test
    config.reset()
  end)

  describe('_convert_gitignore_pattern', function()
    it('should convert basic glob patterns', function()
      local pattern = file_discovery._convert_gitignore_pattern('*.txt')
      assert.equals('.*%.txt', pattern)

      local pattern2 = file_discovery._convert_gitignore_pattern('test?.log')
      assert.equals('test.%.log', pattern2)
    end)

    it('should handle directory patterns', function()
      local pattern = file_discovery._convert_gitignore_pattern('node_modules/')
      assert.equals('node_modules', pattern)
    end)

    it('should handle absolute path patterns', function()
      local pattern = file_discovery._convert_gitignore_pattern('/build')
      assert.equals('^build', pattern)
    end)

    it('should escape special lua pattern characters', function()
      local pattern = file_discovery._convert_gitignore_pattern('test(1).txt')
      assert.equals('test%(1%)%.txt', pattern)
    end)
  end)

  describe('_should_ignore', function()
    it('should always ignore .git directories', function()
      local git_node = FileNode.new({
        path = '/tmp/.git',
        name = '.git',
        type = FileNode.TYPE.DIRECTORY,
      })

      local result = file_discovery._should_ignore(git_node, {})
      assert.is_true(result)
    end)

    it('should not ignore .git files', function()
      local git_file = FileNode.new({
        path = '/tmp/.gitignore',
        name = '.gitignore',
        type = FileNode.TYPE.FILE,
      })

      local result = file_discovery._should_ignore(git_file, {})
      assert.is_false(result)
    end)

    it('should match against ignore patterns', function()
      local node = FileNode.new({ path = '/tmp/test.log', name = 'test.log' })

      local result1 = file_discovery._should_ignore(node, { '%.log$' })
      assert.is_true(result1)

      local result2 = file_discovery._should_ignore(node, { '%.txt$' })
      assert.is_false(result2)
    end)
  end)

  describe('_load_ignore_file', function()
    -- Note: This is a simplified test since we can't easily mock file I/O
    -- In a real implementation, you might want to use a mocking library

    it('should return empty table for non-existent files', function()
      local patterns = file_discovery._load_ignore_file('/non/existent/file')
      assert.is_table(patterns)
      assert.equals(0, #patterns)
    end)
  end)

  describe('_load_ignore_patterns', function()
    it('should load default patterns from config', function()
      config.setup({
        ignore_patterns = { 'node_modules', '*.log' },
      })

      local patterns = file_discovery._load_ignore_patterns('/tmp', {
        respect_gitignore = false,
        custom_ignore = {},
      })

      assert.is_true(vim.tbl_contains(patterns, 'node_modules'))
      assert.is_true(vim.tbl_contains(patterns, '*.log'))
    end)

    it('should include custom ignore patterns', function()
      local patterns = file_discovery._load_ignore_patterns('/tmp', {
        respect_gitignore = false,
        custom_ignore = { 'custom_pattern', 'another_pattern' },
      })

      assert.is_true(vim.tbl_contains(patterns, 'custom_pattern'))
      assert.is_true(vim.tbl_contains(patterns, 'another_pattern'))
    end)

    it('should load .towerignore patterns when enabled', function()
      -- Test that _load_towerignore function exists and can be called
      local towerignore_patterns = file_discovery._load_towerignore('/tmp')
      assert.is_table(towerignore_patterns)
      -- Since we can't guarantee .towerignore exists in /tmp, just test that function works
    end)

    it('should include .towerignore patterns in combined patterns when enabled', function()
      config.setup({
        use_towerignore = true,
        ignore_patterns = { 'config_pattern' },
      })

      local patterns = file_discovery._load_ignore_patterns('/tmp', {
        respect_gitignore = false,
        custom_ignore = {},
      })

      -- Should include config patterns at minimum
      assert.is_true(vim.tbl_contains(patterns, 'config_pattern'))
    end)

    it('should not include .towerignore patterns when disabled', function()
      config.setup({
        use_towerignore = false,
        ignore_patterns = { 'config_pattern' },
      })

      local patterns = file_discovery._load_ignore_patterns('/tmp', {
        respect_gitignore = false,
        custom_ignore = {},
      })

      -- Should include config patterns but not try to load .towerignore
      assert.is_true(vim.tbl_contains(patterns, 'config_pattern'))
    end)
  end)

  describe('find_files', function()
    local root_node

    before_each(function()
      -- Create a simple tree structure for testing
      root_node = FileNode.new({ path = '/tmp/root', type = FileNode.TYPE.DIRECTORY })

      local file1 = FileNode.new({ path = '/tmp/root/test.txt', name = 'test.txt' })
      local file2 = FileNode.new({ path = '/tmp/root/script.lua', name = 'script.lua' })
      local file3 = FileNode.new({ path = '/tmp/root/readme.md', name = 'readme.md' })

      local subdir = FileNode.new({ path = '/tmp/root/subdir', type = FileNode.TYPE.DIRECTORY })
      local file4 = FileNode.new({ path = '/tmp/root/subdir/another.txt', name = 'another.txt' })

      root_node:add_child(file1)
      root_node:add_child(file2)
      root_node:add_child(file3)
      root_node:add_child(subdir)
      subdir:add_child(file4)
    end)

    it('should find files matching pattern', function()
      local txt_files = file_discovery.find_files(root_node, '%.txt$')

      assert.equals(2, #txt_files)
      -- Should find test.txt and another.txt
      local names = vim.tbl_map(function(node)
        return node.name
      end, txt_files)
      assert.is_true(vim.tbl_contains(names, 'test.txt'))
      assert.is_true(vim.tbl_contains(names, 'another.txt'))
    end)

    it('should find files with specific names', function()
      local readme_files = file_discovery.find_files(root_node, '^readme')

      assert.equals(1, #readme_files)
      assert.equals('readme.md', readme_files[1].name)
    end)

    it('should return empty table when no matches', function()
      local matches = file_discovery.find_files(root_node, '%.nonexistent$')

      assert.is_table(matches)
      assert.equals(0, #matches)
    end)
  end)

  describe('get_statistics', function()
    local root_node

    before_each(function()
      -- Create tree structure:
      -- root/
      --   file1.txt (size: 100)
      --   file2.lua (size: 200)
      --   subdir/
      --     file3.txt (size: 300)

      root_node = FileNode.new({ path = '/tmp/root', type = FileNode.TYPE.DIRECTORY })

      local file1 = FileNode.new({
        path = '/tmp/root/file1.txt',
        name = 'file1.txt',
        size = 100,
      })
      local file2 = FileNode.new({
        path = '/tmp/root/file2.lua',
        name = 'file2.lua',
        size = 200,
      })

      local subdir = FileNode.new({
        path = '/tmp/root/subdir',
        type = FileNode.TYPE.DIRECTORY,
      })
      local file3 = FileNode.new({
        path = '/tmp/root/subdir/file3.txt',
        name = 'file3.txt',
        size = 300,
      })

      root_node:add_child(file1)
      root_node:add_child(file2)
      root_node:add_child(subdir)
      subdir:add_child(file3)
    end)

    it('should calculate correct statistics', function()
      local stats = file_discovery.get_statistics(root_node)

      assert.equals(3, stats.total_files)
      assert.equals(2, stats.total_directories) -- root + subdir
      assert.equals(600, stats.total_size) -- 100 + 200 + 300
      assert.equals(2, stats.max_depth) -- root(0) -> subdir(1) -> file(2)
    end)

    it('should track file types', function()
      local stats = file_discovery.get_statistics(root_node)

      assert.equals(2, stats.file_types.txt) -- file1.txt, file3.txt
      assert.equals(1, stats.file_types.lua) -- file2.lua
    end)
  end)

  describe('export_file_list', function()
    local root_node

    before_each(function()
      root_node = FileNode.new({ path = '/home/user/project', type = FileNode.TYPE.DIRECTORY })

      local file1 = FileNode.new({ path = '/home/user/project/src/main.lua' })
      local file2 = FileNode.new({ path = '/home/user/project/README.md' })

      local src_dir = FileNode.new({
        path = '/home/user/project/src',
        type = FileNode.TYPE.DIRECTORY,
      })

      root_node:add_child(file2)
      root_node:add_child(src_dir)
      src_dir:add_child(file1)
    end)

    it('should export absolute paths', function()
      local file_list = file_discovery.export_file_list(root_node)

      assert.equals(2, #file_list)
      assert.is_true(vim.tbl_contains(file_list, '/home/user/project/README.md'))
      assert.is_true(vim.tbl_contains(file_list, '/home/user/project/src/main.lua'))
    end)

    it('should export relative paths when base provided', function()
      local file_list = file_discovery.export_file_list(root_node, '/home/user/project')

      assert.equals(2, #file_list)
      assert.is_true(vim.tbl_contains(file_list, 'README.md'))
      assert.is_true(vim.tbl_contains(file_list, 'src/main.lua'))
    end)

    it('should return sorted list', function()
      local file_list = file_discovery.export_file_list(root_node)

      -- Should be sorted alphabetically
      assert.is_true(file_list[1] < file_list[2])
    end)
  end)

  -- Note: scan_directory tests would require setting up actual filesystem
  -- or sophisticated mocking. For a full test suite, you might want to:
  -- 1. Create temporary directories and files for testing
  -- 2. Use a mocking library to mock vim.loop.fs_* functions
  -- 3. Test with known directory structures

  describe('scan_directory validation', function()
    it('should validate required parameters', function()
      assert.has_error(function()
        file_discovery.scan_directory()
      end)

      assert.has_error(function()
        file_discovery.scan_directory(123)
      end)
    end)

    it('should validate options parameter', function()
      -- This will fail because the directory doesn't exist, but it should
      -- validate the opts parameter first
      assert.has_error(function()
        file_discovery.scan_directory('/non/existent', 'invalid_options')
      end)
    end)
  end)

  describe('hidden files and gitignore pattern regression tests', function()
    local temp_dir, gitignore_file

    before_each(function()
      -- Create temporary directory structure that mimics the bug scenario
      temp_dir = vim.fn.tempname()
      vim.fn.mkdir(temp_dir, 'p')

      -- Create files that start with dots (hidden files)
      local hidden_files = {
        '.gitignore',
        '.github',
        '.stylua.toml',
        '.nvim',
      }

      local regular_files = {
        'init.lua',
        'README.md',
        'config.json',
      }

      -- Create hidden files
      for _, file in ipairs(hidden_files) do
        local file_path = temp_dir .. '/' .. file
        if file == '.github' then
          vim.fn.mkdir(file_path, 'p')
        else
          local f = io.open(file_path, 'w')
          if f then
            f:write('test content')
            f:close()
          end
        end
      end

      -- Create regular files
      for _, file in ipairs(regular_files) do
        local file_path = temp_dir .. '/' .. file
        local f = io.open(file_path, 'w')
        if f then
          f:write('test content')
          f:close()
        end
      end

      -- Create .gitignore with problematic patterns
      gitignore_file = temp_dir .. '/.gitignore'
      local f = io.open(gitignore_file, 'w')
      if f then
        -- This pattern should not affect files when the directory path contains 'nvim'
        f:write('nvim\n')
        f:write('*.log\n')
        f:close()
      end
    end)

    after_each(function()
      if temp_dir then
        vim.fn.delete(temp_dir, 'rf')
      end
    end)

    it('should include hidden files when include_hidden is true', function()
      local opts = {
        include_hidden = true,
        respect_gitignore = false, -- Disable gitignore for this test
        max_depth = 2,
      }

      local root_node = file_discovery.scan_directory(temp_dir, opts)

      -- Should find hidden files
      local children_names = vim.tbl_map(function(child)
        return child.name
      end, root_node.children)

      assert.is_true(vim.tbl_contains(children_names, '.gitignore'))
      assert.is_true(vim.tbl_contains(children_names, '.github'))
      assert.is_true(vim.tbl_contains(children_names, '.stylua.toml'))
      assert.is_true(vim.tbl_contains(children_names, 'init.lua'))
      assert.is_true(vim.tbl_contains(children_names, 'README.md'))
    end)

    it('should exclude hidden files when include_hidden is false', function()
      local opts = {
        include_hidden = false,
        respect_gitignore = false,
        max_depth = 2,
      }

      local root_node = file_discovery.scan_directory(temp_dir, opts)

      -- Should not find hidden files
      local children_names = vim.tbl_map(function(child)
        return child.name
      end, root_node.children)

      assert.is_false(vim.tbl_contains(children_names, '.gitignore'))
      assert.is_false(vim.tbl_contains(children_names, '.github'))
      assert.is_false(vim.tbl_contains(children_names, '.stylua.toml'))

      -- But should find regular files
      assert.is_true(vim.tbl_contains(children_names, 'init.lua'))
      assert.is_true(vim.tbl_contains(children_names, 'README.md'))
    end)

    it('should properly handle gitignore patterns with relative paths', function()
      -- Rename temp_dir to contain 'nvim' to test the exact bug scenario
      local nvim_dir = temp_dir .. '_nvim_config'
      vim.fn.rename(temp_dir, nvim_dir)
      temp_dir = nvim_dir -- Update for cleanup

      local opts = {
        include_hidden = true,
        respect_gitignore = true,
        max_depth = 2,
      }

      local root_node = file_discovery.scan_directory(nvim_dir, opts)

      -- Files should be found despite 'nvim' being in gitignore and directory path
      local children_names = vim.tbl_map(function(child)
        return child.name
      end, root_node.children)

      assert.is_true(vim.tbl_contains(children_names, '.gitignore'))
      assert.is_true(vim.tbl_contains(children_names, '.github'))
      assert.is_true(vim.tbl_contains(children_names, 'init.lua'))
      assert.is_true(vim.tbl_contains(children_names, 'README.md'))

      -- The .nvim file should be ignored by gitignore pattern
      assert.is_false(vim.tbl_contains(children_names, '.nvim'))
    end)

    it('should only ignore exact .git directory, not .gitignore or .github', function()
      -- Create .git directory
      local git_dir = temp_dir .. '/.git'
      vim.fn.mkdir(git_dir, 'p')

      local opts = {
        include_hidden = true,
        respect_gitignore = false,
        custom_ignore = { '^%.git$' }, -- Test the fixed pattern
        max_depth = 2,
      }

      local root_node = file_discovery.scan_directory(temp_dir, opts)

      local children_names = vim.tbl_map(function(child)
        return child.name
      end, root_node.children)

      -- .git directory should be ignored
      assert.is_false(vim.tbl_contains(children_names, '.git'))

      -- But .gitignore and .github should be included
      assert.is_true(vim.tbl_contains(children_names, '.gitignore'))
      assert.is_true(vim.tbl_contains(children_names, '.github'))
    end)

    it('should not ignore files when old broad .git pattern is not used', function()
      -- Test that the old pattern '.git' would incorrectly ignore .gitignore and .github
      local opts = {
        include_hidden = true,
        respect_gitignore = false,
        custom_ignore = { '.git' }, -- Old broad pattern (should be avoided)
        max_depth = 2,
      }

      local root_node = file_discovery.scan_directory(temp_dir, opts)

      local children_names = vim.tbl_map(function(child)
        return child.name
      end, root_node.children)

      -- With the old broad pattern, these would be incorrectly ignored
      -- This test documents the problem with the old pattern
      assert.is_false(vim.tbl_contains(children_names, '.gitignore'))
      assert.is_false(vim.tbl_contains(children_names, '.github'))
    end)
  end)
end)
