# dotfiles
<img width="1508" height="950" alt="image" src="https://github.com/user-attachments/assets/902fbb39-93f6-46f6-a533-0ad169b13c87" />

Personal configs for shell, editor, prompt, and terminal, plus a Homebrew
package list — set up so a fresh machine can be brought up in one command.

Everything ends up symlinked under `~/.config`, matching the
[XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)
layout each tool already supports natively — no extra manual linking, env
vars, or config-path flags needed after the installer runs.

| File / dir | Tool | Symlinked to |
|---|---|---|
| [.gitconfig](.gitconfig) | Git | `~/.config/git/config` |
| [.zshenv](.zshenv) | Zsh | `~/.zshenv` (see [note](#the-one-file-outside-config) below) |
| [.zshrc](.zshrc) | Zsh | `~/.config/zsh/.zshrc` |
| [Brewfile](Brewfile) | Homebrew Bundle | — (installed, not linked) |
| [starship.toml](starship.toml) | [Starship](https://starship.rs) prompt | `~/.config/starship.toml` |
| [wezterm/wezterm.lua](wezterm/wezterm.lua) | [WezTerm](https://wezfurlong.org/wezterm/) | `~/.config/wezterm/wezterm.lua` |
| [nvim/](nvim) | Neovim ([LazyVim](https://lazyvim.github.io)) | `~/.config/nvim` |

On Windows, `~/.config` means `%USERPROFILE%\.config` — the installer
persists `XDG_CONFIG_HOME` so nvim and WezTerm (which don't check
`~/.config` there by default) pick it up automatically.

#### The one file outside `.config`

`~/.zshenv` is the single unavoidable exception. Zsh reads it before it knows
about any other config path, so it can't itself live under `~/.config` — its
only job is one line, `export ZDOTDIR="$HOME/.config/zsh"`, which redirects
everything else zsh loads (`.zshrc`, etc.) into `~/.config/zsh`.

## Quick start

Clone the repo, then run the installer for your platform.

### macOS / Linux

```sh
git clone https://github.com/NavPilDev/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

This installs [Homebrew](https://brew.sh) if it's missing, runs
`brew bundle` against [Brewfile](Brewfile), and symlinks every config above
into place (existing files are backed up, not overwritten — see
[What the scripts do](#what-the-scripts-do)).

On Linux, Homebrew casks and the `vscode "..."` extension lines in
[Brewfile](Brewfile) are macOS-only and get skipped automatically; everything
else (formulae, taps, npm globals) installs the same way via Linuxbrew.

### Windows

Open **PowerShell** — not Command Prompt; `$env:USERPROFILE` below is
PowerShell-only syntax and cmd.exe will create a folder literally named
`$env:USERPROFILE` instead of expanding it — **as Administrator** (needed to
create symlinks — or enable Developer Mode instead, see below) and run:

```powershell
git clone https://github.com/NavPilDev/dotfiles.git $env:USERPROFILE\.dotfiles
cd $env:USERPROFILE\.dotfiles
.\install.ps1
```

Or double-click [install.bat](install.bat), which just calls `install.ps1`
for you.

`install.ps1` installs the closest [winget](https://learn.microsoft.com/windows/package-manager/winget/)
equivalents of the Brewfile tools, and symlinks nvim, starship, wezterm, and
git config. It does **not** set up `.zshrc` or the zsh plugins/tmux from
Brewfile, since those are POSIX-shell only — use WSL (below) if you want the
full setup on Windows.

### Windows via WSL (recommended if you want the whole setup)

If you want zsh, tmux, and the rest of the shell environment on Windows too,
install WSL and run the Linux path inside it:

```powershell
wsl --install
```

Then inside the WSL shell:

```sh
git clone https://github.com/NavPilDev/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

## What the scripts do

Both installers print an overall progress bar (`install.sh`: a step counter
in the terminal; `install.ps1`: a native PowerShell progress bar, plus a
nested one for the winget package loop) so you can tell where setup is at
without reading through the package-manager output.

Both installers are idempotent and safe to re-run:

- Any **legacy** config still sitting at the old, non-XDG path
  (`~/.gitconfig`, `~/.zshrc`, `~/.wezterm.lua`, `%LOCALAPPDATA%\nvim`) is
  moved out of the way first — otherwise git/zsh would keep reading the
  stale `$HOME`-level file instead of the one under `~/.config`.
- Anything already at a target path that **isn't** already the correct
  symlink gets moved to a timestamped backup folder
  (`~/.dotfiles-backup/<timestamp>/` on macOS/Linux,
  `%USERPROFILE%\.dotfiles-backup\<timestamp>\` on Windows) before the new
  symlink is created — nothing is ever deleted outright.
- Package installs use `brew bundle` (macOS/Linux) or `winget install`
  (Windows), both of which no-op on already-installed packages.
- Failures for one package/extension (e.g. VS Code not yet on `PATH` for the
  `vscode "..."` extension lines) print a warning and don't abort the whole
  run — fix the prerequisite and re-run the script.

| Script | Platform | Installs packages via | Symlinks into `~/.config` |
|---|---|---|---|
| [install.sh](install.sh) | macOS, Linux | Homebrew (`brew bundle`) | `git/config`, `zsh/.zshrc` (+ `~/.zshenv`), `starship.toml`, `wezterm/wezterm.lua`, `nvim/` |
| [install.ps1](install.ps1) | Windows | winget | `git/config`, `starship.toml`, `wezterm/wezterm.lua`, `nvim/` (also persists `XDG_CONFIG_HOME`) |
| [install.bat](install.bat) | Windows | — (wraps `install.ps1`) | — |

## Manual steps after installing

Config sync itself needs nothing further — the two items below are outside
that scope (changing your login shell needs your password; VS Code isn't
managed by the installer at all):

- **Shell**: on macOS/Linux, if zsh isn't already your login shell,
  `install.sh` will print the `chsh -s $(command -v zsh)` command to run
  (not automated, since `chsh` prompts for your password).
- **VS Code extensions**: only install if the `code` CLI is on your `PATH`.
  In VS Code, run `Shell Command: Install 'code' command in PATH` from the
  Command Palette, then re-run the installer.

Everything else is genuinely automatic on next launch:

- **Font**: WezTerm's font is set in [wezterm.lua](wezterm/wezterm.lua)
  itself, and the Nerd Font it names is installed by `Brewfile`/`install.ps1`
  — nothing to configure. Only if you also use a *different* terminal would
  you need to pick the font there manually.
- **Neovim plugins**: first launch of `nvim` bootstraps
  [lazy.nvim](https://github.com/folke/lazy.nvim) and installs plugins from
  [nvim/lazy-lock.json](nvim/lazy-lock.json) automatically.

## Updating

```sh
cd ~/.dotfiles
git pull
./install.sh   # or install.ps1 on Windows — safe to re-run anytime
```

Since configs are symlinked (not copied), editing a file in `~/.dotfiles`
takes effect immediately — no re-linking needed. Re-running the installer is
only necessary to pick up new symlinks or new Brewfile packages.
