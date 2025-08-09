# 🚀 cmd.nvim

> Execute CLI commands seamlessly in Neovim with async execution, progress notifications, and smart completion

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Neovim](https://img.shields.io/badge/Neovim-0.10+-green.svg)](https://neovim.io)

cmd.nvim transforms how you interact with command-line tools inside Neovim. Whether you're running git commands, build scripts, or system utilities, cmd.nvim provides a unified interface with beautiful progress indicators, shell completion, and intelligent output handling.

<https://github.com/user-attachments/assets/ec286e66-816a-4a19-8814-ebd9ad7974a3>

> [!NOTE]
> Note that the notifier in the demo is my custom notifier, not a built in one.

> [!WARNING]
> This plugin might not cover all edges and use cases, but it covers all my needs at this moment. Feel free to send in
> PRs instead of asking for fix or issue reports.

## ✨ Features

- **🔄 Async Execution** - Run commands without blocking Neovim
- **📊 Progress Notifications** - Beautiful spinners and progress indicators (snacks.nvim, mini.notify, fidget.nvim or
  custom)
- **🔍 Shell Completion** - Native shell completion for any command (your shell must support it, only for `fish` now,
  need help please!)
- **📜 Command History** - Track and rerun previous commands
- **🖥️ Dual Output Modes** - Buffer output or terminal execution
- **⚙️ Environment Control** - Per-executable environment variables
- **⏰ Timeout Management** - Configurable timeouts with graceful cancellation
- **🎯 Smart Terminal Detection** - Auto-detect commands that need terminal mode

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "y3owk1n/cmd.nvim",
  config = function()
    require("cmd").setup()
  end,
}
```

## 🆚 Why cmd.nvim?

### vs Native Neovim Commands

| Feature                 | `:!command`        | `:terminal`      | `:make`          | **cmd.nvim**              |
| ----------------------- | ------------------ | ---------------- | ---------------- | ------------------------- |
| **Async execution**     | ❌ Blocks UI       | ✅ Yes           | ❌ Blocks UI     | ✅ **Non-blocking**       |
| **Output handling**     | 📄 Basic display   | 🖥️ Terminal only | 📋 Quickfix only | 📊 **Buffer + Terminal**  |
| **Progress feedback**   | ❌ None            | ❌ None          | ⏳ Basic         | 🎯 **Rich notifications** |
| **Shell completion**    | ❌ None            | ❌ None          | ❌ None          | ✅ **Full completion**    |
| **Command history**     | ❌ None            | ❌ None          | ❌ None          | 📜 **Persistent history** |
| **Cancellation**        | ❌ Ctrl+C only     | ✅ Yes           | ❌ Ctrl+C only   | 🛑 **Graceful + Force**   |
| **Environment control** | ❌ None            | ❌ Limited       | ❌ Limited       | ⚙️ **Per-executable**     |
| **Multiple commands**   | ❌ Sequential only | 🔀 Manual        | ❌ Sequential    | 🚀 **Concurrent**         |

#### **Real-world comparison:**

<details>
<summary><b>📊 Native Neovim vs cmd.nvim</b></summary>

**Running `git status` with native commands:**

```vim
:!git status                 " Blocks UI, basic output, hard to copy text
:terminal git status         " New terminal buffer, but not really needed if running non interactive commands
```

**Running `git status` with cmd.nvim:**

```vim
:Cmd git status             " Async, rich output, tracked in history
                            " Auto-completion, progress indicator
                            " Proper error handling, cancellable
```

**Long-running commands:**

```vim
" Native - blocks Neovim completely
:!npm install

" cmd.nvim - work continues, progress shown
:Cmd npm install            " See progress spinner, cancel if needed
```

**Multiple commands:**

```vim
" Native - must wait for each
:!git fetch
:!npm test
:!docker build .

