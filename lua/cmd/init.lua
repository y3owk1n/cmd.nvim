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
---  progress_notifier = {
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
---## Progress notifications ~
---
---Configure progress notifications with different adapters:
--->lua
---   -- Using built-in snacks.nvim adapter
---   require('cmd').setup({
---     progress_notifier = {
---       adapter = require('cmd').builtins.spinner_adapters.snacks,
---       spinner_chars = { '⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷' },
---     }
---   })
---
---   -- Using custom adapter
---   require('cmd').setup({
---     progress_notifier = {
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

local M = {}

-- ============================================================================
-- ENVIRONMENT VALIDATION & SETUP
-- ============================================================================

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

---@private
---Flag to prevent setup from running multiple times
local setup_complete = false

-- ============================================================================
-- TYPE DEFINITIONS
-- ============================================================================

---@mod cmd.types Types

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
---@field next_command_id integer Next command identifier for tracking

---@alias Cmd.LogLevel
---| '"INFO"'  # Informational message
---| '"WARN"'  # Warning message
---| '"ERROR"' # Error message

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

---@class Cmd.SpinnerDriver
---Driver interface for managing spinner lifecycle during command execution.
---@field start fun(opts: Cmd.Config.ProgressNotifier.Start): string|integer|number|nil Function called before command execution
---@field stop fun(opts: Cmd.Config.ProgressNotifier.Finish) Function called after command completion

---@class Cmd.RunResult
---Result of a command execution, returned only for synchronous operations.
---@field code integer Exit code of the command (0 for success)
---@field out string Standard output content
---@field err string Standard error content

---@class Cmd.Config.Completion
---Configuration for shell completion functionality.
---@field enabled? boolean Whether to enable shell completion (default: false)
---@field shell? string Shell executable to use for completion (default: $SHELL or "/bin/sh")
---@field prompt_pattern_to_remove? string Regex pattern to remove from completion output

---@class Cmd.Config.ProgressNotifier.Start
---Context passed to spinner adapter before command execution.
---@field command_id integer Unique command identifier
---@field args_raw string[] Original command arguments array
---@field args string Concatenated command string
---@field current_spinner_char? string Currently displayed spinner character

---@class Cmd.Config.ProgressNotifier.Finish
---Context passed to spinner adapter after command execution.
---@field command_id integer Unique command identifier
---@field args_raw string[] Original command arguments array
---@field args string Concatenated command string
---@field status Cmd.CommandStatus Final command execution status
---@field user_defined_notifier_id? string|integer|number|nil Adapter-specific notification ID

---@class Cmd.Config.ProgressNotifier
---Configuration for async command notifications and progress indicators.
---@field spinner_chars? string[] Characters for spinner animation (default: braille patterns)
---@field adapter? Cmd.Config.ProgressNotifier.SpinnerAdapter Custom notification adapter

---@class Cmd.Config.ProgressNotifier.SpinnerAdapter
---Interface for custom notification adapters to handle progress display.
---@field start fun(msg: string, data: Cmd.Config.ProgressNotifier.Start): string|integer|nil Initialize progress notification
---@field update fun(notify_id: string|integer|number|nil, msg: string, data: Cmd.Config.ProgressNotifier.Start) Update progress message
---@field finish fun(notify_id: string|integer|number|nil, msg: string, level: Cmd.LogLevel, data: Cmd.Config.ProgressNotifier.Finish) Show final result

---@class Cmd.Config
---Main configuration table for the Cmd plugin.
---@field force_terminal? table<string, string[]> Patterns that force terminal execution per executable
---@field create_usercmd? table<string, string> Auto-create user commands for executables
---@field env? table<string, string[]> Environment variables per executable
---@field timeout? integer Default command timeout in milliseconds (default: 30000)
---@field completion? Cmd.Config.Completion Shell completion configuration
---@field progress_notifier? Cmd.Config.ProgressNotifier Progress notification configuration
---@field history_formatter_fn? fun(opts: Cmd.CommandHistoryFormatterOpts): Cmd.FormattedLineOpts[] Formatter function for history display

---@class Cmd.Builtins
---Built-in utilities and adapters for extending plugin functionality.
---@field spinner_adapters table<"snacks"|"mini"|"fidget", Cmd.Config.ProgressNotifier.SpinnerAdapter> Pre-built notification adapters
---@field formatters Cmd.Builtins.Formatters Built-in formatters

---@class Cmd.Builtins.Formatters
---@field default_history fun(opts: Cmd.CommandHistoryFormatterOpts): Cmd.FormattedLineOpts[] Default history formatter

-- ============================================================================
-- CONSTANTS
-- ============================================================================

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

-- ============================================================================
-- GLOBAL STATE MANAGEMENT
-- ============================================================================

---@type Cmd.State
local State = {
  config = {},
  cwd = "",
  temp_script_cache = {},
  spinner_state = {},
  command_history = {},
  next_command_id = 1,
}

---Initialize state
---@private
---@return nil
local function init_state()
  State.cwd = vim.fn.getcwd()
  State.next_command_id = 1
  State.command_history = {}
  State.spinner_state = {}
  State.temp_script_cache = {}
end

-- ============================================================================
-- CONFIGURATION MANAGEMENT
-- ============================================================================

---Default configuration
---@type Cmd.Config
local DEFAULT_CONFIG = {
  force_terminal = {},
  create_usercmd = {},
  env = {},
  timeout = 30000,
  completion = {
    enabled = false,
    shell = vim.env.SHELL or "/bin/sh",
  },
  progress_notifier = {
    spinner_chars = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    adapter = nil,
  },
  history_formatter_fn = nil, -- Set below
}

---Validate configuration
---@param config Cmd.Config
---@return boolean, string?
---@private
local function validate_config(config)
  -- Validate timeout
  if config.timeout and (type(config.timeout) ~= "number" or config.timeout < 0) then
    return false, "timeout must be a positive number"
  end

  -- Validate completion config
  if config.completion then
    local comp = config.completion
    if comp and comp.enabled ~= nil and type(comp.enabled) ~= "boolean" then
      return false, "completion.enabled must be boolean"
    end
    if comp and comp.shell and type(comp.shell) ~= "string" then
      return false, "completion.shell must be string"
    end
  end

  -- Validate progress notifier
  if config.progress_notifier and config.progress_notifier.adapter then
    local adapter = config.progress_notifier.adapter
    if type(adapter) ~= "table" then
      return false, "progress_notifier.adapter must be table"
    end

    local required_methods = { "start", "update", "finish" }
    for _, method in ipairs(required_methods) do
      if type(adapter[method]) ~= "function" then
        return false, string.format("progress_notifier.adapter.%s must be function", method)
      end
    end
  end

  return true, nil
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

---@private
---@class Cmd.Utils
local Utils = {}

---Safe file deletion with deferred execution
---@param path string File path to delete
function Utils.safe_delete(path)
  vim.defer_fn(function()
    pcall(vim.fn.delete, path)
  end, 0)
end

---Ensure current working directory is set
function Utils.ensure_cwd()
  local buf_dir = vim.fn.expand("%:p:h")
  if buf_dir and vim.fn.isdirectory(buf_dir) == 1 then
    State.cwd = buf_dir
  else
    State.cwd = vim.fn.getcwd()
  end
end

---Display notification with proper formatting
---@param msg string Message content
---@param level Cmd.LogLevel Log level
---@param opts? table Additional options
function Utils.notify(msg, level, opts)
  opts = opts or {}
  opts.title = opts.title or "cmd.nvim"
  vim.notify(msg, vim.log.levels[level:upper()], opts)
end

---Convert stream chunks to string with normalized line endings
---@param chunks string[] Data chunks
---@return string
function Utils.stream_to_string(chunks)
  local normalized = table.concat(chunks):gsub("\r\n", "\n"):gsub("\r", "\n")
  return normalized
end

---Remove empty lines from array
---@param lines string[] Array of strings
---@return string[] Filtered array
function Utils.trim_empty_lines(lines)
  return vim.tbl_filter(function(line)
    return line and line:match("%S") ~= nil
  end, lines)
end

---Start reading from stream pipe into buffer
---@param pipe uv.uv_stream_t Stream handle
---@param buffer string[] Buffer to store chunks
function Utils.read_stream(pipe, buffer)
  uv.read_start(pipe, function(err, chunk)
    if err then
      Utils.notify("Stream read error: " .. tostring(err), "ERROR")
      return
    end
    if chunk then
      buffer[#buffer + 1] = chunk
    end
  end)
end

---Sanitize line by removing ANSI codes and trimming
---@param line string Input line
---@return string Cleaned line
function Utils.sanitize_line(line)
  line = line
    :gsub("\27%[[%d:;]*%d?[ -/]*[@-~]", "") -- Remove ANSI escape codes
    :gsub("^%s+", "") -- Trim leading spaces
    :gsub("%s+$", "") -- Trim trailing spaces

  -- Remove prompt pattern if configured
  if State.config.completion.prompt_pattern_to_remove then
    line = line:gsub(State.config.completion.prompt_pattern_to_remove, ""):gsub("^%s+", ""):gsub("%s+$", "")
  end

  return line
end

---Get environment variables for executable
---@param executable string Executable name
---@return string[]? Environment variables or nil
function Utils.get_cmd_env(executable)
  local env = State.config.env or {}
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

  return #found > 0 and found or nil
end

---Parse a format function result into computed line pieces.
---Converts display_text to string, computes col/virtual positions and sets is_virtual default.
---@private
---@param format_result Cmd.FormattedLineOpts[]
---@return Cmd.ComputedLineOpts[] parsed
function Utils.parse_format_fn_result(format_result)
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
function Utils.convert_parsed_format_result_to_string(parsed, include_virtual)
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
function Utils.setup_virtual_text_hls(ns, bufnr, line_data)
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

-- ============================================================================
-- COMMAND HISTORY MANAGEMENT
-- ============================================================================

---@private
---@class Cmd.History
local History = {}

---Track command in history
---@param entry Cmd.CommandHistory Command entry
function History.track(entry)
  local id = entry.id
  local existing = State.command_history[id] or {}

  -- Merge with existing entry
  for key, value in pairs(entry) do
    existing[key] = value
  end

  existing.timestamp = existing.timestamp or os.time()
  State.command_history[id] = existing
end

---Get command from history by ID
---@param id integer Command ID
---@return Cmd.CommandHistory? Command entry or nil
function History.get(id)
  return State.command_history[id]
end

---Get all command history
---@return Cmd.CommandHistory[] All history entries
function History.get_all()
  return State.command_history
end

---Get next available command ID
---@return integer Next command ID
function History.get_next_id()
  local id = State.next_command_id
  State.next_command_id = id + 1
  return id
end

---Default history formatter
---@param opts Cmd.CommandHistoryFormatterOpts
---@return Cmd.FormattedLineOpts[]
function History.default_formatter(opts)
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

-- ============================================================================
-- SPINNER & PROGRESS MANAGEMENT
-- ============================================================================

---@private
---@class Cmd.SpinnerManager
local Spinner = {}

---Set spinner state for command
---@param command_id integer Command ID
---@param state Cmd.Spinner? Spinner state or nil to clear
function Spinner.set_state(command_id, state)
  if state then
    State.spinner_state[command_id] = vim.tbl_deep_extend("force", State.spinner_state[command_id] or {}, state)
  else
    State.spinner_state[command_id] = nil
  end
end

---Get spinner state for command
---@param command_id integer Command ID
---@return Cmd.Spinner? Current state or nil
function Spinner.get_state(command_id)
  return State.spinner_state[command_id]
end

---Create spinner driver for adapter
---@param adapter Cmd.Config.ProgressNotifier.SpinnerAdapter Notification adapter
---@return Cmd.SpinnerDriver Configured spinner driver
function Spinner.create_driver(adapter)
  return {
    ---Start the spinner animation and initial notification
    ---@param opts Cmd.Config.ProgressNotifier.Start Execution context and configuration
    start = function(opts)
      local timer = uv.new_timer()
      if not timer then
        Utils.notify("Failed to create spinner timer", "ERROR")
        return nil
      end

      local msg = string.format("[#%d] running `%s`", opts.command_id, opts.args)

      Spinner.set_state(opts.command_id, {
        timer = timer,
        active = true,
        msg = msg,
        title = "cmd.nvim",
        cmd = opts.args,
        start_time = os.time(),
      })

      local spinner_chars = State.config.progress_notifier.spinner_chars
      local idx = 1
      local notify_id = adapter.start(msg, opts)

      timer:start(0, 150, function()
        vim.schedule(function()
          local state = Spinner.get_state(opts.command_id)
          if not state or not state.active then
            return
          end

          local spinner_msg = state.msg
          if spinner_chars and #spinner_chars > 0 then
            idx = (idx % #spinner_chars) + 1
            spinner_msg = string.format("%s %s", spinner_chars[idx], state.msg)
            opts.current_spinner_char = spinner_chars[idx]
          end
          adapter.update(notify_id, spinner_msg, opts)
        end)
      end)

      return notify_id
    end,

    ---Stop spinner and show final execution result
    ---@param opts Cmd.Config.ProgressNotifier.Finish Post-execution context and results
    stop = function(opts)
      local state = Spinner.get_state(opts.command_id)
      if not state or not state.active then
        return
      end

      if state.timer and not state.timer:is_closing() then
        state.timer:stop()
        state.timer:close()
      end

      Spinner.set_state(opts.command_id, nil)

      local icon = icon_map[opts.status] or " "
      local level = level_map[opts.status] or vim.log.levels.ERROR
      local msg = string.format("%s [#%s] %s `%s`", icon, opts.command_id, opts.status, state.cmd)

      adapter.finish(opts.user_defined_notifier_id, msg, level, opts)
    end,
  }
end

-- Built-in spinner adapters
Spinner.builtin_adapters = {
  ---@type Cmd.Config.ProgressNotifier.SpinnerAdapter
  snacks = {
    start = function(msg, ctx)
      Utils.notify(msg, "INFO", { id = string.format("cmd_%d", ctx.command_id), title = "cmd.nvim" })
      return nil
    end,
    update = function(_, msg, ctx)
      Utils.notify(msg, "INFO", { id = string.format("cmd_%d", ctx.command_id), title = "cmd.nvim" })
    end,
    finish = function(_, msg, level, ctx)
      Utils.notify(msg, level, { id = string.format("cmd_%d", ctx.command_id), title = "cmd.nvim" })
    end,
  },

  ---@type Cmd.Config.ProgressNotifier.SpinnerAdapter
  mini = {
    start = function(msg)
      ---@diagnostic disable-next-line: redefined-local
      local ok, mini_notify = pcall(require, "mini.notify")
      return ok and mini_notify.add(msg, "INFO") or nil
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
        if data then
          data.msg = msg
          mini_notify.update(id, data)
        end
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
        if data then
          data.msg = msg
          data.level = level
          mini_notify.update(id, data)
          vim.defer_fn(function()
            mini_notify.remove(id)
          end, mini_notify.config.lsp_progress.duration_last)
        end
      end
    end,
  },

  ---@type Cmd.Config.ProgressNotifier.SpinnerAdapter
  fidget = {
    start = function(msg, ctx)
      ---@diagnostic disable-next-line: redefined-local
      local ok, fidget = pcall(require, "fidget")
      return ok
          and fidget.notification.notify(msg, "INFO", {
            key = string.format("cmd_%d", ctx.command_id),
            annote = "cmd.nvim",
            ttl = State.config.timeout,
          })
        or nil
    end,
    update = function(_, msg, ctx)
      ---@diagnostic disable-next-line: redefined-local
      local ok, fidget = pcall(require, "fidget")
      if ok then
        fidget.notification.notify(msg, "INFO", {
          key = string.format("cmd_%d", ctx.command_id),
          annote = "cmd.nvim",
          update_only = true,
        })
      end
    end,
    finish = function(_, msg, level, ctx)
      ---@diagnostic disable-next-line: redefined-local
      local ok, fidget = pcall(require, "fidget")
      if ok then
        fidget.notification.notify(msg, level, {
          key = string.format("cmd_%d", ctx.command_id),
          annote = "cmd.nvim",
          update_only = true,
          ttl = 0,
        })
      end
    end,
  },
}

-- ============================================================================
-- SHELL COMPLETION
-- ============================================================================

---@private
---@class Cmd.Completion
local Completion = {}

---Write temporary completion script for shell
---@param shell string Shell path
---@return string? Script path or nil on failure
function Completion.write_temp_script(shell)
  if State.temp_script_cache[shell] then
    return State.temp_script_cache[shell]
  end

  local path = vim.fn.tempname() .. ".sh"
  local content = ""

  -- TODO: fish is tested and working, but zsh and bash are not, come back later
  -- or somebody seeing this, please help me out
  if shell:find("fish") then
    content = [[
#!/usr/bin/env fish
set -l input "$argv"
complete -C "$input"
]]
  elseif shell:find("zsh") then
    content = [[
#!/usr/bin/env zsh
autoload -U compinit && compinit
autoload -U _command_names
input="$1"
_command_names "$input"
]]
  else -- bash
    content = [[
#!/usr/bin/env bash
# Optional: source bash-completion for extended completions
if [ -f /usr/share/bash-completion/bash_completion ]; then
  . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
  . /etc/bash_completion
fi
input="$1"
compgen -A command -- "$input"
]]
  end

  local fd = uv.fs_open(path, "w", 384) -- 0600 permissions
  if not fd then
    return nil
  end

  uv.fs_write(fd, content)
  uv.fs_close(fd)

  State.temp_script_cache[shell] = path
  return path
end

---Get shell completion candidates
---@param executable? string Executable name
---@param lead_args string Leading arguments
---@param cmd_line string Full command line
---@param cursor_pos integer Cursor position
---@return string[] Completion candidates
function Completion.get_candidates(executable, lead_args, cmd_line, cursor_pos)
  if not State.config.completion.enabled then
    return {}
  end

  Utils.ensure_cwd()

  -- Handle root Cmd call
  if not executable then
    local cmd_line_table = vim.split(cmd_line, " ")
    table.remove(cmd_line_table, 1)

    executable = cmd_line_table[1]

    cmd_line = table.concat(cmd_line_table, " ")
  end

  local shell = State.config.completion.shell

  --- validate shell whether it is executable
  if vim.fn.executable(shell) == 0 then
    Utils.notify(string.format("%s is not executable", shell), "ERROR")
    return {}
  end

  local script_path = Completion.write_temp_script(shell)
  if not script_path then
    Utils.notify("Failed to create completion script", "ERROR")
    return {}
  end

  -- Build completion line
  local full_line = cmd_line:sub(1, cursor_pos)

  local full_line_table = vim.split(full_line, " ")
  full_line_table[1] = executable
  full_line = table.concat(full_line_table, " ")

  local result = vim
    .system({ shell, script_path, full_line }, {
      text = true,
      cwd = State.cwd,
      timeout = 5000,
    })
    :wait()

  if result.code ~= 0 then
    return {}
  end

  local lines = vim.split(result.stdout, "\n")
  local completions = {}

  for _, line in ipairs(lines) do
    local cleaned = Utils.sanitize_line(line):gsub("\t.*", "")
    if cleaned ~= "" then
      table.insert(completions, cleaned)
    end
  end

  return completions
end

-- ============================================================================
-- UI COMPONENTS
-- ============================================================================

---@private
---@class Cmd.UI
local UI = {}

---Show command output in buffer
---@param lines string[] Output lines
---@param title string Buffer title
---@param post_hook? fun(buf: integer, lines: string[]) Optional callback after buffer creation
function UI.show_buffer(lines, title, post_hook)
  -- Clean up existing buffer
  local old_buf = vim.fn.bufnr(title)
  if old_buf ~= -1 then
    vim.api.nvim_buf_delete(old_buf, { force = true })
  end

  vim.schedule(function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Configure buffer
    vim.bo[buf].filetype = "cmd"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    vim.bo[buf].readonly = true
    vim.bo[buf].buflisted = false

    vim.api.nvim_buf_set_name(buf, title)
    vim.cmd("vsplit | buffer " .. buf)

    -- Add close keymap
    vim.keymap.set("n", "q", function()
      vim.cmd("close")
    end, { buffer = buf, nowait = true })

    if post_hook then
      post_hook(buf, lines)
    end
  end)
end

---Execute command in terminal
---@param cmd string[] Command arguments
---@param title string Terminal title
---@param command_id integer Command ID
function UI.show_terminal(cmd, title, command_id)
  History.track({
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

  -- Prepare command with environment
  local env_vars = Utils.get_cmd_env(cmd[1])
  local final_cmd = vim.deepcopy(cmd)
  if env_vars then
    final_cmd = vim.list_extend({ "env" }, vim.list_extend(env_vars, cmd))
  end

  -- Start spinner if adapter available
  local notify_id
  local adapter = State.config.progress_notifier.adapter
  if adapter then
    local driver = Spinner.create_driver(adapter)
    notify_id = driver.start({
      command_id = command_id,
      args_raw = cmd,
      args = table.concat(cmd, " "),
    })
  else
    Utils.notify(string.format("[#%d] running `%s`", command_id, table.concat(cmd, " ")), "INFO")
  end

  vim.fn.jobstart(final_cmd, {
    cwd = State.cwd,
    term = true,
    on_exit = function(_, exit_code)
      UI.refresh()

      local status = exit_code == 0 and "success" or (exit_code == 130 and "cancelled" or "failed")

      History.track({
        id = command_id,
        status = status,
        exit_code = exit_code,
      })

      -- Stop spinner or show notification
      if adapter then
        local driver = Spinner.create_driver(adapter)
        driver.stop({
          command_id = command_id,
          args_raw = cmd,
          args = table.concat(cmd, " "),
          status = status,
          user_defined_notifier_id = notify_id,
        })
      else
        local icon = icon_map[status] or " "
        local level = level_map[status] or vim.log.levels.ERROR

        local msg = string.format("%s [#%s] %s `%s`", icon, command_id, status, table.concat(cmd, " "))
        Utils.notify(msg, level)
      end

      -- Handle non-success cases
      if status == "cancelled" then
        vim.schedule(function()
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end)
      elseif status == "failed" then
        vim.schedule(function()
          local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
          lines = Utils.trim_empty_lines(lines)

          local preview = #lines <= 6 and table.concat(lines, "\n")
            or table.concat(vim.list_slice(lines, 1, 3), "\n")
              .. "\n...omitted...\n"
              .. table.concat(vim.list_slice(lines, #lines - 2, #lines), "\n")

          Utils.notify(string.format("`%s` exited %d\n%s", table.concat(cmd, " "), exit_code, preview), "ERROR")

          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end)
      end
    end,
  })

  vim.cmd("startinsert")
end

---Show command history in floating window
function UI.show_history()
  local history = History.get_all()
  if #history == 0 then
    Utils.notify("No command history", "INFO")
    return
  end

  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.6)

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

  -- Close keymaps
  local close = function()
    pcall(vim.api.nvim_win_close, win, true)
  end

  for _, key in ipairs({ "<Esc>", "q", "<C-c>" }) do
    vim.keymap.set("n", key, close, { buffer = buf, nowait = true })
  end

  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = close,
  })

  -- Format history lines
  ---@type string[]
  local lines = {}

  ---@type Cmd.FormattedLineOpts[][]
  local formatted_raw_data = {}

  local formatter = State.config.history_formatter_fn or History.default_formatter

  if type(formatter) ~= "function" then
    error("`opts.history_formatter_fn` must be a function")
    return
  end

  for i = #history, 1, -1 do
    local entry = history[i]

    local formatted = formatter({
      history = entry,
    })

    local formatted_line_data = Utils.parse_format_fn_result(formatted)
    local formatted_line = Utils.convert_parsed_format_result_to_string(formatted_line_data)

    table.insert(lines, formatted_line)
    table.insert(formatted_raw_data, formatted_line_data)
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local ns = vim.api.nvim_create_namespace("cmd_history")
  Utils.setup_virtual_text_hls(ns, buf, formatted_raw_data)

  vim.api.nvim_set_current_win(win)
end

---Refresh UI to reflect changes
function UI.refresh()
  vim.schedule(function()
    vim.cmd("redraw!")
    vim.cmd("checktime")
  end)
end

-- ============================================================================
-- COMMAND EXECUTION ENGINE
-- ============================================================================

---@private
---@class Cmd.Executor
local Executor = {}

---Execute CLI command asynchronously
---@param cmd string[] Command arguments
---@param command_id integer Command ID
---@param on_done function Completion callback
---@param timeout? integer Timeout in milliseconds
function Executor.exec_async(cmd, command_id, on_done, timeout)
  timeout = timeout or State.config.timeout
  Utils.ensure_cwd()

  local stdout, stderr = uv.new_pipe(false), uv.new_pipe(false)
  local out_chunks, err_chunks = {}, {}
  local done = false
  local timer

  local function finish(code, out, err, is_cancelled)
    if done then
      return
    end
    done = true

    -- Cleanup timer
    if timer and not timer:is_closing() then
      timer:stop()
      timer:close()
    end

    -- Cleanup pipes
    if stdout and not stdout:is_closing() then
      stdout:close()
    end
    if stderr and not stderr:is_closing() then
      stderr:close()
    end

    -- Clear job from history
    local history_entry = History.get(command_id)
    if history_entry then
      history_entry.job = nil
    end

    vim.schedule(function()
      on_done(code, out or "", err or "", is_cancelled)
    end)
  end

  -- Spawn process
  local process = uv.spawn(cmd[1], {
    args = vim.list_slice(cmd, 2),
    cwd = State.cwd,
    stdio = { nil, stdout, stderr },
    env = nil,
    uid = nil,
    gid = nil,
    verbatim = nil,
    detached = nil,
    hide = nil,
  }, function(code, signal)
    -- Handle signals
    if signal == 2 then
      code = 130
    end -- SIGINT
    if signal == 15 then
      code = 143
    end -- SIGTERM
    if signal == 9 then
      code = 137
    end -- SIGKILL

    finish(code, Utils.stream_to_string(out_chunks), Utils.stream_to_string(err_chunks), code == 130)
  end)

  if not process then
    on_done(127, "", string.format("Failed to spawn process: %s", cmd[1]), false)
    return
  end

  -- Store process handle
  History.track({ id = command_id, job = process })

  -- Setup stream reading
  if stdout then
    Utils.read_stream(stdout, out_chunks)
  end
  if stderr then
    Utils.read_stream(stderr, err_chunks)
  end

  -- Setup timeout
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
        finish(124, "", string.format("Command timed out after %dms: %s", timeout, cmd[1]), false)
      end)
    end
  end
end

---Cancel running command with graceful shutdown
---@param command_id integer Command ID
function Executor.cancel(command_id)
  local entry = History.get(command_id)
  if not entry or not entry.job or entry.job:is_closing() then
    return false, "No running command to cancel"
  end

  entry.job:kill("sigint")
  -- Escalate to SIGKILL after 1 second
  vim.defer_fn(function()
    if entry.job and not entry.job:is_closing() then
      entry.job:kill("sigkill")
    end
  end, 1000)

  History.track({ id = command_id, status = "cancelled" })
  return true, "Command cancelled"
end

---Check if executable should force terminal mode
---@param executable string Executable name
---@param args string[] Command arguments
---@return boolean Should force terminal
function Executor.should_force_terminal(executable, args)
  local patterns = State.config.force_terminal[executable]
  if not patterns or vim.tbl_isempty(patterns) then
    return false
  end

  local args_string = table.concat(args, " ")
  for _, pattern in ipairs(patterns) do
    if args_string:find(pattern, 1, true) then
      return true
    end
  end

  return false
end

---Run command in appropriate mode
---@param args string[] Command arguments
---@param force_terminal? boolean Force terminal execution
function Executor.run(args, force_terminal)
  local executable = args[1]

  -- Validate executable
  if vim.fn.executable(executable) == 0 then
    Utils.notify(string.format("%s is not executable", executable), "ERROR")
    return
  end

  local command_id = History.get_next_id()

  -- Check if should force terminal
  if not force_terminal then
    force_terminal = Executor.should_force_terminal(executable, args)
  end

  if force_terminal then
    UI.show_terminal(args, "cmd://" .. table.concat(args, " "), command_id)
  else
    -- Run in buffer mode
    History.track({
      id = command_id,
      cmd = args,
      type = "normal",
      status = "running",
    })

    -- Start spinner/notification
    local notify_id
    local adapter = State.config.progress_notifier.adapter
    if adapter then
      local driver = Spinner.create_driver(adapter)
      notify_id = driver.start({
        command_id = command_id,
        args_raw = args,
        args = table.concat(args, " "),
      })
    else
      Utils.notify(string.format("[#%d] running `%s`", command_id, table.concat(args, " ")), "INFO")
    end

    Executor.exec_async(args, command_id, function(code, out, err, is_cancelled)
      local status = is_cancelled and "cancelled" or (code == 0 and "success" or "failed")

      History.track({
        id = command_id,
        status = status,
        exit_code = code,
      })

      -- Stop spinner or show notification
      if adapter then
        local driver = Spinner.create_driver(adapter)
        driver.stop({
          command_id = command_id,
          args_raw = args,
          args = table.concat(args, " "),
          status = status,
          user_defined_notifier_id = notify_id,
        })
      else
        local status_icons = { success = "✓", failed = "✗", cancelled = "⚠" }
        local icon = status_icons[status] or "?"
        local level = status == "success" and "INFO" or (status == "cancelled" and "WARN" or "ERROR")
        Utils.notify(string.format("%s [#%d] %s `%s`", icon, command_id, status, table.concat(args, " ")), level)
      end

      if not is_cancelled then
        local combined_output = table.concat(Utils.trim_empty_lines({ err, out }), "\n")
        local lines = vim.split(combined_output, "\n")
        lines = Utils.trim_empty_lines(lines)

        -- Strip ANSI escape codes
        for i, line in ipairs(lines) do
          lines[i] = line:gsub("\27%[[0-9;]*m", "")
        end

        if #lines > 0 then
          UI.show_buffer(lines, "cmd://" .. table.concat(args, " ") .. "-" .. command_id)
        else
          Utils.notify("Command completed with no output", "INFO")
        end

        if status == "success" then
          UI.refresh()
        end
      end
    end)
  end
end

-- ============================================================================
-- USER COMMANDS SETUP
-- ============================================================================

---@private
---@class Cmd.Commands
local Commands = {}

---Setup all user commands
function Commands.setup()
  Commands.setup_main_command()
  Commands.setup_rerun_command()
  Commands.setup_cancel_command()
  Commands.setup_history_command()
  Commands.setup_auto_commands()
end

---Setup main :Cmd command
function Commands.setup_main_command()
  vim.api.nvim_create_user_command("Cmd", function(opts)
    local args = vim.deepcopy(opts.fargs)

    -- Expand arguments (e.g., % to current file)
    for i, arg in ipairs(args) do
      args[i] = vim.fn.expand(arg)
    end

    if #args == 0 then
      Utils.notify("No arguments provided", "WARN")
      return
    end

    Executor.run(args, opts.bang)
  end, {
    nargs = "*",
    bang = true,
    complete = function(...)
      return Completion.get_candidates(nil, ...)
    end,
    desc = "Execute CLI command (! for terminal mode)",
  })
end

---Setup :CmdRerun command
function Commands.setup_rerun_command()
  vim.api.nvim_create_user_command("CmdRerun", function(opts)
    local id = tonumber(opts.args) or #State.command_history
    local entry = History.get(id)

    if not entry or not entry.cmd then
      Utils.notify("No command found to rerun", "WARN")
      return
    end

    Executor.run(entry.cmd, opts.bang)
  end, {
    nargs = "?",
    bang = true,
    desc = "Rerun command from history (! for terminal mode)",
  })
end

---Setup :CmdCancel command
function Commands.setup_cancel_command()
  vim.api.nvim_create_user_command("CmdCancel", function(opts)
    if opts.bang then
      -- Cancel all running commands
      local cancelled = 0
      for _, entry in pairs(State.command_history) do
        if entry.job and not entry.job:is_closing() then
          local success = Executor.cancel(entry.id)
          if success then
            cancelled = cancelled + 1
          end
        end
      end
      Utils.notify(string.format("Cancelled %d running commands", cancelled), "INFO")
    else
      -- Cancel specific or last command
      local id = tonumber(opts.args) or #State.command_history
      local success, msg = Executor.cancel(id)
      Utils.notify(msg, success and "INFO" or "WARN")
    end
  end, {
    nargs = "?",
    bang = true,
    desc = "Cancel running command (! to cancel all)",
  })
end

---Setup :CmdHistory command
function Commands.setup_history_command()
  vim.api.nvim_create_user_command("CmdHistory", function()
    UI.show_history()
  end, {
    desc = "Show command history",
  })
end

---Setup auto-created user commands for configured executables
function Commands.setup_auto_commands()
  local existing_cmds = vim.api.nvim_get_commands({})

  for executable, cmd_name in pairs(State.config.create_usercmd or {}) do
    if vim.fn.executable(executable) == 1 and not existing_cmds[cmd_name] then
      vim.api.nvim_create_user_command(cmd_name, function(opts)
        local args = vim.deepcopy(opts.fargs)

        -- Expand arguments
        for i, arg in ipairs(args) do
          args[i] = vim.fn.expand(arg)
        end

        local full_args = vim.list_extend({ executable }, args)
        local force_terminal = opts.bang or Executor.should_force_terminal(executable, full_args)

        Executor.run(full_args, force_terminal)
      end, {
        nargs = "*",
        bang = true,
        complete = function(...)
          return Completion.get_candidates(executable, ...)
        end,
        desc = string.format("Auto-generated command for %s", executable),
      })
    end
  end
end

-- ============================================================================
-- AUTOCMDS & CLEANUP
-- ============================================================================

---Setup autocmds for cleanup and resource management
local function setup_autocmds()
  local group = vim.api.nvim_create_augroup("CmdNvim", { clear = true })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      -- Stop all spinner timers
      for _, state in pairs(State.spinner_state) do
        if state.timer and not state.timer:is_closing() then
          state.timer:stop()
          state.timer:close()
        end
      end

      -- Clean up temporary completion scripts
      for _, path in pairs(State.temp_script_cache) do
        Utils.safe_delete(path)
      end

      -- Kill any remaining processes
      for _, entry in pairs(State.command_history) do
        if entry.job and not entry.job:is_closing() then
          entry.job:kill("sigterm")
        end
      end
    end,
  })
end

-- ============================================================================
-- HIGHLIGHT GROUPS
-- ============================================================================

---Setup default highlight groups
local function setup_highlights()
  local highlights = {
    CmdHistoryNormal = { link = "NormalFloat", default = true },
    CmdHistoryBorder = { link = "FloatBorder", default = true },
    CmdHistoryTitle = { link = "FloatTitle", default = true },
    CmdHistoryIdentifier = { link = "Identifier", default = true },
    CmdHistoryTime = { link = "Comment", default = true },
    CmdSuccess = { link = "MoreMsg", default = true },
    CmdFailed = { link = "ErrorMsg", default = true },
    CmdCancelled = { link = "WarningMsg", default = true },
  }

  for name, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

-- ============================================================================
-- HEALTH CHECK
-- ============================================================================

---@private
---Health check for :checkhealth
function M.check()
  if not setup_complete then
    vim.health.error("cmd.nvim not setup", "Run require('cmd').setup()")
    return
  end

  vim.health.start("cmd.nvim")

  -- Check environment
  if uv then
    vim.health.ok("libuv available")
  else
    vim.health.error("libuv not available")
  end

  -- Check shell
  local shell = State.config.completion.shell
  if vim.fn.executable(shell) == 1 then
    vim.health.ok("Shell executable: " .. shell)
  else
    vim.health.warn("Shell not executable: " .. shell)
  end

  -- Check optional dependencies
  local deps = {
    { "snacks.nvim", "snacks" },
    { "mini.notify", "mini.notify" },
    { "fidget.nvim", "fidget" },
  }

  for _, dep in ipairs(deps) do
    local name, module = dep[1], dep[2]
    ---@diagnostic disable-next-line: redefined-local
    local ok = pcall(require, module)
    if ok then
      vim.health.ok(name .. " available")
    else
      vim.health.info(name .. " not available (optional)")
    end
  end

  -- Check configuration
  local issues = {}
  if State.config.timeout <= 0 then
    table.insert(issues, "timeout should be positive")
  end

  if #issues > 0 then
    for _, issue in ipairs(issues) do
      vim.health.warn("Configuration: " .. issue)
    end
  else
    vim.health.ok("Configuration valid")
  end
end

-- ============================================================================
-- PUBLIC API & SETUP
-- ============================================================================

---@mod cmd.public Public API

-- Default history formatter (set here to avoid circular dependency)
DEFAULT_CONFIG.history_formatter_fn = History.default_formatter

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
---     progress_notifier = {
---       adapter = require('cmd').builtins.spinner_adapters.snacks
---     }
---   })
---@usage ]]
function M.setup(user_config)
  if setup_complete then
    Utils.notify("cmd.nvim already setup", "WARN")
    return
  end

  -- Validate and merge configuration
  local config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, user_config or {})
  local valid, err = validate_config(config)
  if not valid then
    error("cmd.nvim: Invalid configuration: " .. err)
  end

  State.config = config

  -- Initialize systems
  init_state()
  setup_highlights()
  setup_autocmds()
  Commands.setup()

  -- Expose public configuration
  M.config = vim.deepcopy(State.config)

  setup_complete = true
end

-- ============================================================================
-- PUBLIC BUILT-INS
-- ============================================================================

---@tag Cmd.builtins

---Built-in utilities and notification adapters.
---
---Provides pre-built notification adapters for popular plugins and utilities
---for creating custom notification implementations.
---
---@type Cmd.Builtins
---@usage [[
---   -- Use built-in snacks.nvim adapter
---   require('cmd').setup({
---     progress_notifier = {
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
---   require('cmd').setup({
---     progress_notifier = {
---       adapter = custom_adapter
---     }
---   })
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
M.builtins = {
  spinner_adapters = Spinner.builtin_adapters,
  formatters = {
    default_history = History.default_formatter,
  },
}

-- ============================================================================
-- DEVELOPMENT API
-- ============================================================================

---@private
---Internal API for development and testing
M._internal = {
  state = function()
    return State
  end,
  utils = Utils,
  history = History,
  spinner = Spinner,
  completion = Completion,
  ui = UI,
  executor = Executor,
  commands = Commands,
}

return M
