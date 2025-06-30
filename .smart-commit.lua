-- User-level Smart Commit configuration
-- This file is loaded from the user's home directory

return {
	defaults = {
		auto_run = true,
		sign_column = true,
		status_window = {
			enabled = true,
			position = "bottom",
			refresh_rate = 100,
		},
	},
	tasks = {
		["copilot:message"] = true,
		-- ["copilot:analyze"] = true,

		["stylua:check"] = {
			icon = "",
			label = "Stylua",
			command = "stylua --check .",
		},
	},
}
