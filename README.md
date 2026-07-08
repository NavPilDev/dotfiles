# dotfiles
<img width="1508" height="950" alt="image" src="https://github.com/user-attachments/assets/902fbb39-93f6-46f6-a533-0ad169b13c87" />

Personal configs for shell, editor, prompt, and terminal, plus a Homebrew
package list — set up so a fresh machine can be brought up in one command.

| File / dir | Tool | Symlinked to |
|---|---|---|
| [.gitconfig](.gitconfig) | Git | `~/.gitconfig` |
| [.zshrc](.zshrc) | Zsh | `~/.zshrc` |
| [Brewfile](Brewfile) | Homebrew Bundle | — (installed, not linked) |
| [starship.toml](starship.toml) | [Starship](https://starship.rs) prompt | `~/.config/starship.toml` |
| [wezterm/wezterm.lua](wezterm/wezterm.lua) | [WezTerm](https://wezfurlong.org/wezterm/) | `~/.config/wezterm/wezterm.lua` (`~/.wezterm.lua` on Windows) |
| [nvim/](nvim) | Neovim ([LazyVim](https://lazyvim.github.io)) | `~/.config/nvim` (`%LOCALAPPDATA%\nvim` on Windows) |

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

Open PowerShell **as Administrator** (needed to create symlinks — or enable
Developer Mode instead, see below) and run:

```powershell
git clone https://github.com/NavPilDev/dotfiles.git $HOME\.dotfiles
cd $HOME\.dotfiles
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

Both installers are idempotent and safe to re-run:

- Anything already at a target path that **isn't** already the correct
  symlink gets moved to a timestamped backup folder
  (`~/.dotfiles-backup/<timestamp>/` on macOS/Linux,
  `%USERPROFILE%\.dotfiles-backup\<timestamp>\` on Windows) before the new
  symlink is created.
- Package installs use `brew bundle` (macOS/Linux) or `winget install`
  (Windows), both of which no-op on already-installed packages.
- Failures for one package/extension (e.g. VS Code not yet on `PATH` for the
  `vscode "..."` extension lines) print a warning and don't abort the whole
  run — fix the prerequisite and re-run the script.

| Script | Platform | Installs packages via | Symlinks |
|---|---|---|---|
| [install.sh](install.sh) | macOS, Linux | Homebrew (`brew bundle`) | `.gitconfig`, `.zshrc`, `starship.toml`, `wezterm.lua`, `nvim/` |
| [install.ps1](install.ps1) | Windows | winget | `.gitconfig`, `starship.toml`, `wezterm.lua`, `nvim/` |
| [install.bat](install.bat) | Windows | — (wraps `install.ps1`) | — |

## Manual steps after installing

- **Shell**: on macOS/Linux, if zsh isn't already your login shell,
  `install.sh` will print the `chsh -s $(command -v zsh)` command to run.
- **Font**: the config expects a [Nerd Font](https://www.nerdfonts.com)
  (JetBrains Mono Nerd Font) for prompt/terminal glyphs to render correctly.
  It's installed automatically via `Brewfile`/`install.ps1`; set it as your
  terminal's font manually if your terminal doesn't pick it up.
- **VS Code extensions**: only install if the `code` CLI is on your `PATH`.
  In VS Code, run `Shell Command: Install 'code' command in PATH` from the
  Command Palette, then re-run the installer.
- **Neovim plugins**: first launch of `nvim` will bootstrap
  [lazy.nvim](https://github.com/folke/lazy.nvim) and install plugins from
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
