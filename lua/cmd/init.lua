---@brief [[
---*cmd.nvim* Execute CLI commands in Neovim
---*Cmd*
---
---Features:
--- - Execute CLI commands with output in buffers or terminal
--- - Shell completion support for commands
--- - Command history tracking
--- - Async execution with progress notifications
--- - Configurable spinner adapters for different notification plugins
--- - Environment variable support per executable
--- - Timeout handling and command cancellation
---
---# Setup ~
---
---This module needs to be set up with `require('cmd').setup({})` (replace
---`{}` with your `config` table).
---
---# Highlighting ~
---
---Plugin defines several highlight groups:
--- - `CmdHistoryNormal` - for history floating window (linked to `NormalFloat`)
--- - `CmdHistoryBorder` - for history floating window border (linked to `FloatBorder`)
--- - `CmdHistoryTitle` - for history floating window title (linked to `FloatTitle`)
--- - `CmdHistoryIdentifier` - for command ID in history (linked to `Identifier`)
--- - `CmdHistoryTime` - for timestamp in history (linked to `Comment`)
--- - `CmdSuccess` - for successful commands (linked to `MoreMsg`)
--- - `CmdFailed` - for failed commands (linked to `ErrorMsg`)
--- - `CmdCancelled` - for cancelled commands (linked to `WarningMsg`)
---
---To change any highlight group, modify it directly with |:highlight|.
---
---@brief ]]

---@toc cmd.contents

---@mod cmd.setup Setup
---@divider =

---@tag Cmd.setup()
---@tag Cmd-setup

---@brief [[
---# Module setup ~
---
--->lua
---   require('cmd').setup() -- use default config
---   -- OR
---   require('cmd').setup({}) -- replace {} with your config table
---<
---@brief ]]

---@mod cmd.config Configuration
---@divider =

---@tag Cmd.config

---@brief [[
---# Module config ~
---
---Default values:
---{
---  force_terminal = {},
---  create_usercmd = {},
---  env = {},
---  timeout = 30000,
---  completion = {
---    enabled = false,
---    shell = vim.env.SHELL or "/bin/sh",
---  },
---  async_notifier = {
---    spinner_chars = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
---    adapter = nil,
---  },
---  history_formatter_fn = U.default_history_formatter,
---}
---
---## Force terminal execution ~
---
---Some commands should always run in terminal mode. Use `force_terminal`
---to specify patterns that trigger terminal execution:
--->lua
---   require('cmd').setup({
---     force_terminal = {
---       git = { 'push', 'pull', 'fetch' }, -- git push/pull/fetch always in terminal
---       npm = { 'run' },                   -- npm run always in terminal
---     }
---   })
---<
---
---## Auto-create user commands ~
---
---Automatically create user commands for executables if they don't exist:
--->lua
---   require('cmd').setup({
---     create_usercmd = {
---       git = 'Git',     -- Creates :Git command if it doesn't exist
---       npm = 'Npm',     -- Creates :Npm command if it doesn't exist
---       docker = 'Docker', -- Creates :Docker command if it doesn't exist
---     }
---   })
---<
---
---## Environment variables ~
---
---Set environment variables per executable:
--->lua
---   require('cmd').setup({
---     env = {
---       node = { 'NODE_ENV=development' },
---       python = { 'PYTHONPATH=/custom/path' },
---     }
---   })
---<
---
---## Completion configuration ~
---
---Configure shell completion behavior:
--->lua
---   require('cmd').setup({
---     completion = {
---       enabled = true,
---       shell = '/bin/fish', -- Use fish for completion
---       prompt_pattern_to_remove = '^%$ ', -- Remove '$ ' prompt
---     }
---   })
---<
---
---## Async notifications ~
---
---Configure progress notifications with different adapters:
--->lua
---   -- Using built-in snacks.nvim adapter
---   require('cmd').setup({
---     async_notifier = {
---       adapter = require('cmd').builtins.spinner_adapters.snacks,
---       spinner_chars = { '⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷' },
---     }
---   })
---
---   -- Using custom adapter
---   require('cmd').setup({
---     async_notifier = {
---       adapter = {
---         start = function(msg, data)
---           return vim.notify(msg, vim.log.levels.INFO)
---         end,
---         update = function(id, msg, data)
---           vim.notify(msg, vim.log.levels.INFO, { replace = id })
---         end,
---         finish = function(id, msg, level, data)
---           vim.notify(msg, vim.log.levels[level], { replace = id })
---         end,
---       }
---     }
---   })
---<
---@brief ]]

---@mod cmd.commands Commands
---@divider =

---@tag :Cmd
---@tag Cmd-:Cmd

---@brief [[
---# Execute a CLI command ~
---
---Run any CLI command with optional shell completion and async notifications.
---Use `!` to force terminal execution, `!!` to rerun last command in terminal.
---
--->vim
---   :Cmd git status           " Run in async without terminal
---   :Cmd! git log --oneline   " Force terminal execution
---<
---@brief ]]

---@tag :CmdRerun
---@tag Cmd-:CmdRerun

---@brief [[
---# Rerun a command from history ~
---
---Rerun the last command or a specific command by ID.
---Use `!` to force terminal execution.
---
--->vim
---   :CmdRerun      " Rerun last command
---   :CmdRerun 5    " Rerun command #5 from history
---   :CmdRerun! 3   " Rerun command #3 in terminal
---<
---@brief ]]

---@tag :CmdCancel
---@tag Cmd-:CmdCancel

---@brief [[
---# Cancel running commands ~
---
---Cancel currently running command(s).
---Use `!` to cancel all running commands.
---
--->vim
---   :CmdCancel     " Cancel last running command
---   :CmdCancel 2   " Cancel command #2
---   :CmdCancel!    " Cancel all running commands
---<
---@brief ]]

---@tag :CmdHistory
---@tag Cmd-:CmdHistory

---@brief [[
---# Show command history ~
---
---Display a formatted list of all executed commands with their status,
---timestamps, and execution type.
---
--->vim
---   :CmdHistory    " Show command history in buffer
---<
---@brief ]]

---@mod cmd.api API
---@divider =

local ok, uv = pcall(function()
  return vim.uv or vim.loop
end)
if not ok or uv == nil then
  error("Cmd.nvim: libuv not available")
end

local nvim = vim.version()
if nvim.major == 0 and (nvim.minor < 10 or (nvim.minor == 10 and nvim.patch < 0)) then
  error("Cmd.nvim requires Neovim 0.10+")
end

------------------------------------------------------------------
-- Modules & internal namespaces
------------------------------------------------------------------

---@tag Cmd
---@tag cmd-main

---Main module table
---@class Cmd
local Cmd = {}

---@private
---@class Cmd.Helpers
---Collection of internal helper functions for file operations, sanitization,
---environment handling, and temporary script management.
local H = {}

---@private
---@class Cmd.UI
---User interface components including spinner adapters, buffer management,
---terminal integration, and visual feedback systems.
local U = {
  ---@type table<string, Cmd.Config.AsyncNotifier.SpinnerAdapter>
  spinner_adapters = {},
}

