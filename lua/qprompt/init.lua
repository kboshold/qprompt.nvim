local M = {}

-- Default configuration
local default_config = {
	triggers = {
		file = "@ff",
		directory = "@fd",
	},
}

-- User configuration (will be set in setup)
local config = {}

-- Global variables to store state
local insert_pos = nil
local insert_bufnr = nil

function M.setup(user_config)
	-- Merge user config with default config
	config = vim.tbl_deep_extend("force", default_config, user_config or {})

	vim.notify(
		"QPrompt initialized with triggers: "
			.. config.triggers.file
			.. " (files), "
			.. config.triggers.directory
			.. " (directories)",
		vim.log.levels.INFO
	)

	-- Create an autocommand group for qprompt
	local augroup = vim.api.nvim_create_augroup("QPrompt", { clear = true })

	-- Add an autocommand for BuffEnter event to detect prompt buffers
	vim.api.nvim_create_autocmd("BufEnter", {
		group = augroup,
		callback = function(args)
			local bufname = vim.api.nvim_buf_get_name(args.buf)

			-- Check if the buffer name contains q_prompt_<uuid>.md pattern
			if bufname:match("q_prompt_[%w-]+%.md") then
				-- Set up InsertCharPre autocmd to detect triggers
				vim.api.nvim_create_autocmd("InsertCharPre", {
					group = augroup,
					buffer = args.buf,
					callback = function()
						local line = vim.api.nvim_get_current_line()
						local col = vim.api.nvim_win_get_cursor(0)[2]

						-- Check for file trigger
						if
							line:sub(col - #config.triggers.file + 2, col) == config.triggers.file:sub(1, -2)
							and vim.v.char == config.triggers.file:sub(-1)
						then
							vim.v.char = ""
							vim.schedule(function()
								M.trigger_file_picker("file", config.triggers.file)
							end)
						-- Check for directory trigger
						elseif
							line:sub(col - #config.triggers.directory + 2, col)
								== config.triggers.directory:sub(1, -2)
							and vim.v.char == config.triggers.directory:sub(-1)
						then
							vim.v.char = ""
							vim.schedule(function()
								M.trigger_file_picker("directory", config.triggers.directory)
							end)
						end
					end,
				})
			end
		end,
	})
end

-- Function to trigger the file picker
function M.trigger_file_picker(picker_type, trigger_text)
	-- Save the current position and buffer
	insert_bufnr = vim.api.nvim_get_current_buf()
	insert_pos = vim.api.nvim_win_get_cursor(0)

	-- Exit insert mode
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)

	-- Call the file picker after a short delay
	vim.defer_fn(function()
		M.pick_file(picker_type, trigger_text)
	end, 10)
end

-- Function to format a file path as markdown link with relative path
local function format_as_markdown_link(path, is_directory)
	-- Convert to relative path if possible
	local rel_path = vim.fn.fnamemodify(path, ":~:.")

	-- Extract the filename or directory name from the path
	local name = vim.fn.fnamemodify(path, ":t")

	-- Add trailing slash to directory paths for clarity
	if is_directory and not rel_path:match("/$") then
		rel_path = rel_path .. "/"
	end

	-- Create markdown link format: [name](relative_path)
	return "[" .. name .. "](" .. rel_path .. ")"
end

-- Function to pick a file or directory
function M.pick_file(picker_type, trigger_text)
	-- Default to file if not specified
	picker_type = picker_type or "file"
	local is_directory = (picker_type == "directory")

	-- Check if telescope is available
	local has_telescope, telescope = pcall(require, "telescope.builtin")

	if has_telescope then
		if is_directory then
			-- Use find_files with only directories
			telescope.find_files({
				find_command = { "find", ".", "-type", "d", "-not", "-path", "*/\\.git/*" },
				attach_mappings = function(_, map)
					map("i", "<CR>", function(prompt_bufnr)
						local selection = require("telescope.actions.state").get_selected_entry(prompt_bufnr)
						require("telescope.actions").close(prompt_bufnr)

						if selection and selection.path then
							-- Format the path as markdown link before inserting
							local markdown_link = format_as_markdown_link(selection.path, true)
							M.insert_at_saved_position(markdown_link, trigger_text)
						end

						return true
					end)
					return true
				end,
			})
		else
			-- Use regular find_files for files
			telescope.find_files({
				attach_mappings = function(_, map)
					map("i", "<CR>", function(prompt_bufnr)
						local selection = require("telescope.actions.state").get_selected_entry(prompt_bufnr)
						require("telescope.actions").close(prompt_bufnr)

						if selection and selection.path then
							-- Format the path as markdown link before inserting
							local markdown_link = format_as_markdown_link(selection.path, false)
							M.insert_at_saved_position(markdown_link, trigger_text)
						end

						return true
					end)
					return true
				end,
			})
		end
	else
		-- Fallback to vim.ui.select
		local cwd = vim.fn.getcwd()
		local find_type = is_directory and "d" or "f"
		local files = vim.fn.systemlist(
			"find " .. vim.fn.shellescape(cwd) .. " -type " .. find_type .. " -not -path '*/\\.git/*' | sort"
		)

		vim.ui.select(files, {
			prompt = "Select a " .. (is_directory and "directory" or "file") .. " to insert:",
			format_item = function(item)
				return vim.fn.fnamemodify(item, ":~:.")
			end,
		}, function(selected)
			if selected then
				-- Format the path as markdown link before inserting
				local markdown_link = format_as_markdown_link(selected, is_directory)
				M.insert_at_saved_position(markdown_link, trigger_text)
			end
		end)
	end
end

-- Function to insert text at the saved position
function M.insert_at_saved_position(text, trigger_text)
	-- Ensure we have a valid buffer and position
	if not insert_bufnr or not insert_pos or not vim.api.nvim_buf_is_valid(insert_bufnr) then
		return
	end

	-- Get the current line
	local line = vim.api.nvim_buf_get_lines(insert_bufnr, insert_pos[1] - 1, insert_pos[1], false)[1]
	if not line then
		return
	end

	-- Replace the trigger text with the markdown link
	local col = insert_pos[2]
	local trigger_len = #trigger_text
	local new_line = line:sub(1, col - trigger_len + 1) .. text .. line:sub(col + 1)
	vim.api.nvim_buf_set_lines(insert_bufnr, insert_pos[1] - 1, insert_pos[1], false, { new_line })

	-- Calculate the correct cursor position (end of inserted text)
	local new_col = col - trigger_len + 1 + #text

	-- Position the cursor and return to insert mode
	vim.api.nvim_win_set_cursor(0, { insert_pos[1], new_col })
	vim.cmd("startinsert!")
end

return M
