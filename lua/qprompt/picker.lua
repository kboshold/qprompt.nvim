local M = {}

local config = require("qprompt.config")
local utils = require("qprompt.utils")

-- Global variables to store state
local insert_pos = nil
local insert_bufnr = nil

function M.trigger_file_picker(picker_type, trigger_text, from_home)
	-- Save the current position and buffer
	insert_bufnr = vim.api.nvim_get_current_buf()
	insert_pos = vim.api.nvim_win_get_cursor(0)

	-- Exit insert mode
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)

	-- Call the file picker after a short delay
	vim.defer_fn(function()
		M.pick_file(picker_type, trigger_text, from_home)
	end, 10)
end

function M.pick_file(picker_type, trigger_text, from_home)
	-- Default to file if not specified
	picker_type = picker_type or "file"
	local is_directory = (picker_type == "directory")
	from_home = from_home or false

	-- Determine the starting directory
	local home_dir = vim.fn.expand("~")
	local start_dir = from_home and home_dir or "."

	-- Check if telescope is available
	local has_telescope, telescope = pcall(require, "telescope.builtin")

	if has_telescope then
		M.pick_file_telescope(start_dir, is_directory, from_home, trigger_text)
	else
		M.pick_file_fallback(start_dir, is_directory, from_home, trigger_text)
	end
end

function M.pick_file_telescope(start_dir, is_directory, from_home, trigger_text)
	local telescope = require("telescope.builtin")
	telescope.find_files({
		cwd = start_dir,
		hidden = config.options.show_hidden,
		no_ignore = not config.options.respect_gitignore,
		find_command = {
			"find",
			".",
			"-type",
			is_directory and "d" or "f",
			config.options.show_hidden and "" or "-not",
			config.options.show_hidden and "" or "-path",
			config.options.show_hidden and "" or "*/.*",
			"-not",
			"-path",
			"*/\\.git/*",
		},
		attach_mappings = function(_, map)
			map("i", "<CR>", function(prompt_bufnr)
				local selection = require("telescope.actions.state").get_selected_entry(prompt_bufnr)
				require("telescope.actions").close(prompt_bufnr)

				if selection and selection.path then
					-- Get the full path
					local full_path = start_dir .. "/" .. selection.path
					-- Check if the file should be ignored
					if not utils.should_ignore(full_path) then
						-- Format the path as markdown link before inserting
						local markdown_link = utils.format_as_markdown_link(full_path, is_directory, from_home)
						M.insert_at_saved_position(markdown_link, trigger_text)
					else
						vim.notify("Selected file is ignored by configuration", vim.log.levels.WARN)
					end
				end

				return true
			end)
			return true
		end,
	})
end

function M.pick_file_fallback(start_dir, is_directory, from_home, trigger_text)
	-- Fallback to vim.ui.select with fd command if available (respects .gitignore by default)
	local has_fd = vim.fn.executable("fd") == 1
	local cmd

	if has_fd then
		-- fd respects .gitignore by default
		local fd_type_flag = is_directory and "-t d" or "-t f"
		local fd_ignore_flag = config.options.respect_gitignore and "" or "--no-ignore"
		local fd_hidden_flag = config.options.show_hidden and "--hidden" or ""
		cmd = string.format(
			"fd %s %s %s . %s",
			fd_type_flag,
			fd_ignore_flag,
			fd_hidden_flag,
			vim.fn.shellescape(start_dir)
		)
	else
		-- Fallback to find with grep to filter out gitignored files
		local find_type = is_directory and "d" or "f"
		local hidden_flag = config.options.show_hidden and "" or "-not -path '*/.*'"
		cmd = string.format(
			"find %s -type %s %s -not -path '*/\\.git/*'",
			vim.fn.shellescape(start_dir),
			find_type,
			hidden_flag
		)

		-- If we should respect gitignore, pipe through git check-ignore
		if config.options.respect_gitignore then
			cmd = cmd
				.. " | grep -v -f <(git -C "
				.. vim.fn.shellescape(start_dir)
				.. " config --get core.excludesfile 2>/dev/null)"
		end
	end

	local files = vim.fn.systemlist(cmd)

	-- Filter out ignored files
	local filtered_files = {}
	for _, file in ipairs(files) do
		if not utils.should_ignore(file) then
			table.insert(filtered_files, file)
		end
	end

	vim.ui.select(filtered_files, {
		prompt = "Select a " .. (is_directory and "directory" or "file") .. " to insert:",
		format_item = function(item)
			if from_home then
				return vim.fn.fnamemodify(item, ":~")
			else
				return vim.fn.fnamemodify(item, ":~:.")
			end
		end,
	}, function(selected)
		if selected then
			-- Format the path as markdown link before inserting
			local markdown_link = utils.format_as_markdown_link(selected, is_directory, from_home)
			M.insert_at_saved_position(markdown_link, trigger_text)
		end
	end)
end

function M.insert_at_saved_position(text, trigger_text)
	-- Ensure we have a valid buffer and position
	if not insert_bufnr or not insert_pos or not vim.api.nvim_buf_is_valid(insert_bufnr) then
		vim.notify("Cannot insert: invalid buffer or position", vim.log.levels.ERROR)
		return
	end

	-- Get the current line
	local line = vim.api.nvim_buf_get_lines(insert_bufnr, insert_pos[1] - 1, insert_pos[1], false)[1]
	if not line then
		vim.notify("Cannot insert: invalid line", vim.log.levels.ERROR)
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

	-- Notify for debugging
	vim.notify("Inserted: " .. text .. " (replacing " .. trigger_text .. ")", vim.log.levels.INFO)
end

return M