" cmd.nvim - run concurrently
:Cmd git fetch
:Cmd npm test
:Cmd docker build .         " All run async with individual progress
```

</details>

## 🚀 Quick Start

```lua
-- Minimal setup
require("cmd").setup()
```

Now you can use the `:Cmd` command:

```vim
:Cmd git status              " Run in buffer with output
:Cmd! git log --oneline      " Run in terminal (interactive)
:Cmd ls -la %:h             " List current file's directory
```

## ⚙️ Configuration

<details>
<summary><b>🎛️ Full Configuration Options</b></summary>

```lua
require("cmd").setup({
  -- Force terminal execution for specific command patterns
  force_terminal = {
    git = { "push", "pull", "fetch", "rebase" },
    npm = { "run", "start" },
    docker = { "run", "exec" },
  },

  -- Auto-create user commands for executables
  -- and you can use them without :Cmd
  create_usercmd = {
    git = "Git",       -- Creates :Git command
    npm = "Npm",       -- Creates :Npm command
    docker = "Docker", -- Creates :Docker command
  },

  -- Environment variables per executable
  env = {
    node = { "NODE_ENV=development" },
    python = { "PYTHONPATH=/custom/path" },
    go = { "GOOS=linux", "GOARCH=amd64" },
  },

  -- Command timeout (milliseconds)
  timeout = 30000,

  -- Shell completion configuration
  completion = {
    enabled = true,
    shell = "/bin/fish", -- or "/bin/bash", "/bin/zsh" (Note that bash and fish are not yet be supported, please help!)
    prompt_pattern_to_remove = "^%$ ", -- Remove shell prompt
  },

  -- Progress notifications
  async_notifier = {
    spinner_chars = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
    adapter = require("cmd").builtins.spinner_adapters.snacks,
  },

  -- Custom history formatter
  history_formatter_fn = function(opts)
    local entry = opts.history
    return {
      {
        display_text = "Something",
        hl_group = "CmdHistoryIdentifier", -- optional
        is_virtual = true, -- should it be virtual text or not?
      },
    }
  end
})
```

</details>

> [!WARNING] > `bash` and `fish` are not yet supported for autocomplete, as I don't have them configured on my machine...
> Whovere are good with this and are using these shells, please help me out to make the completion work for them ~

### 🔌 Notification Adapters

cmd.nvim works seamlessly with popular notification plugins:

### [snacks.nvim](https://github.com/folke/snacks.nvim)

```lua
async_notifier = {
  adapter = require("cmd").builtins.spinner_adapters.snacks,
}
```

### [mini.notify](https://github.com/echasnovski/mini.notify)

```lua
async_notifier = {
  adapter = require("cmd").builtins.spinner_adapters.mini,
}
```

### [fidget.nvim](https://github.com/j-hui/fidget.nvim)

```lua
async_notifier = {
  adapter = require("cmd").builtins.spinner_adapters.fidget,
}
```

### Custom Adapter

You can also create your own adapter by the following sample:

```lua
async_notifier = {
  adapter = {
    start = function(msg, data)
      return vim.notify(msg, vim.log.levels.INFO, { title = "cmd" })
    end,
    update = function(id, msg, data)
      vim.notify(msg, vim.log.levels.INFO, { replace = id })
    end,
    finish = function(id, msg, level, data)
      vim.notify(msg, vim.log.levels[level], { replace = id })
    end,
  }
}
```

I am currently using my custom notifier, and here's how i do it:

```lua
async_notifier = {
  adapter = {
    start = function(_, data)
      vim.notify("", vim.log.levels.INFO, {
        id = string.format("cmd_progress_%s", data.command_id),
        title = "cmd",
        group_name = "bottom-left",
        icon = " ",
        _notif_formatter = function(opts)
          local notif = opts.notif
          local _notif_formatter_data = notif._notif_formatter_data

          if not _notif_formatter_data then
            return {}
          end

          local separator = { display_text = " " }

          local icon = notif.icon or opts.config.icons[notif.level]
          local icon_hl = notif.hl_group or opts.log_level_map[notif.level].hl_group

          local id_text = string.format("#%s", _notif_formatter_data.command_id)

          return {
            icon and { display_text = icon, hl_group = icon_hl },
            icon and separator,
            { display_text = id_text, hl_group = "CmdHistoryIdentifier" },
            separator,
            { display_text = "running", hl_group = icon_hl },
            separator,
            { display_text = _notif_formatter_data.args, hl_group = "Comment" },
          }
        end,
        _notif_formatter_data = data,
      })
      return nil -- no need to return ID, as my custom notifier updates by `opts.id`
    end,

    update = function(_, _, data)
      vim.notify("", vim.log.levels.INFO, {
        id = string.format("cmd_progress_%s", data.command_id),
        title = "cmd",
        group_name = "bottom-left",
        icon = data.current_spinner_char,
        _notif_formatter = function(opts)
          local notif = opts.notif
          local _notif_formatter_data = notif._notif_formatter_data

          if not _notif_formatter_data then
            return {}
          end

          local separator = { display_text = " " }

          local icon = notif.icon or opts.config.icons[notif.level]
          local icon_hl = notif.hl_group or opts.log_level_map[notif.level].hl_group

          local id_text = string.format("#%s", _notif_formatter_data.command_id)

          return {
            icon and { display_text = icon, hl_group = icon_hl },
            icon and separator,
            { display_text = id_text, hl_group = "CmdHistoryIdentifier" },
            separator,
            { display_text = "running", hl_group = icon_hl },
            separator,
            { display_text = _notif_formatter_data.args, hl_group = "Comment" },
          }
        end,
        _notif_formatter_data = data,
      })
    end,

    finish = function(_, _, level, data)
      ---@type table<Cmd.CommandStatus, string>
      local icon_map = {
        success = " ",
        failed = " ",
        cancelled = " ",
      }

      local icon = icon_map[data.status]

      vim.notify("", vim.log.levels[level], {
        id = string.format("cmd_progress_%s", data.command_id),
        title = "cmd",
        group_name = "bottom-left",
        icon = icon,
        _notif_formatter = function(opts)
          local notif = opts.notif
          local _notif_formatter_data = notif._notif_formatter_data

          if not _notif_formatter_data then
            return {}
          end

          local separator = { display_text = " " }

          local _icon = notif.icon or opts.config.icons[notif.level]
          local icon_hl = notif.hl_group or opts.log_level_map[notif.level].hl_group

          local id_text = string.format("#%s", _notif_formatter_data.command_id)

          return {
            icon and { display_text = _icon, hl_group = icon_hl },
            icon and separator,
            { display_text = id_text, hl_group = "CmdHistoryIdentifier" },
            separator,
            { display_text = _notif_formatter_data.status, hl_group = icon_hl },
            separator,
            { display_text = _notif_formatter_data.args, hl_group = "Comment" },
          }
        end,
        _notif_formatter_data = data,
      })
    end,
  },
},
```

## 📚 Usage

### Commands

| Command           | Description                    | Example                   |
| ----------------- | ------------------------------ | ------------------------- |
| `:Cmd <command>`  | Run command in buffer          | `:Cmd git status`         |
| `:Cmd! <command>` | Run command in terminal        | `:Cmd! git log --oneline` |
| `:CmdRerun [id]`  | Rerun last or specific command | `:CmdRerun 5`             |
| `:CmdCancel [id]` | Cancel running command(s)      | `:CmdCancel!` (all)       |
| `:CmdHistory`     | Show command history           | `:CmdHistory`             |

### Examples

<details>
<summary><b>📋 Common Usage Patterns</b></summary>

```vim
" Git workflows
:Cmd git status -s
:Cmd git add .
:Cmd! git add -p
:Cmd! git commit
:Cmd git push

