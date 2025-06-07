-- tests/services/template_engine_spec.lua
-- Unit tests for template engine service

local config = require('prompt-tower.config')
local file_node = require('prompt-tower.models.file_node')
local template_engine = require('prompt-tower.services.template_engine')

describe('template_engine', function()
  local test_dir
  local test_files

  before_each(function()
    -- Reset config to defaults
    config.reset()

    -- Create temporary test directory and files
    test_dir = vim.fn.tempname()
    vim.fn.mkdir(test_dir, 'p')

    test_files = {
      main_lua = test_dir .. '/main.lua',
      config_js = test_dir .. '/src/config.js',
      readme_md = test_dir .. '/README.md',
    }

    -- Create test files with known content
    local main_content = '-- Main application entry point\nlocal M = {}\nreturn M'
    local config_content = '// Configuration module\nconst config = {};\nexport default config;'
    local readme_content = '# Test Project\n\nThis is a test README file.'

    vim.fn.writefile(vim.split(main_content, '\n'), test_files.main_lua)
    vim.fn.mkdir(vim.fn.fnamemodify(test_files.config_js, ':h'), 'p')
    vim.fn.writefile(vim.split(config_content, '\n'), test_files.config_js)
    vim.fn.writefile(vim.split(readme_content, '\n'), test_files.readme_md)
  end)

  after_each(function()
    -- Clean up test files
    if test_dir and vim.fn.isdirectory(test_dir) == 1 then
      vim.fn.delete(test_dir, 'rf')
    end
  end)

  describe('_read_file', function()
    it('should read existing file content correctly', function()
      local content = template_engine._read_file(test_files.main_lua)
      assert.is_not_nil(content)
      assert.is_true(string.find(content, 'Main application entry point') ~= nil)
      assert.is_true(string.find(content, 'local M = {}') ~= nil)
    end)

    it('should return nil for non-existent files', function()
      local content = template_engine._read_file('/non/existent/file.txt')
      assert.is_nil(content)
    end)

    it('should handle empty files', function()
      local empty_file = test_dir .. '/empty.txt'
      vim.fn.writefile({}, empty_file)

      local content = template_engine._read_file(empty_file)
      assert.is_not_nil(content)
      assert.equals('', content)
    end)
  end)

  describe('generate_context', function()
    local function create_test_file_nodes()
      local nodes = {}
      for name, path in pairs(test_files) do
        local node = file_node.new({ path = path })
        node.is_directory = false
        table.insert(nodes, node)
      end
      return nodes
    end

    describe('XML format', function()
      it('should generate correct XML structure', function()
        config.setup({
          output_format = {
            default_format = 'xml',
          },
        })

        local nodes = create_test_file_nodes()
        local template_config = config.get_template_config()
        local context = template_engine.generate_context(nodes, test_dir, template_config)

        -- Check XML structure
        assert.is_true(string.find(context, '<file name="') ~= nil)
        assert.is_true(string.find(context, 'path="') ~= nil)
        assert.is_true(string.find(context, '</file>') ~= nil)
        assert.is_true(string.find(context, '<project_files>') ~= nil)
        assert.is_true(string.find(context, '</project_files>') ~= nil)

        -- Check file content is included
        assert.is_true(string.find(context, 'Main application entry point') ~= nil)
        assert.is_true(string.find(context, 'Configuration module') ~= nil)
        assert.is_true(string.find(context, 'Test Project') ~= nil)
      end)

      it('should include correct file metadata in XML', function()
        config.setup({
          output_format = {
            default_format = 'xml',
          },
        })

        local nodes = { file_node.new({ path = test_files.main_lua }) }
        local template_config = config.get_template_config()
        local context = template_engine.generate_context(nodes, test_dir, template_config)

        -- Check file name and path attributes
        assert.is_true(string.find(context, 'name="main.lua"') ~= nil)
        assert.is_true(string.find(context, 'path="main.lua"') ~= nil)
      end)
    end)

    describe('Markdown format', function()
      it('should generate correct Markdown structure', function()
        config.setup({
          output_format = {
            default_format = 'markdown',
          },
        })

        local nodes = create_test_file_nodes()
        local template_config = config.get_template_config()
        local context = template_engine.generate_context(nodes, test_dir, template_config)

        -- Check Markdown structure
        assert.is_true(string.find(context, '# Project Context') ~= nil)
        assert.is_true(string.find(context, '## Selected Files') ~= nil)
        assert.is_true(string.find(context, '## main') ~= nil)
        assert.is_true(string.find(context, '**Path:**') ~= nil)
        assert.is_true(string.find(context, '```lua') ~= nil)
        assert.is_true(string.find(context, '```js') ~= nil)
        assert.is_true(string.find(context, '---') ~= nil) -- separator

        -- Check file content is included
        assert.is_true(string.find(context, 'Main application entry point') ~= nil)
        assert.is_true(string.find(context, 'Configuration module') ~= nil)
      end)

      it('should use correct file extensions in code blocks', function()
        config.setup({
          output_format = {
            default_format = 'markdown',
          },
        })

        local nodes = {
          file_node.new({ path = test_files.main_lua }),
          file_node.new({ path = test_files.config_js }),
        }
        local template_config = config.get_template_config()
        local context = template_engine.generate_context(nodes, test_dir, template_config)

        -- Check language tags
        assert.is_true(string.find(context, '```lua') ~= nil)
        assert.is_true(string.find(context, '```js') ~= nil)
      end)
    end)

    describe('Minimal format', function()
      it('should generate correct minimal structure', function()
        config.setup({
          output_format = {
            default_format = 'minimal',
          },
        })

        local nodes = create_test_file_nodes()
        local template_config = config.get_template_config()
        local context = template_engine.generate_context(nodes, test_dir, template_config)

        -- Check minimal structure
        assert.is_true(string.find(context, '// File: ') ~= nil)
        assert.is_true(string.find(context, '// File: main.lua') ~= nil)
        assert.is_true(string.find(context, '// File: src/config.js') ~= nil)

        -- Should not contain XML or Markdown formatting
        assert.is_false(string.find(context, '<file') ~= nil)
        assert.is_false(string.find(context, '##') ~= nil)
        assert.is_false(string.find(context, '**Path:**') ~= nil)

        -- Check file content is included
        assert.is_true(string.find(context, 'Main application entry point') ~= nil)
        assert.is_true(string.find(context, 'Configuration module') ~= nil)
      end)
    end)

    describe('placeholder substitution', function()
      it('should replace all file placeholders correctly', function()
        local custom_template = {
          block_template = 'NAME:{fileName} EXT:{fileExtension} PATH:{rawFilePath} FULL:{fullPath} CONTENT:{fileContent}',
          separator = '\n---\n',
          wrapper_template = 'COUNT:{fileCount} TIME:{timestamp} ROOT:{workspaceRoot}\n{fileBlocks}',
        }

        local nodes = { file_node.new({ path = test_files.main_lua }) }
        local context = template_engine.generate_context(nodes, test_dir, custom_template)

        -- Check file placeholders
        assert.is_true(string.find(context, 'NAME:main') ~= nil)
        assert.is_true(string.find(context, 'EXT:lua') ~= nil)
        assert.is_true(string.find(context, 'PATH:main.lua') ~= nil)
        assert.is_true(string.find(context, 'FULL:' .. test_files.main_lua) ~= nil)
        assert.is_true(string.find(context, 'CONTENT:') ~= nil)

        -- Check wrapper placeholders
        assert.is_true(string.find(context, 'COUNT:1') ~= nil)
        assert.is_true(string.find(context, 'TIME:') ~= nil)
        assert.is_true(string.find(context, 'ROOT:' .. test_dir) ~= nil)
      end)

      it('should handle files without extensions', function()
        local no_ext_file = test_dir .. '/Makefile'
        vim.fn.writefile({ 'all:', '\techo "Building..."' }, no_ext_file)

        local custom_template = {
          block_template = 'FILE:{fileNameWithExtension} EXT:{fileExtension}',
          separator = '\n',
          wrapper_template = '{fileBlocks}',
        }

        local nodes = { file_node.new({ path = no_ext_file }) }
        local context = template_engine.generate_context(nodes, test_dir, custom_template)

        -- Should default to 'txt' for missing extension
        assert.is_true(string.find(context, 'FILE:Makefile') ~= nil)
        assert.is_true(string.find(context, 'EXT:txt') ~= nil)
      end)

      it('should handle nested file paths correctly', function()
        local custom_template = {
          block_template = 'PATH:{rawFilePath}',
          separator = '\n',
          wrapper_template = '{fileBlocks}',
        }

        local nodes = { file_node.new({ path = test_files.config_js }) }
        local context = template_engine.generate_context(nodes, test_dir, custom_template)

        -- Should show relative path from workspace root
        assert.is_true(string.find(context, 'PATH:src/config.js') ~= nil)
      end)

      it('should handle missing workspace root gracefully', function()
        local custom_template = {
          block_template = 'PATH:{rawFilePath}',
          separator = '\n',
          wrapper_template = 'ROOT:{workspaceRoot}\n{fileBlocks}',
        }

        local nodes = { file_node.new({ path = test_files.main_lua }) }
        local context = template_engine.generate_context(nodes, nil, custom_template)

        -- Should show full path when no workspace root
        assert.is_true(string.find(context, 'PATH:' .. test_files.main_lua) ~= nil)
        assert.is_true(string.find(context, 'ROOT:Unknown') ~= nil)
      end)
    end)

    describe('file count and metadata', function()
      it('should include correct file count', function()
        local custom_template = {
          block_template = '{fileContent}',
          separator = '\n',
          wrapper_template = 'Files: {fileCount}\n{fileBlocks}',
        }

        local nodes = create_test_file_nodes()
        local context = template_engine.generate_context(nodes, test_dir, custom_template)

        assert.is_true(string.find(context, 'Files: 3') ~= nil)
      end)

      it('should include timestamp in output', function()
        local custom_template = {
          block_template = '{fileContent}',
          separator = '\n',
          wrapper_template = 'Generated at: {timestamp}\n{fileBlocks}',
        }

        local nodes = { file_node.new({ path = test_files.main_lua }) }
        local context = template_engine.generate_context(nodes, test_dir, custom_template)

        assert.is_true(string.find(context, 'Generated at: %d%d%d%d%-%d%d%-%d%d') ~= nil)
      end)
    end)

    describe('error handling', function()
      it('should handle missing files gracefully', function()
        local non_existent_file = test_dir .. '/missing.txt'
        local nodes = { file_node.new({ path = non_existent_file }) }
        local template_config = config.get_template_config()

        local context = template_engine.generate_context(nodes, test_dir, template_config)

        -- Should generate context without the missing file
        assert.is_string(context)
        assert.is_false(string.find(context, 'missing.txt') ~= nil)
      end)

      it('should validate required parameters', function()
        assert.has_error(function()
          template_engine.generate_context(nil, test_dir, {})
        end)

        assert.has_error(function()
          template_engine.generate_context({}, test_dir, nil)
        end)
      end)
    end)

    describe('separator handling', function()
      it('should use configured separator between files', function()
        local custom_template = {
          block_template = 'FILE:{fileName}',
          separator = '\n***SEPARATOR***\n',
          wrapper_template = '{fileBlocks}',
        }

        local nodes = {
          file_node.new({ path = test_files.main_lua }),
          file_node.new({ path = test_files.readme_md }),
        }
        local context = template_engine.generate_context(nodes, test_dir, custom_template)

        assert.is_true(string.find(context, '***SEPARATOR***') ~= nil)
      end)

      it('should not add separator for single file', function()
        local custom_template = {
          block_template = 'FILE:{fileName}',
          separator = '\n***SEPARATOR***\n',
          wrapper_template = '{fileBlocks}',
        }

        local nodes = { file_node.new({ path = test_files.main_lua }) }
        local context = template_engine.generate_context(nodes, test_dir, custom_template)

        assert.is_false(string.find(context, '***SEPARATOR***') ~= nil)
      end)
    end)
  end)

  describe('format switching integration', function()
    it('should use XML format when set as current', function()
      config.setup({
        output_format = {
          default_format = 'minimal',
        },
      })

      -- Switch to XML format
      config.set_current_format('xml')

      local nodes = { file_node.new({ path = test_files.main_lua }) }
      local template_config = config.get_template_config()
      local context = template_engine.generate_context(nodes, test_dir, template_config)

      -- Should use XML format despite minimal being default
      assert.is_true(string.find(context, '<file name="') ~= nil)
      assert.is_true(string.find(context, '</file>') ~= nil)
      assert.equals('xml', config.get_current_format())
    end)

    it('should use Markdown format when set as current', function()
      config.setup({
        output_format = {
          default_format = 'xml',
        },
      })

      -- Switch to Markdown format
      config.set_current_format('markdown')

      local nodes = { file_node.new({ path = test_files.main_lua }) }
      local template_config = config.get_template_config()
      local context = template_engine.generate_context(nodes, test_dir, template_config)

      -- Should use Markdown format despite XML being default
      assert.is_true(string.find(context, '# Project Context') ~= nil)
      assert.is_true(string.find(context, '## main') ~= nil)
      assert.equals('markdown', config.get_current_format())
    end)

    it('should use Minimal format when set as current', function()
      config.setup({
        output_format = {
          default_format = 'xml',
        },
      })

      -- Switch to Minimal format
      config.set_current_format('minimal')

      local nodes = { file_node.new({ path = test_files.main_lua }) }
      local template_config = config.get_template_config()
      local context = template_engine.generate_context(nodes, test_dir, template_config)

      -- Should use Minimal format despite XML being default
      assert.is_true(string.find(context, '// File: ') ~= nil)
      assert.is_false(string.find(context, '<file') ~= nil)
      assert.equals('minimal', config.get_current_format())
    end)

    it('should fall back to default format when no current format set', function()
      config.setup({
        output_format = {
          default_format = 'markdown',
        },
      })

      local nodes = { file_node.new({ path = test_files.main_lua }) }
      local template_config = config.get_template_config()
      local context = template_engine.generate_context(nodes, test_dir, template_config)

      -- Should use default Markdown format
      assert.is_true(string.find(context, '# Project Context') ~= nil)
      assert.equals('markdown', config.get_current_format())
    end)

    it('should error for invalid format names', function()
      config.setup()

      assert.has_error(function()
        config.set_current_format('invalid_format')
      end)

      assert.has_error(function()
        config.set_current_format('HTML')
      end)
    end)

    it('should list available formats correctly', function()
      config.setup()

      local formats = config.get_available_formats()
      assert.is_table(formats)
      assert.is_true(vim.tbl_contains(formats, 'xml'))
      assert.is_true(vim.tbl_contains(formats, 'markdown'))
      assert.is_true(vim.tbl_contains(formats, 'minimal'))
    end)
  end)

  describe('template configuration', function()
    it('should use custom block template', function()
      config.setup({
        output_format = {
          default_format = 'xml',
          presets = {
            xml = {
              block_template = 'CUSTOM_BLOCK:{fileName}|{fileContent}',
              separator = '\n',
              wrapper_template = '{fileBlocks}',
            },
          },
        },
      })

      local nodes = { file_node.new({ path = test_files.main_lua }) }
      local template_config = config.get_template_config()
      local context = template_engine.generate_context(nodes, test_dir, template_config)

      assert.is_true(string.find(context, 'CUSTOM_BLOCK:main|') ~= nil)
      assert.is_true(string.find(context, 'Main application entry point') ~= nil)
    end)

    it('should use custom separator', function()
      config.setup({
        output_format = {
          default_format = 'xml',
          presets = {
            xml = {
              block_template = 'FILE:{fileName}',
              separator = '\n<<SEPARATOR>>\n',
              wrapper_template = '{fileBlocks}',
            },
          },
        },
      })

      local nodes = {
        file_node.new({ path = test_files.main_lua }),
        file_node.new({ path = test_files.readme_md }),
      }
      local template_config = config.get_template_config()
      local context = template_engine.generate_context(nodes, test_dir, template_config)

      assert.is_true(string.find(context, '<<SEPARATOR>>') ~= nil)
    end)

    it('should use custom wrapper template', function()
      config.setup({
        output_format = {
          default_format = 'xml',
          presets = {
            xml = {
              block_template = '{fileName}',
              separator = '\n',
              wrapper_template = 'HEADER:Custom wrapper\nCOUNT:{fileCount}\nCONTENT:\n{fileBlocks}\nFOOTER:End',
            },
          },
        },
      })

      local nodes = { file_node.new({ path = test_files.main_lua }) }
      local template_config = config.get_template_config()
      local context = template_engine.generate_context(nodes, test_dir, template_config)

      assert.is_true(string.find(context, 'HEADER:Custom wrapper') ~= nil)
      assert.is_true(string.find(context, 'COUNT:1') ~= nil)
      assert.is_true(string.find(context, 'FOOTER:End') ~= nil)
    end)

    it('should support adding custom template formats', function()
      -- First setup with xml as default, then add custom preset and switch to it
      config.setup({
        output_format = {
          default_format = 'xml',
          presets = {
            custom = {
              block_template = 'BEGIN_{fileName}_\n{fileContent}\nEND_{fileName}_',
              separator = '\n---\n',
              wrapper_template = 'Total files: {fileCount}\n\n{fileBlocks}',
            },
          },
        },
      })

      -- Switch to custom format
      config.set_current_format('custom')

      local nodes = { file_node.new({ path = test_files.main_lua }) }
      local template_config = config.get_template_config()
      local context = template_engine.generate_context(nodes, test_dir, template_config)

      assert.is_true(string.find(context, 'BEGIN_main_') ~= nil)
      assert.is_true(string.find(context, 'END_main_') ~= nil)
      assert.is_true(string.find(context, 'Total files: 1') ~= nil)
      assert.equals('custom', config.get_current_format())
    end)

    it('should validate template configuration on setup', function()
      assert.has_error(function()
        config.setup({
          output_format = {
            default_format = 'nonexistent',
          },
        })
      end)
    end)

    it('should merge custom presets with default presets', function()
      config.setup({
        output_format = {
          default_format = 'xml',
          presets = {
            -- Override XML preset
            xml = {
              block_template = 'MODIFIED_XML:{fileName}',
              separator = '\n',
              wrapper_template = '{fileBlocks}',
            },
            -- Add new custom preset
            json = {
              block_template = '{"file": "{fileName}", "content": "{fileContent}"}',
              separator = ',\n',
              wrapper_template = '[{fileBlocks}]',
            },
          },
        },
      })

      local formats = config.get_available_formats()

      -- Should have default formats plus custom
      assert.is_true(vim.tbl_contains(formats, 'xml'))
      assert.is_true(vim.tbl_contains(formats, 'markdown'))
      assert.is_true(vim.tbl_contains(formats, 'minimal'))
      assert.is_true(vim.tbl_contains(formats, 'json'))

      -- XML should be modified
      local xml_config = config.get_template_config('xml')
      assert.is_true(string.find(xml_config.block_template, 'MODIFIED_XML') ~= nil)

      -- New format should be available
      config.set_current_format('json')
      local json_config = config.get_template_config('json')
      assert.is_true(string.find(json_config.block_template, '"file":') ~= nil)
    end)
  end)
end)