---@private
---@class Cmd.Core
---Core functionality for command execution, process management,
---completion handling, and command lifecycle management.
local C = {}

------------------------------------------------------------------
-- Constants & Setup
------------------------------------------------------------------

---@class Cmd.CommandHistory
---Represents a single command entry in the execution history.
---@field id integer Unique command identifier
---@field cmd? string[] Command arguments array
---@field timestamp? number Unix timestamp when command was executed
---@field type? Cmd.CommandType Execution type
---@field status? Cmd.CommandStatus Current command status
---@field job? uv.uv_process_t|nil Process handle if command is running

---@alias Cmd.CommandType
---| '"normal"'      # Command executed in buffer mode
---| '"interactive"' # Command executed in terminal mode

---@alias Cmd.CommandStatus
---| '"success"'   # Command completed successfully (exit code 0)
---| '"failed"'    # Command failed (non-zero exit code)
---| '"cancelled"' # Command was cancelled by user
---| '"running"'   # Command is currently executing

---@class Cmd.Spinner
---Represents the state of a progress spinner for a running command.
---@field timer uv.uv_timer_t|nil Timer handle for spinner animation
---@field active boolean Whether spinner is currently active
---@field msg string Current spinner message text
---@field title string Spinner notification title
---@field cmd string Full command string being executed

---@class Cmd.State
---Internal state management for the plugin.
---@field cwd string Current working directory for command execution
---@field temp_script_cache table<string, string> Cache of temporary completion scripts
---@field spinner_state table<integer, Cmd.Spinner> Active spinner states by command ID
---@field command_history Cmd.CommandHistory[] Complete command execution history
local S = {
  cwd = "",
  temp_script_cache = {},
  spinner_state = {},
  command_history = {},
}

---@type table<Cmd.CommandStatus, string>
---Icon mappings for different command statuses in notifications
local icon_map = {
  success = " ",
  failed = " ",
  cancelled = " ",
}

---@type table<Cmd.CommandStatus, string>
---Log level mappings for different command statuses
local level_map = {
  success = "INFO",
  failed = "ERROR",
  cancelled = "WARN",
}

---@type table<Cmd.CommandStatus, string>
---Highlight group mappings for different command statuses
local hl_groups = {
  success = "CmdSuccess",
  failed = "CmdFailed",
  cancelled = "CmdCancelled",
}

------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------

---Safely delete a file with deferred execution to prevent blocking.
---
---@param path string Absolute path to file to delete
---@return nil
function H.safe_delete(path)
  vim.defer_fn(function()
    pcall(vim.fn.delete, path)
  end, 0)
end

---Ensure that the current working directory is properly set for command execution.
---
---Uses the directory of the current buffer if available and valid,
---otherwise falls back to Neovim's current working directory.
---
---@return nil
function H.ensure_cwd()
  local buf_dir = vim.fn.expand("%:p:h")

  if buf_dir and vim.fn.isdirectory(buf_dir) == 1 then
    S.cwd = buf_dir
  else
    S.cwd = vim.fn.getcwd()
  end
end

---@alias Cmd.LogLevel
---| '"INFO"'  # Informational message
---| '"WARN"'  # Warning message
---| '"ERROR"' # Error message

---Display a notification message with specified log level.
---
---@param msg string Message content to display
---@param lvl Cmd.LogLevel Log level for the notification
---@param opts? table Additional notification options (title, timeout, etc.)
---@return nil
function H.notify(msg, lvl, opts)
  opts = opts or {}
  opts.title = opts.title or "cmd"
  vim.notify(msg, vim.log.levels[lvl:upper()], opts)
end

---Convert stream chunks array to a single string with proper line endings.
---
---@param chunks string[] Array of data chunks from stream
---@return string Concatenated string with normalized line endings
function H.stream_tostring(chunks)
  return (table.concat(chunks):gsub("\r", "\n"))
end

