local M = {}

local default_config = {
  triggers = {
    file = "@ff",
    directory = "@fd",
    file_from_home = "@fF",
    directory_from_home = "@fD"
  },
  respect_gitignore = true,
  show_hidden = false,
  ignore_patterns = {
    "%.git",
    "%.pyc$",
    "node_modules",
    -- Add more default patterns here
  },
  context_windows = {
    enabled = true,
    position = "right", -- or "bottom"
    width = 30, -- used when position is "right"
    height = 10, -- used when position is "bottom"
  }
}

M.options = {}

function M.setup(user_config)
  M.options = vim.tbl_deep_extend("force", default_config, user_config or {})
  
  vim.notify("QPrompt initialized with triggers: " .. 
    M.options.triggers.file .. " (files), " .. 
    M.options.triggers.directory .. " (directories), " ..
    M.options.triggers.file_from_home .. " (files from home), " ..
    M.options.triggers.directory_from_home .. " (directories from home)", 
    vim.log.levels.INFO)
end

return M
