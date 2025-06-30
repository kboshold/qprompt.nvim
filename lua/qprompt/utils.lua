local M = {}

local config = require("qprompt.config")

function M.check_trigger(line, col, trigger)
	if #trigger == 0 then
		return false
	end

	-- Check if we're typing the last character of the trigger
	if vim.v.char ~= trigger:sub(-1) then
		return false
	end

	-- Check if the preceding characters match the rest of the trigger
	local prefix_len = #trigger - 1
	if col < prefix_len then
		return false
	end

	local prefix = line:sub(col - prefix_len + 1, col)
	return prefix == trigger:sub(1, -2)
end

function M.format_as_markdown_link(path, is_directory, from_home)
	local rel_path

	if from_home then
		-- Use path relative to home for "from home" options
		rel_path = vim.fn.fnamemodify(path, ":~")
	else
		-- Convert to relative path if possible for regular options
		rel_path = vim.fn.fnamemodify(path, ":~:.")
	end

	-- Extract the filename or directory name from the path
	local name = vim.fn.fnamemodify(path, ":t")

	-- Add trailing slash to directory paths for clarity
	if is_directory and not rel_path:match("/$") then
		rel_path = rel_path .. "/"
	end

	-- Create markdown link format: [name](relative_path)
	return "[" .. name .. "](" .. rel_path .. ")"
end

function M.should_ignore(file)
	for _, pattern in ipairs(config.options.ignore_patterns) do
		if file:match(pattern) then
			return true
		end
	end
	return false
end

return M