---Start reading from a stream pipe into a buffer array.
---
---@param pipe uv.uv_stream_t Stream handle to read from
---@param buffer string[] Buffer array to store chunks
---@return nil
function H.read_stream(pipe, buffer)
  uv.read_start(pipe, function(err, chunk)
    if err then
      return
    end
    if chunk then
      buffer[#buffer + 1] = chunk
    end
  end)
end

---Remove empty lines from string array while preserving order.
---
---@param lines string[] Array of strings that may contain empty lines
---@return string[] Filtered array without empty strings
function H.trim_empty_lines(lines)
  return vim.tbl_filter(function(s)
    return s ~= ""
  end, lines)
end

---Get environment variables configured for a specific executable.
---
---@param executable string Name of the executable to get environment for
---@return string[]|nil Array of environment variable assignments or nil if none
function H.get_cmd_env(executable)
  local env = Cmd.config.env or {}

  ---@type string[]
  local found = {}

  if not vim.tbl_isempty(env) then
    for k, v in pairs(env) do
      if k == executable then
        for _, v2 in ipairs(v) do
          table.insert(found, v2)
        end
      end
    end
  end

  if #found == 0 then
    return nil
  end

  return found
end

---Sanitize a line by removing ANSI escape sequences and trimming whitespace.
---
---Also removes configured prompt patterns if specified in configuration.
---
---@param line string Input line that may contain escape sequences
---@return string Cleaned line with escape sequences removed
function H.sanitize_line(line)
  line = line
    :gsub("\27%[[%d:;]*%d?[ -/]*[@-~]", "") -- Strip every CSI escape. NOTE: Generated by AI
    :gsub("^%s+", "") -- trim leading whitespaces
    :gsub("%s+$", "") -- trim trailing whitespaces
  if Cmd.config.completion.prompt_pattern_to_remove then
    --- trim the whitespaces again after removing the prompt pattern
    line = line:gsub(Cmd.config.completion.prompt_pattern_to_remove, ""):gsub("^%s+", ""):gsub("%s+$", "")
  end
  return line
end

---Sanitize shell completion output by cleaning lines and extracting completions.
---
---Processes each line to remove tab characters and extract the first completion token.
---
---@param lines string[] Raw completion output lines from shell
---@return string[] Cleaned completion candidates
function H.sanitize_file_output(lines)
  ---@type string[]
  local cleaned = {}
  for _, l in ipairs(lines) do
    local first = (H.sanitize_line(l):gsub("\t.*", "")) -- NOTE: safer split
    if first ~= "" then
      table.insert(cleaned, first)
    end
  end

  return cleaned
end

---Write a temporary shell script for completion based on the shell type.
---
---Creates shell-specific completion scripts for bash, zsh, and fish shells.
---Scripts are cached to avoid recreating them for each completion request.
---
---@param shell string Path to shell executable
---@return string|nil Path to temporary script file or nil on failure
function H.write_temp_script(shell)
  if S.temp_script_cache[shell] then
    return S.temp_script_cache[shell]
  end

  local path = vim.fn.tempname() .. ".sh"
  local content = ""

  if shell:find("fish") then
    content = [[
#!/usr/bin/env fish
set -l input "$argv"
complete -C "$input"
]]
  elseif shell:find("zsh") then
    -- TODO: Need help with this, i don't use zsh and no idea how to make it work!
    content = [[]]
  else -- bash
    -- TODO: Need help with this, i don't use bash and no idea how to make it work!
    content = [[]]
  end

  local fd = uv.fs_open(path, "w", 384) -- 0600
  if not fd then
    return nil
  end
  uv.fs_write(fd, content)
  uv.fs_close(fd)

  S.temp_script_cache[shell] = path

  return path
end

---Set the spinner state for a specific command.
---
---@param command_id integer Unique command identifier
---@param opts Cmd.Spinner|nil Spinner configuration or nil to clear
function H.set_spinner_state(command_id, opts)
  if opts and not vim.tbl_isempty(opts) then
    opts = vim.tbl_deep_extend("force", S.spinner_state[command_id] or {}, opts)
  end

  S.spinner_state[command_id] = opts
end

---Get the current spinner state for a specific command.
---
---@param command_id integer Unique command identifier
---@return Cmd.Spinner|nil Current spinner state or nil if not found
function H.get_spinner_state(command_id)
  return S.spinner_state[command_id]
end

---Parse a format function result into computed line pieces.
---Converts display_text to string, computes col/virtual positions and sets is_virtual default.
---@private
---@param format_result Cmd.FormattedLineOpts[]
---@return Cmd.ComputedLineOpts[] parsed
function H.parse_format_fn_result(format_result)
  ---@type Cmd.ComputedLineOpts[]
  local parsed = {}

  ---@type number keep track of the col counts to proper compute every col position
  local current_line_col = 0

  ---@type number keep track of the virtual col counts to proper compute every virtual col position
  local current_line_virtual_col = 0

  for _, item in ipairs(format_result) do
    if type(item) ~= "table" then
      goto continue
    end

    ---@type Cmd.ComputedLineOpts
    ---@diagnostic disable-next-line: missing-fields
    local parsed_item = {}

    -- force `is_virtual` to false just in case
    parsed_item.is_virtual = item.is_virtual or false

    if item.display_text then
      if type(item.display_text) == "string" then
        parsed_item.display_text = item.display_text
      end

      -- just in case user did not `tostring` the number
      if type(item.display_text) == "number" then
        parsed_item.display_text = tostring(item.display_text)
      end

      local text_length = parsed_item.is_virtual and vim.fn.strdisplaywidth(parsed_item.display_text)
        or #parsed_item.display_text

      if not parsed_item.is_virtual then
        ---calculate the start and end column one by one
        parsed_item.col_start = current_line_col
        current_line_col = parsed_item.col_start + text_length
        parsed_item.col_end = current_line_col

        ---always set the virtual col start to the current line virtual col for later calculation
        parsed_item.virtual_col_start = current_line_virtual_col
        parsed_item.virtual_col_end = current_line_virtual_col
      else
        ---always set the col start to the current line col for later calculation
        parsed_item.col_start = current_line_col
        parsed_item.col_end = current_line_col

        parsed_item.virtual_col_start = current_line_virtual_col
        current_line_virtual_col = parsed_item.virtual_col_start + text_length
        parsed_item.virtual_col_end = current_line_virtual_col
      end
    end

    if item.hl_group then
      if type(item.hl_group) == "string" then
        parsed_item.hl_group = item.hl_group
      end
    end

    table.insert(parsed, parsed_item)

    ::continue::
  end

  return parsed
end

---Convert parsed computed line pieces back to a concatenated string.
---@private
---@param parsed Cmd.ComputedLineOpts[]
---@param include_virtual? boolean
---@return string
function H.convert_parsed_format_result_to_string(parsed, include_virtual)
  include_virtual = include_virtual or false
  local display_lines = {}

  for _, item in ipairs(parsed) do
    if item.display_text then
      if include_virtual then
        table.insert(display_lines, item.display_text)
      else
        if not item.is_virtual then
          table.insert(display_lines, item.display_text)
        end
      end
    end
  end

  return table.concat(display_lines, "")
end

---Set extmarks / virtual text highlights for each computed line piece.
---@private
---@param ns number @namespace returned from nvim_create_namespace
---@param bufnr number @buffer number
---@param line_data Cmd.ComputedLineOpts[][] @array of lines -> array of pieces
---@return nil
function H.setup_virtual_text_hls(ns, bufnr, line_data)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  for line_number, line in ipairs(line_data) do
    --- reverse the line so that the virtual text is on the right
    local reversed_line = {}
    for i = #line, 1, -1 do
      table.insert(reversed_line, line[i])
    end

    for _, data in ipairs(reversed_line) do
      if data.is_virtual then
        -- set the virtual text in the right position with it's hl group
        vim.api.nvim_buf_set_extmark(bufnr, ns, line_number - 1, data.col_start, {
          virt_text = { { data.display_text, data.hl_group } },
          virt_text_pos = "inline",
        })
      else
        if data.col_start and data.col_end then
          vim.api.nvim_buf_set_extmark(bufnr, ns, line_number - 1, data.col_start, {
            end_col = data.col_end,
            hl_group = data.hl_group,
          })
        end
      end
    end
  end
end

------------------------------------------------------------------
-- UI
------------------------------------------------------------------

---@class Cmd.FormattedLineOpts
---@field display_text string The display text
---@field hl_group? string The highlight group of the text
---@field is_virtual? boolean Whether the line is virtual

---@class Cmd.ComputedLineOpts : Cmd.FormattedLineOpts
---@field col_start? number The start column of the text, NOTE: this is calculated and for type purpose only
---@field col_end? number The end column of the text, NOTE: this is calculated and for type purpose only
---@field virtual_col_start? number The start virtual column of the text, NOTE: this is calculated and for type purpose only
---@field virtual_col_end? number The end virtual column of the text, NOTE: this is calculated and for type purpose only

---@class Cmd.CommandHistoryFormatterOpts
---@field history Cmd.CommandHistory

---Default history formatter.
---@private
---@param opts Cmd.CommandHistoryFormatterOpts
---@return Cmd.FormattedLineOpts[]
function U.default_history_formatter(opts)
  local virtual_separator = { display_text = " ", is_virtual = true }

  local entry = opts.history

  local status_icon = icon_map[entry.status] or "?"

  local cmd_str = table.concat(entry.cmd, " ")

  local timetamp = entry.timestamp

  local pretty_time = os.date("%Y-%m-%d %H:%M:%S", timetamp)

  return {
    {
      display_text = string.format("#%d", entry.id),
      hl_group = "CmdHistoryIdentifier",
      is_virtual = true,
    },
    virtual_separator,
    {
      display_text = pretty_time,
      hl_group = "CmdHistoryTime",
      is_virtual = true,
    },
    virtual_separator,
    {
      display_text = status_icon,
      hl_group = hl_groups[entry.status],
      is_virtual = true,
    },
    virtual_separator,
    {
      display_text = string.format("[%s]", entry.type:sub(1, 1):upper()),
      hl_group = hl_groups[entry.status],
      is_virtual = true,
    },
    virtual_separator,
    { display_text = cmd_str, hl_group = hl_groups[entry.status] },
  }
end

---@class Cmd.SpinnerDriver
---Driver interface for managing spinner lifecycle during command execution.
---@field pre_exec fun(opts: Cmd.Config.AsyncNotifier.PreExec): string|integer|number|nil Function called before command execution
---@field post_exec fun(opts: Cmd.Config.AsyncNotifier.PostExec) Function called after command completion

---Create a spinner driver for a specific adapter.
---
---The driver manages the complete lifecycle of progress notifications,
---from starting the spinner animation to showing the final result.
---
---@param adapter Cmd.Config.AsyncNotifier.SpinnerAdapter Notification adapter to use
---@return Cmd.SpinnerDriver Configured spinner driver
function U.spinner_driver(adapter)
  return {
    ---Start the spinner animation and initial notification
    ---@param opts Cmd.Config.AsyncNotifier.PreExec Execution context and configuration
    pre_exec = function(opts)
      local timer = uv.new_timer()
      if timer then
        opts.set_spinner_state(opts.command_id, {
          timer = timer,
          active = true,
          msg = string.format("[#%s] running `%s`", opts.command_id, opts.args),
          title = "cmd",
          cmd = opts.args,
        })
      end

      local idx = 1
      local spinner_chars = opts.spinner_chars

      local notify_id = adapter.start(string.format("[#%s] running `%s`", opts.command_id, opts.args), opts)

      if timer then
        timer:start(0, 150, function()
          vim.schedule(function()
            local st = opts.get_spinner_state(opts.command_id)
            if not st or not st.active then
              return
            end

            local msg = st.msg
            if spinner_chars and #spinner_chars > 0 then
              idx = (idx % #spinner_chars) + 1
              msg = string.format("%s %s", spinner_chars[idx], msg)
              opts.current_spinner_char = spinner_chars[idx]
            end
            adapter.update(notify_id, msg, opts)
          end)
        end)
      end
      return notify_id
    end,

    ---Stop spinner and show final execution result
    ---@param opts Cmd.Config.AsyncNotifier.PostExec Post-execution context and results
    post_exec = function(opts)
      local st = opts.get_spinner_state(opts.command_id)
      if not st or not st.active then
        return
      end

      if st.timer and not st.timer:is_closing() then
        st.timer:stop()
        st.timer:close()
      end
      opts.set_spinner_state(opts.command_id, nil)

      local icon = icon_map[opts.status] or " "
      local level = level_map[opts.status] or vim.log.levels.ERROR
      local msg = string.format("%s [#%s] %s `%s`", icon, opts.command_id, opts.status, st.cmd)

      ---@diagnostic disable-next-line: param-type-mismatch
      adapter.finish(opts.user_defined_notifier_id, msg, level, opts)
    end,
  }
end

---Spinner adapter for snacks.nvim notification system.
---
---Uses notification IDs for updating progress messages and maintaining
---consistent notification state throughout command execution.
---@type Cmd.Config.AsyncNotifier.SpinnerAdapter
U.spinner_adapters.snacks = {
  start = function(msg, data)
    H.notify(msg, "INFO", { id = string.format("cmd_progress_%s", data.command_id), title = "cmd" })
    return nil -- snacks uses the id internally
  end,

  update = function(_, msg, data)
    H.notify(msg, "INFO", { id = string.format("cmd_progress_%s", data.command_id), title = "cmd" })
  end,

  finish = function(_, msg, level, data)
    H.notify(msg, level, { id = string.format("cmd_progress_%s", data.command_id), title = "cmd" })
  end,
}

---Spinner adapter for mini.notify notification system.
---
---Manages notification lifecycle using mini.notify's ID-based system
---for updating and removing notifications after completion.
---@type Cmd.Config.AsyncNotifier.SpinnerAdapter
U.spinner_adapters.mini = {
  start = function(msg)
    ---@diagnostic disable-next-line: redefined-local
    local ok, mini_notify = pcall(require, "mini.notify")
    return ok and mini_notify.add(msg, "INFO", nil, {}) or nil
  end,

  update = function(id, msg)
    id = tonumber(id)
    if not id then
      return
    end
    ---@diagnostic disable-next-line: redefined-local
    local ok, mini_notify = pcall(require, "mini.notify")
    if ok then
      local data = mini_notify.get(id)
      data.msg = msg
      mini_notify.update(id, data)
    end
  end,

  finish = function(id, msg, level)
    id = tonumber(id)
    if not id then
      return
    end
    ---@diagnostic disable-next-line: redefined-local
    local ok, mini_notify = pcall(require, "mini.notify")
    if ok then
      local data = mini_notify.get(id)
      data.msg = msg
      data.level = level
      mini_notify.update(id, data)

      vim.defer_fn(function()
        mini_notify.remove(id)
      end, mini_notify.config.lsp_progress.duration_last)
    end
  end,
}

---Spinner adapter for fidget.nvim progress notification system.
---
---Uses fidget's key-based notification system with automatic TTL
---management for progress updates and final results.
---@type Cmd.Config.AsyncNotifier.SpinnerAdapter
U.spinner_adapters.fidget = {
  start = function(msg, data)
    ---@diagnostic disable-next-line: redefined-local
    local ok, fidget = pcall(require, "fidget")
    return ok
        and fidget.notification.notify(msg, "INFO", {
          key = string.format("cmd_progress_%s", data.command_id),
          annote = "cmd",
          ttl = Cmd.config.timeout,
        })
      or nil
  end,

  update = function(_, msg, data)
    ---@diagnostic disable-next-line: redefined-local
    local ok, fidget = pcall(require, "fidget")
    if ok then
      fidget.notification.notify(msg, "INFO", {
        key = string.format("cmd_progress_%s", data.command_id),
        annote = "cmd",
        update_only = true,
      })
    end
  end,

  finish = function(_, msg, level, data)
    ---@diagnostic disable-next-line: redefined-local
    local ok, fidget = pcall(require, "fidget")
    if ok then
      fidget.notification.notify(msg, level, {
        key = string.format("cmd_progress_%s", data.command_id),
        annote = "cmd",
        update_only = true,
        ttl = 0,
      })
    end
  end,
}

---Display command output in a scratch buffer with vertical split.
---
---Creates a read-only buffer with proper filetype and buffer options
---for displaying command results. Supports post-processing hooks.
---
---@param lines string[] Output lines to display in buffer
---@param title string Buffer name/title
---@param post_hook? fun(buf: integer, lines: string[]) Optional callback after buffer creation
---@return nil
function U.show_buffer(lines, title, post_hook)
  local old_buf = vim.fn.bufnr(title)
  if old_buf ~= -1 then
    vim.api.nvim_buf_delete(old_buf, { force = true })
  end

  vim.schedule(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = "cmd"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.bo[buf].buflisted = false
    vim.api.nvim_buf_set_name(buf, title)
    vim.cmd("vsplit | buffer " .. buf)

    if post_hook then
      post_hook(buf, lines)
    end
  end)
end

---Execute command in an interactive terminal buffer.
---
---Creates a terminal buffer in a horizontal split with proper job handling,
---exit code processing, and command history tracking.
---
---@param cmd string[] Command and arguments array
---@param title string Terminal buffer title
---@param command_id integer Unique command identifier
---@return nil
function U.show_terminal(cmd, title, command_id)
  C.track_cmd({
    id = command_id,
    cmd = cmd,
    type = "interactive",
    status = "running",
  })

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "cmd"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.keymap.set("n", "q", function()
    vim.cmd("close")
  end, { buffer = buf, nowait = true })

  vim.api.nvim_buf_set_name(buf, title)
  vim.cmd("botright split | buffer " .. buf)

  local env = H.get_cmd_env(cmd[1])

  if env then
    local env_copy = vim.deepcopy(env)
    table.insert(env_copy, 1, "env")

    cmd = vim.list_extend(env_copy, cmd)
  else
    cmd = { unpack(cmd) }
  end

  vim.fn.jobstart(cmd, {
    cwd = S.cwd,
    term = true,
    on_exit = function(_, code)
      U.refresh_ui()

      if code == 0 then
        C.track_cmd({
          id = command_id,
          status = "success",
        })
        return
      end

      vim.schedule(function()
        -- 130 = Interrupted (Ctrl+C)
        if code == 130 then
          C.track_cmd({
            id = command_id,
            status = "cancelled",
          })
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
          return
        end

        local cmd_string = table.concat(cmd, " ")

        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        lines = H.trim_empty_lines(lines)

        local preview = (#lines <= 6) and table.concat(lines, "\n")
          or table.concat(vim.list_slice(lines, 1, 3), "\n")
            .. "\n...omitted...\n"
            .. table.concat(vim.list_slice(lines, #lines - 2, #lines), "\n")

        H.notify(string.format("`%s` exited %d\n%s", cmd_string, code, preview), "ERROR")

        C.track_cmd({
          id = command_id,
          status = "failed",
        })
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end)
    end,
  })

  vim.cmd("startinsert")
end

---Refresh the user interface to reflect any changes.
---
---Triggers redraw and file change detection to ensure UI consistency
---after command execution or other state changes.
---
---@return nil
function U.refresh_ui()
  vim.schedule(function()
    vim.cmd("redraw!")
    vim.cmd("checktime")
  end)
end

------------------------------------------------------------------
-- Core
------------------------------------------------------------------

---@class Cmd.RunResult
---Result of a command execution, returned only for synchronous operations.
---@field code integer Exit code of the command (0 for success)
---@field out string Standard output content
---@field err string Standard error content

---Execute a CLI command with async handling, timeout, and cancellation support.
---
---Spawns a process using libuv with proper stream handling, timeout management,
---and signal-based cancellation. Supports both sync and async execution patterns.
---
---@param cmd string[] Command and arguments to execute
---@param command_id integer Unique identifier for tracking
---@param on_done fun(code: integer, out: string, err: string, is_cancelled?: boolean) Completion callback
---@param timeout? integer Timeout in milliseconds (default: config.timeout)
---@return Cmd.RunResult? result Only returned for synchronous execution
function C.exec_cli(cmd, command_id, on_done, timeout)
  timeout = timeout or Cmd.config.timeout

  H.ensure_cwd()

  -- Create a coroutine
  local stdout, stderr = uv.new_pipe(false), uv.new_pipe(false)
  local out_chunks, err_chunks = {}, {}
  local done = false
  ---@type uv.uv_timer_t|nil
  local timer

  local function finish(code, out, err)
    if done then
      return
    end
    done = true

    -- stop & close the timer so it can never fire
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end

    if stdout and not stdout:is_closing() then
      stdout:close()
    end
    if stderr and not stderr:is_closing() then
      stderr:close()
    end

    local is_cancelled = code == 130
    local final_out = out or ""
    local final_err = err or ""

    vim.schedule(function()
      on_done(code, final_out, final_err, is_cancelled)
    end)
  end

  local process = uv.spawn(cmd[1], {
    args = vim.list_slice(cmd, 2),
    cwd = S.cwd,
    stdio = { nil, stdout, stderr },
    env = nil,
    uid = nil,
    gid = nil,
    verbatim = nil,
    detached = nil,
    hide = nil,
  }, function(code, signal)
    S.command_history[command_id].job = nil

    if signal == 2 then
      code = 130
    end -- SIGINT
    if signal == 15 then
      code = 143
    end -- SIGTERM
    if signal == 9 then
      code = 137
    end -- SIGKILL

    finish(code, H.stream_tostring(out_chunks), H.stream_tostring(err_chunks))
  end)

  if not process then
    on_done(127, "", string.format("failed to spawn process: %s", cmd[1]))
    return
  end

  S.command_history[command_id].job = process

  if stdout then
    H.read_stream(stdout, out_chunks)
  end
  if stderr then
    H.read_stream(stderr, err_chunks)
  end

  -- Set up timeout
  if timeout and timeout > 0 then
    timer = uv.new_timer()
    if timer then
      timer:start(timeout, 0, function()
        if process and not process:is_closing() then
          process:kill("sigterm")
          vim.defer_fn(function()
            if process and not process:is_closing() then
              process:kill("sigkill")
            end
          end, 1000)
        end
        timer:close()
        finish(124, "", string.format("process killed after timeout: %s", cmd[1]))
      end)
    end
  end
end

---Cancel a running command with graceful termination and fallback to force kill.
---
---Attempts graceful termination with SIGINT, then escalates to SIGKILL if needed.
---Updates command status and cleans up process resources.
---
---@param job uv.uv_process_t|nil Process handle to cancel
---@param command_id number Command identifier for status tracking
---@return nil
function C.cancel_with_fallback(job, command_id)
  if not job or job:is_closing() then
    return
  end

  job:kill("sigint")
  vim.defer_fn(function()
    if job and not job:is_closing() then
      job:kill("sigkill")
    end
  end, 1000) -- give 1 second to terminate cleanly

  C.track_cmd({
    id = command_id,
    status = "cancelled",
  })
end

---Cancel running commands by ID or all running commands.
---
---@param command_id number|nil Specific command ID to cancel, or nil for last command
---@param all boolean If true, cancel all running commands
---@return nil
local function cancel_cmd(command_id, all)
  if all then
    local count = 0
    for id, entry in pairs(S.command_history) do
      if entry.job and not entry.job:is_closing() then
        C.cancel_with_fallback(entry.job, entry.id)
        S.command_history[id].job = nil
        count = count + 1
      end
    end
    H.notify(string.format("Cancelled %d running commands", count), "WARN")
    return
  end

  local id = command_id or #S.command_history
  local job = S.command_history[id].job

  if job and not job:is_closing() then
    C.cancel_with_fallback(job, id)
    S.command_history[id].job = nil
  else
    H.notify("No running command to cancel", "WARN")
  end
end

---Get shell completion candidates for a command using temporary completion scripts.
---
---Creates shell-specific completion scripts and executes them to get completion
---candidates. Supports bash, zsh, and fish shells with proper completion loading.
---
---@param executable? string Executable name for completion (nil for root Cmd calls)
---@param lead_args string Leading arguments before cursor
---@param cmd_line string Complete command line being completed
---@param cursor_pos integer Current cursor position in command line
---@return string[] Array of completion candidates
function C.cached_shell_complete(executable, lead_args, cmd_line, cursor_pos)
  if Cmd.config.completion.enabled == false then
    return {}
  end

  H.ensure_cwd()

  --- this should be the root `Cmd` call rather than user defined commands
  --- we can then set the right executable and reconstruct the cmd_line to let it work normally
  if not executable then
    local cmd_line_table = vim.split(cmd_line, " ")
    table.remove(cmd_line_table, 1)

    executable = cmd_line_table[1]

    cmd_line = table.concat(cmd_line_table, " ")
  end

  local shell = Cmd.config.completion.shell or vim.env.SHELL or "/bin/bash"

  -- TODO:: Need to add support for zsh and bash, but not sure how
  -- for now, let's just throw error if it's not fish... Sorry! and please help!
  if shell ~= "fish" then
    H.notify("Sorry, shell completion is only supported for fish at this moment.", "ERROR")
    H.notify("As I mainly daily driving fish shell, please help to make bash and zsh work ~.", "ERROR")
    return {}
  end

  local script_path = H.write_temp_script(shell)
  if not script_path then
    H.notify("Failed to create temp script", "ERROR")
    return {}
  end

  -- Build the exact line the shell would see
  local full_line = cmd_line:sub(1, cursor_pos)

  local full_line_table = vim.split(full_line, " ")
  full_line_table[1] = executable
  full_line = table.concat(full_line_table, " ")

  local result = vim
    .system({ shell, script_path, full_line }, {
      text = true,
      cwd = S.cwd,
    })
    :wait()

  if result.code ~= 0 then
    H.notify("Shell completion failed with exit code: " .. result.code, "WARN")
    return {}
  end

  local lines = vim.split(result.stdout, "\n")

  local completions = H.sanitize_file_output(lines)

  return completions
end

---Execute a command in terminal (interactive) or buffer (normal) mode.
---
---Handles executable validation, command history tracking, environment setup,
---and output display. Supports both terminal and buffer execution modes.
---
---@param args string[] Command arguments array
---@param bang boolean If true, force terminal execution
---@return nil
function C.run_cmd(args, bang)
  local executable = args[1]
  if vim.fn.executable(executable) == 0 then
    H.notify(executable .. " is not executable", "WARN")
    return
  end

  local command_id = #S.command_history + 1

  if bang then
    U.show_terminal(args, "cmd://" .. table.concat(args, " "), command_id)
  else
    C.track_cmd({
      id = command_id,
      cmd = args,
      type = "normal",
      status = "running",
    })

    local user_defined_notifier_id = nil

    if Cmd.config.async_notifier.adapter and type(Cmd.config.async_notifier.adapter) == "table" then
      user_defined_notifier_id = U.spinner_driver(Cmd.config.async_notifier.adapter).pre_exec({
        command_id = command_id,
        args_raw = args,
        args = table.concat(args, " "),
        get_spinner_state = H.get_spinner_state,
        set_spinner_state = H.set_spinner_state,
        spinner_chars = Cmd.config.async_notifier.spinner_chars,
      })
    else
      local msg = string.format("? [#%s] running `%s`", command_id, table.concat(args, " "))
      H.notify(msg, "INFO")
    end

    C.exec_cli(args, command_id, function(code, out, err, is_cancelled)
      ---@type Cmd.CommandStatus
      local status

      if is_cancelled then
        status = "cancelled"
      else
        status = code == 0 and "success" or "failed"

        local text = table.concat(H.trim_empty_lines({ err, out }), "\n")

        local lines = vim.split(text, "\n")
        lines = H.trim_empty_lines(lines)

        for i, line in ipairs(lines) do
          --- Strip ANSI escape codes
          lines[i] = line:gsub("\27%[[0-9;]*m", "")
        end

        if #lines > 0 then
          U.show_buffer(lines, "cmd://" .. table.concat(args, " ") .. "-" .. command_id)
        else
          H.notify("Completed but no output lines", "INFO")
        end

        if status == "success" then
          U.refresh_ui()
        end
      end

      if Cmd.config.async_notifier.adapter and type(Cmd.config.async_notifier.adapter) == "table" then
        U.spinner_driver(Cmd.config.async_notifier.adapter).post_exec({
          command_id = command_id,
          args_raw = args,
          args = table.concat(args, " "),
          get_spinner_state = H.get_spinner_state,
          set_spinner_state = H.set_spinner_state,
          status = status,
          user_defined_notifier_id = user_defined_notifier_id,
        })
      else
        local icon = icon_map[status] or " "
        local level = level_map[status] or vim.log.levels.ERROR

        local msg = string.format("%s [#%s] %s `%s`", icon, command_id, status, table.concat(args, " "))
        H.notify(msg, level)
      end

      C.track_cmd({
        id = command_id,
        status = status,
      })
    end)
  end
end

---Track a command entry in the execution history.
---
---Updates or creates a command history entry with execution details,
---status updates, and timestamp information.
---
---@param opts Cmd.CommandHistory Command history data to track
---@return nil
function C.track_cmd(opts)
  opts = vim.tbl_deep_extend("force", S.command_history[opts.id] or {}, opts)

  opts.timestamp = os.time()

  S.command_history[opts.id] = opts
end

------------------------------------------------------------------
-- Public Interface
------------------------------------------------------------------

---@tag Cmd.config

---@type Cmd.Config
---Module configuration with all available options and defaults.
Cmd.config = {}

---@class Cmd.Config.Completion
---Configuration for shell completion functionality.
---@field enabled? boolean Whether to enable shell completion (default: false)
---@field shell? string Shell executable to use for completion (default: $SHELL or "/bin/sh")
---@field prompt_pattern_to_remove? string Regex pattern to remove from completion output

---@class Cmd.Config.AsyncNotifier.PreExec
---Context passed to spinner adapter before command execution.
---@field command_id integer Unique command identifier
---@field args_raw string[] Original command arguments array
---@field args string Concatenated command string
---@field set_spinner_state fun(command_id: integer, opts: Cmd.Spinner|nil) Set spinner state
---@field get_spinner_state fun(command_id: integer): Cmd.Spinner|nil Get spinner state
---@field spinner_chars string[] Array of spinner animation characters
---@field current_spinner_char? string Currently displayed spinner character

---@class Cmd.Config.AsyncNotifier.PostExec
---Context passed to spinner adapter after command execution.
---@field command_id integer Unique command identifier
---@field args_raw string[] Original command arguments array
---@field args string Concatenated command string
---@field set_spinner_state fun(command_id: integer, opts: Cmd.Spinner|nil) Set spinner state
---@field get_spinner_state fun(command_id: integer): Cmd.Spinner|nil Get spinner state
---@field status Cmd.CommandStatus Final command execution status
---@field user_defined_notifier_id? string|integer|number|nil Adapter-specific notification ID

---@class Cmd.Config.AsyncNotifier
---Configuration for async command notifications and progress indicators.
---@field spinner_chars? string[] Characters for spinner animation (default: braille patterns)
---@field adapter? Cmd.Config.AsyncNotifier.SpinnerAdapter Custom notification adapter

---@class Cmd.Config.AsyncNotifier.SpinnerAdapter
---Interface for custom notification adapters to handle progress display.
---@field start fun(msg: string, data: Cmd.Config.AsyncNotifier.PreExec): string|integer|nil Initialize progress notification
---@field update fun(notify_id: string|integer|number|nil, msg: string, data: Cmd.Config.AsyncNotifier.PreExec) Update progress message
---@field finish fun(notify_id: string, msg: string, level: Cmd.LogLevel, data: Cmd.Config.AsyncNotifier.PostExec) Show final result

---@class Cmd.Config
---Main configuration table for the Cmd plugin.
---@field force_terminal? table<string, string[]> Patterns that force terminal execution per executable
---@field create_usercmd? table<string, string> Auto-create user commands for executables
---@field env? table<string, string[]> Environment variables per executable
---@field timeout? integer Default command timeout in milliseconds (default: 30000)
---@field completion? Cmd.Config.Completion Shell completion configuration
---@field async_notifier? Cmd.Config.AsyncNotifier Progress notification configuration
---@field history_formatter_fn? fun(opts: Cmd.CommandHistoryFormatterOpts): Cmd.FormattedLineOpts[] Formatter function for history display

---@tag Cmd.defaults

---Default configuration values for all plugin options.
---@type Cmd.Config
Cmd.defaults = {
  force_terminal = {},
  create_usercmd = {},
  env = {},
  timeout = 30000,
  completion = {
    enabled = false,
    shell = vim.env.SHELL or "/bin/sh",
  },
  async_notifier = {
    spinner_chars = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    adapter = nil,
  },
  history_formatter_fn = U.default_history_formatter,
}

---Create user commands for configured executables if they don't already exist.
---
---Checks if executables are available and user commands don't exist,
---then creates them with proper completion and terminal force detection.
---
---@return nil
local function create_usercmd_if_not_exists()
  local existing_cmds = vim.api.nvim_get_commands({})
  for executable, cmd_name in pairs(Cmd.config.create_usercmd) do
    if vim.fn.executable(executable) == 1 and not existing_cmds[cmd_name] then
      vim.api.nvim_create_user_command(cmd_name, function(opts)
        local fargs = vim.deepcopy(opts.fargs)

        -- to support expanding the args like %
        for i, arg in ipairs(fargs) do
          fargs[i] = vim.fn.expand(arg)
        end

        local args = { executable, unpack(fargs) }
        local bang = opts.bang

        local force_terminal_executable = Cmd.config.force_terminal[executable] or {}

        if not vim.tbl_isempty(force_terminal_executable) then
          for _, value in ipairs(force_terminal_executable) do
            local args_string = table.concat(args, " ")
            local matched = string.find(args_string, value, 1, true) ~= nil

            if matched == true then
              bang = true
              break
            end
          end
        end

        C.run_cmd(args, bang)
      end, {
        nargs = "*",
        bang = true,
        complete = function(...)
          return C.cached_shell_complete(executable, ...)
        end,
        desc = "Auto-generated command for " .. executable,
      })
    else
      H.notify(("%s is not executable or already exists"):format(executable), "WARN")
    end
  end
end

---Set up all user commands for the plugin.
---
---Creates the main :Cmd command and related commands like :CmdRerun,
---:CmdCancel, and :CmdHistory with appropriate completion and documentation.
---
---@return nil
local function setup_usercmds()
  vim.api.nvim_create_user_command("Cmd", function(opts)
    local bang = opts.bang or false
    local args = vim.deepcopy(opts.fargs)

    -- to support expanding the args like %
    for i, arg in ipairs(args) do
      args[i] = vim.fn.expand(arg)
    end

    if #args < 1 then
      H.notify("No arguments provided", "WARN")
      return
    end

    local executable = args[1]

    if vim.fn.executable(executable) == 0 then
      H.notify(("%s is not executable"):format(executable), "WARN")
      return
    end

    local force_terminal_executable = Cmd.config.force_terminal[executable] or {}

    if not vim.tbl_isempty(force_terminal_executable) then
      for _, value in pairs(force_terminal_executable) do
        local args_string = table.concat(args, " ")
        local matched = string.find(args_string, value, 1, true) ~= nil

        if matched == true then
          bang = true
          break
        end
      end
    end

    C.run_cmd(args, bang)
  end, {
    nargs = "*",
    bang = true,
    complete = function(...)
      return C.cached_shell_complete(nil, ...)
    end,
    desc = "Run CLI command (add ! to run in terminal, add !! to rerun last command in terminal)",
  })

  vim.api.nvim_create_user_command("CmdRerun", function(opts)
    local bang = opts.bang or false
    local id = tonumber(opts.args) or #S.command_history
    local command_entry = S.command_history[id]

    if not command_entry then
      H.notify("No command history", "WARN")
      return
    end

    local args = command_entry.cmd

    if not args then
      H.notify("No args to rerun", "WARN")
      return
    end

    local executable = args[1]

    local force_terminal_executable = Cmd.config.force_terminal[executable] or {}

    if not vim.tbl_isempty(force_terminal_executable) then
      for _, value in pairs(force_terminal_executable) do
        local args_string = table.concat(args, " ")
        local matched = string.find(args_string, value, 1, true) ~= nil

        if matched == true then
          bang = true
          break
        end
      end
    end

    C.run_cmd(args, bang)
  end, {
    bang = true,
    nargs = "?",
    desc = "Rerun the last command",
  })

  vim.api.nvim_create_user_command("CmdCancel", function(opts)
    local id = tonumber(opts.args)
    cancel_cmd(id, opts.bang)
  end, {
    bang = true,
    nargs = "?",
    desc = "Cancel the currently running Cmd (add ! to cancel all)",
  })

  vim.api.nvim_create_user_command("CmdHistory", function()
    local history = S.command_history

    if #history == 0 then
      H.notify("No command history", "INFO")
      return
    end

    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.6)

    -- Prepare floating window / buffer
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, false, {
      relative = "editor",
      width = width,
      height = height,
      col = (vim.o.columns - width) / 2,
      row = (vim.o.lines - height) / 2,
      style = "minimal",
      border = "rounded",
      title = "Command History",
    })

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = true

    vim.wo[win].winhighlight = string.format(
      "NormalFloat:%s,FloatBorder:%s,FloatTitle:%s",
      "CmdHistoryNormal",
      "CmdHistoryBorder",
      "CmdHistoryTitle"
    )

    local close = function()
      pcall(vim.api.nvim_win_close, win, true)
    end

    for _, key in ipairs({ "<Esc>", "q", "<C-c>" }) do
      vim.keymap.set("n", key, close, { buffer = buf, nowait = true })
    end

    vim.api.nvim_create_autocmd("WinLeave", { buffer = buf, once = true, callback = close })

    ---@type string[]
    local lines = {}

    ---@type Cmd.FormattedLineOpts[][]
    local formatted_raw_data = {}

    for i = #history, 1, -1 do
      local entry = history[i]

      local formatter_fn = Cmd.config.history_formatter_fn or U.default_history_formatter

      if type(formatter_fn) ~= "function" then
        error("`opts.history_formatter_fn` must be a function")
        return
      end

      local formatted = formatter_fn({
        history = entry,
      })

      local formatted_line_data = H.parse_format_fn_result(formatted)
      local formatted_line = H.convert_parsed_format_result_to_string(formatted_line_data)

      table.insert(lines, formatted_line)
      table.insert(formatted_raw_data, formatted_line_data)
    end

    pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, lines)

    vim.bo[buf].modifiable = false

    local ns = vim.api.nvim_create_namespace("cmd_history")
    H.setup_virtual_text_hls(ns, buf, formatted_raw_data)

    vim.api.nvim_set_current_win(win)
  end, {
    desc = "History",
  })
end

---Set up autocmds for cleanup and resource management.
---
---Handles cleanup of timers and temporary files when Neovim exits
---to prevent resource leaks and file system pollution.
---
---@return nil
local function setup_autocmds()
  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      -- stop all timers
      for _, st in pairs(S.spinner_state) do
        if st.timer and not st.timer:is_closing() then
          st.timer:stop()
          st.timer:close()
        end
      end

      -- delete all temp scripts
      for _, path in pairs(S.temp_script_cache) do
        H.safe_delete(path)
      end
    end,
  })