" Github workflows
:Cmd gh pr create
:Cmd gh pr merge
:Cmd! gh pr checks --watch

" Development
:Cmd npm test
:Cmd! npm run dev
:Cmd docker ps
:Cmd! docker exec -it mycontainer bash
:Cmd just --list

" System administration
:Cmd ls -la
:Cmd! htop

" File operations with current buffer
:Cmd ls %:h
:Cmd cat %
```

</details>

### 🎯 Smart Features

#### Auto-completion

> [!WARNING]
> Only `fish` shell is supported, as that's my shell, please help me out to make it work for `bash` and `zsh` ~

Enable shell completion to get native command-line completion inside Neovim:

```lua
completion = {
  enabled = true,
  shell = "/bin/fish", -- Your preferred shell
}
```

#### Command History

Track all your commands with timestamps and status:

```vim
:CmdHistory
```

#### Cancellation

Cancel long-running commands gracefully:

```vim
:CmdCancel     " Cancel last command
:CmdCancel 3   " Cancel command #3
:CmdCancel!    " Cancel all running commands
```

## 🎨 Customization

### Highlight Groups

Customize the appearance by modifying these highlight groups:

```vim
hi CmdSuccess   guifg=#50fa7b  " Successful commands (default: links to MoreMsg)
hi CmdFailed    guifg=#ff5555  " Failed commands (default: links to ErrorMsg)
hi CmdCancelled guifg=#f1fa8c  " Cancelled commands (default: links to WarningMsg)
```

### Key Mappings

Create convenient mappings for common workflows:

```lua
-- Quick git commands
vim.keymap.set("n", "<leader>gs", ":Cmd git status<CR>")
vim.keymap.set("n", "<leader>ga", ":Cmd git add .<CR>")
vim.keymap.set("n", "<leader>gc", ":Cmd! git commit<CR>")
vim.keymap.set("n", "<leader>gp", ":Cmd git push<CR>")

