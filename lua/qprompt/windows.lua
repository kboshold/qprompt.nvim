local M = {}

local config = require('qprompt.config')

local function get_or_create_buffer(title)
  -- Check if a buffer with this name already exists
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf):match(title .. "$") then
      return buf
    end
  end

  -- If not, create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, title)
  return buf
end

local function create_window(title, position, size)
  local win_cmd = position == "right" and "vnew" or "new"
  vim.cmd(win_cmd)
  local win = vim.api.nvim_get_current_win()
  local buf = get_or_create_buffer(title)

  -- Set window options
  vim.api.nvim_win_set_option(win, 'number', false)
  vim.api.nvim_win_set_option(win, 'relativenumber', false)
  vim.api.nvim_win_set_option(win, 'wrap', true)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')

  -- Set the buffer for this window
  vim.api.nvim_win_set_buf(win, buf)

  -- Set window size
  if position == "right" then
    vim.api.nvim_win_set_width(win, size)
  else
    vim.api.nvim_win_set_height(win, size)
  end

  -- Add a title to the window
  if vim.fn.has('nvim-0.9') == 1 then
    -- For Neovim 0.9+, use winbar
    vim.api.nvim_win_set_option(win, 'winbar', '%#Title#' .. title .. '%*')
  else
    -- For older versions, add a title line at the top of the buffer
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, {"=== " .. title .. " ==="})
    vim.api.nvim_buf_add_highlight(buf, -1, "Title", 0, 0, -1)
  end

  return win, buf
end

function M.setup_context_windows(main_win)
  if not config.options.context_windows.enabled then
    return
  end

  local position = config.options.context_windows.position
  local size = position == "right" and config.options.context_windows.width or config.options.context_windows.height

  -- Store the current window
  local current_win = vim.api.nvim_get_current_win()

  -- Create the first context window
  local sticky_win, sticky_buf = create_window("Sticky Context", position, size)
  
  -- For "right" position, windows should be stacked vertically (one under another)
  -- For "bottom" position, windows should be arranged horizontally (side by side)
  if position == "right" then
    -- Create the second window below the first one
    vim.cmd("split")
    local project_win = vim.api.nvim_get_current_win()
    local project_buf = get_or_create_buffer("Project Context")
    vim.api.nvim_win_set_buf(project_win, project_buf)
    
    -- Add title to Project Context window
    if vim.fn.has('nvim-0.9') == 1 then
      vim.api.nvim_win_set_option(project_win, 'winbar', '%#Title#Project Context%*')
    else
      vim.api.nvim_buf_set_lines(project_buf, 0, 0, false, {"=== Project Context ==="})
      vim.api.nvim_buf_add_highlight(project_buf, -1, "Title", 0, 0, -1)
    end
    
    -- Create the third window below the second one
    vim.cmd("split")
    local global_win = vim.api.nvim_get_current_win()
    local global_buf = get_or_create_buffer("Global Context")
    vim.api.nvim_win_set_buf(global_win, global_buf)
    
    -- Add title to Global Context window
    if vim.fn.has('nvim-0.9') == 1 then
      vim.api.nvim_win_set_option(global_win, 'winbar', '%#Title#Global Context%*')
    else
      vim.api.nvim_buf_set_lines(global_buf, 0, 0, false, {"=== Global Context ==="})
      vim.api.nvim_buf_add_highlight(global_buf, -1, "Title", 0, 0, -1)
    end
  else -- position == "bottom"
    -- Create the second window to the right of the first one
    vim.cmd("vsplit")
    local project_win = vim.api.nvim_get_current_win()
    local project_buf = get_or_create_buffer("Project Context")
    vim.api.nvim_win_set_buf(project_win, project_buf)
    
    -- Add title to Project Context window
    if vim.fn.has('nvim-0.9') == 1 then
      vim.api.nvim_win_set_option(project_win, 'winbar', '%#Title#Project Context%*')
    else
      vim.api.nvim_buf_set_lines(project_buf, 0, 0, false, {"=== Project Context ==="})
      vim.api.nvim_buf_add_highlight(project_buf, -1, "Title", 0, 0, -1)
    end
    
    -- Create the third window to the right of the second one
    vim.cmd("vsplit")
    local global_win = vim.api.nvim_get_current_win()
    local global_buf = get_or_create_buffer("Global Context")
    vim.api.nvim_win_set_buf(global_win, global_buf)
    
    -- Add title to Global Context window
    if vim.fn.has('nvim-0.9') == 1 then
      vim.api.nvim_win_set_option(global_win, 'winbar', '%#Title#Global Context%*')
    else
      vim.api.nvim_buf_set_lines(global_buf, 0, 0, false, {"=== Global Context ==="})
      vim.api.nvim_buf_add_highlight(global_buf, -1, "Title", 0, 0, -1)
    end
  end

  -- Return to the main window
  vim.api.nvim_set_current_win(main_win)

  -- Equalize window sizes
  vim.cmd("wincmd =")

  -- Return to the original window
  vim.api.nvim_set_current_win(current_win)
end

return M
