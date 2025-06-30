local M = {}

local config = require("qprompt.config")
local picker = require("qprompt.picker")
local autocmds = require("qprompt.autocmds")

function M.setup(user_config)
	config.setup(user_config)
	autocmds.setup()
end

M.trigger_file_picker = picker.trigger_file_picker

return M