-- Development commands
vim.keymap.set("n", "<leader>tt", ":Cmd npm test<CR>")
vim.keymap.set("n", "<leader>td", ":Cmd! npm run dev<CR>")

-- Command management
vim.keymap.set("n", "<leader>ch", ":CmdHistory<CR>")
vim.keymap.set("n", "<leader>cc", ":CmdCancel<CR>")
```

## 🔧 Advanced Usage

### Environment Variables

Set different environments for different tools:

```lua
env = {
  -- Node.js development
  node = {
    "NODE_ENV=development",
    "DEBUG=app:*"
  },

  -- Python with custom paths
  python = {
    "PYTHONPATH=/custom/modules:/another/path",
    "PYTHONDONTWRITEBYTECODE=1"
  },

  -- Docker with specific configs
  docker = {
    "DOCKER_BUILDKIT=1",
    "COMPOSE_DOCKER_CLI_BUILD=1"
  },
}
```

### Terminal Force Patterns

Automatically run certain commands in terminal mode:

```lua
force_terminal = {
  git = { "rebase", "merge", "commit --amend" },
}
```

### Auto-Generated Commands

Create user commands automatically:

```lua
create_usercmd = {
  git = "Git", -- :Git
  docker = "Docker", -- :Docker
  kubectl = "K",  -- :K
  npm = "Npm", -- :Npm
}
```

This creates commands like `:Git status`, `:Docker ps`, `:K get pods`, etc.

## 🐛 Troubleshooting

<details>
<summary><b>Common Issues</b></summary>

### Commands not completing

- Ensure `completion.enabled = true`
- Check that your shell supports completion the completion
- Verify shell path in `completion.shell`
- Currently, bash and zsh are not supported for autocomplete, as I don't have them configured on my machine... Please
  help ~

### Terminal commands not working

- Check if the command is in your PATH
- Try running with full path: `:Cmd /usr/bin/git status`

### No notifications progress

- Ensure that you have enabled `opts.async_notifier.adapter` in your config, if not it will just do one single `vim.notify` for start and end
- Ensure you have a compatible notification plugin installed
- Check adapter configuration
- Try the default adapter first

### Timeout issues

- Increase `timeout` value for long-running commands
- Use `:Cmd!` for interactive commands
- Cancel with `:CmdCancel` if needed

### "Why not just use `:!`?"

- `:!` blocks your entire editor - you can't do anything else
- No progress feedback for long commands
- No history tracking or rerun capabilities
- No shell completion
- Limited output handling options

### "What about `:terminal`?"

- Terminal is great for interactive shells, cmd.nvim is for running specific commands

</details>

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.