end

---Set up default highlight groups for the plugin.
---
---Creates highlight group definitions with sensible defaults
---that link to existing Neovim highlight groups.
---
---@return nil
local function setup_hls()
  local hi = function(name, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end

  hi("CmdHistoryNormal", { link = "NormalFloat" })
  hi("CmdHistoryBorder", { link = "FloatBorder" })
  hi("CmdHistoryTitle", { link = "FloatTitle" })
  hi("CmdHistoryIdentifier", { link = "Identifier" })
  hi("CmdHistoryTime", { link = "Comment" })
  hi("CmdSuccess", { link = "MoreMsg" })
  hi("CmdFailed", { link = "ErrorMsg" })
  hi("CmdCancelled", { link = "WarningMsg" })
end

---Validate that a notification adapter implements the required interface.
---
---Ensures that custom adapters have all required methods with proper signatures
---to prevent runtime errors during command execution.
---
---@param adapter? Cmd.Config.AsyncNotifier.SpinnerAdapter Adapter to validate
---@return nil
local function validate_adapter(adapter)
  if adapter == nil then
    return
  end

  if type(adapter) ~= "table" then
    error("`opts.async_notifier.adapter` must be a table")
  end

  if adapter.start == nil or type(adapter.start) ~= "function" then
    error("`opts.async_notifier.adapter.start` must be a function")
  end

  if adapter.update == nil or type(adapter.update) ~= "function" then
    error("`opts.async_notifier.adapter.update` must be a function")
  end

  if adapter.finish == nil or type(adapter.finish) ~= "function" then
    error("`opts.async_notifier.adapter.finish` must be a function")
  end
end

---@tag Cmd.setup()

---Set up the Cmd plugin with user configuration.
---
---Initializes all plugin components, validates configuration,
---creates user commands, and sets up necessary autocmds and highlights.
---
---@param user_config? Cmd.Config User configuration to merge with defaults
---@return nil
---@usage [[
---   -- Minimal setup with defaults
---   require('cmd').setup()
---
---   -- Custom configuration
---   require('cmd').setup({
---     completion = { enabled = true },
---     timeout = 60000,
---     async_notifier = {
---       adapter = require('cmd').builtins.spinner_adapters.snacks
---     }
---   })
---@usage ]]
function Cmd.setup(user_config)
  Cmd.config = vim.tbl_deep_extend("force", Cmd.defaults, user_config or {})

  validate_adapter(Cmd.config.async_notifier.adapter)

  if Cmd.config.create_usercmd and not vim.tbl_isempty(Cmd.config.create_usercmd) then
    create_usercmd_if_not_exists()
  end

  setup_autocmds()
  setup_usercmds()
  setup_hls()
end

---@class Cmd.builtins
---Built-in utilities and adapters for extending plugin functionality.
---@field spinner_driver fun(adapter: Cmd.Config.AsyncNotifier.SpinnerAdapter): Cmd.SpinnerDriver Create spinner driver for adapter
---@field spinner_adapters table<"snacks"|"mini"|"fidget", Cmd.Config.AsyncNotifier.SpinnerAdapter> Pre-built notification adapters

---@tag Cmd.builtins

---Built-in utilities and notification adapters.
---
---Provides pre-built notification adapters for popular plugins and utilities
---for creating custom notification implementations.
---
---@type Cmd.builtins
---@usage [[
---   -- Use built-in snacks.nvim adapter
---   require('cmd').setup({
---     async_notifier = {
---       adapter = require('cmd').builtins.spinner_adapters.snacks
---     }
---   })
---
---   -- Create custom adapter with spinner driver
---   local custom_adapter = {
---     start = function(msg) return my_notify_start(msg) end,
---     update = function(id, msg) my_notify_update(id, msg) end,
---     finish = function(id, msg, level) my_notify_finish(id, msg, level) end
---   }
---   local driver = require('cmd').builtins.spinner_driver(custom_adapter)
---
---   -- Custom history formatter
---   local custom_history_formatter = function(opts)
---     local history = opts.history
---     local formatted = {}
---
---     for i = 1, #history do
---       local entry = history[i]
---       local formatted_line = {
---         display_text = entry.cmd[1],
---         hl_group = "CmdHistoryIdentifier",
---         is_virtual = true,
---       }
---       table.insert(formatted, formatted_line)
---     end
---
---     return formatted
---   end
---   require('cmd').setup({
---     history_formatter_fn = custom_history_formatter
---   })
---@usage ]]
Cmd.builtins = {
  spinner_driver = U.spinner_driver,
  spinner_adapters = U.spinner_adapters,
  history_formatter_fn = U.default_history_formatter,
}

return Cmd
