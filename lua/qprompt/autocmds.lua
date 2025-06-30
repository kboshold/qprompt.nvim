local M = {}

local config = require("qprompt.config")
local utils = require("qprompt.utils")
local picker = require("qprompt.picker")
local windows = require("qprompt.windows")

local context_windows_created = false

function M.setup()
    -- Create an autocommand group for qprompt
    local augroup = vim.api.nvim_create_augroup("QPrompt", { clear = true })

    -- Add an autocommand for BufEnter and BufWinEnter events to detect prompt buffers
    vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
        group = augroup,
        callback = function(args)
            local bufname = vim.api.nvim_buf_get_name(args.buf)

            -- Check if the buffer name contains q_prompt_<uuid>.md pattern
            if bufname:match("q_prompt_[%w-]+%.md") then
                vim.notify("Entered prompt buffer: " .. bufname, vim.log.levels.INFO)

                -- Set up context windows if they haven't been created yet
                if not context_windows_created and config.options.context_windows.enabled then
                    local main_win = vim.api.nvim_get_current_win()
                    windows.setup_context_windows(main_win)
                    context_windows_created = true
                end

                -- Start in insert mode
                vim.schedule(function()
                    vim.cmd("startinsert")
                end)

                -- Set up InsertCharPre autocmd to detect triggers
                vim.api.nvim_create_autocmd("InsertCharPre", {
                    group = augroup,
                    buffer = args.buf,
                    callback = function()
                        local line = vim.api.nvim_get_current_line()
                        local col = vim.api.nvim_win_get_cursor(0)[2]

                        -- Check for file trigger
                        if utils.check_trigger(line, col, config.options.triggers.file) then
                            vim.v.char = ""
                            vim.schedule(function()
                                picker.trigger_file_picker("file", config.options.triggers.file, false)
                            end)
                        -- Check for directory trigger
                        elseif utils.check_trigger(line, col, config.options.triggers.directory) then
                            vim.v.char = ""
                            vim.schedule(function()
                                picker.trigger_file_picker("directory", config.options.triggers.directory, false)
                            end)
                        -- Check for file from home trigger
                        elseif utils.check_trigger(line, col, config.options.triggers.file_from_home) then
                            vim.v.char = ""
                            vim.schedule(function()
                                picker.trigger_file_picker("file", config.options.triggers.file_from_home, true)
                            end)
                        -- Check for directory from home trigger
                        elseif utils.check_trigger(line, col, config.options.triggers.directory_from_home) then
                            vim.v.char = ""
                            vim.schedule(function()
                                picker.trigger_file_picker(
                                    "directory",
                                    config.options.triggers.directory_from_home,
                                    true
                                )
                            end)
                        end
                    end,
                })
            end
        end,
    })
end

return M
