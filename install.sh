#!/usr/bin/env bash
#
# Sets up this dotfiles repo on macOS or Linux:
#   1. Installs Homebrew (if missing)
#   2. Installs packages from Brewfile (casks/VS Code extensions are
#      macOS-only and are skipped on Linux)
#   3. Symlinks configs into place, backing up anything that already exists
#
# Usage: ./install.sh
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1"; }

case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux) PLATFORM="linux" ;;
  *)
    echo "Unsupported OS: $(uname -s). On Windows, run install.ps1 instead."
    exit 1
    ;;
esac
info "Detected platform: $PLATFORM"

link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    return
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mkdir -p "$BACKUP_DIR"
    info "Backing up existing $dest -> $BACKUP_DIR/"
    mv "$dest" "$BACKUP_DIR/"
  fi
  ln -s "$src" "$dest"
  info "Linked $dest -> $src"
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    info "Homebrew already installed"
    return
  fi
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ "$PLATFORM" = "linux" ]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  else
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
}

install_packages() {
  install_homebrew
  if [ "$PLATFORM" = "macos" ]; then
    info "Installing packages from Brewfile (brew formulae, casks, VS Code extensions)"
    brew bundle --file="$DOTFILES_DIR/Brewfile" \
      || warn "Some Brewfile entries failed (e.g. VS Code not on PATH for extensions). Fix the prerequisite and re-run: brew bundle --file=\"$DOTFILES_DIR/Brewfile\""
  else
    info "Installing packages from Brewfile (skipping macOS-only casks/VS Code entries)"
    local tmp
    tmp="$(mktemp)"
    grep -Ev '^(cask|vscode) ' "$DOTFILES_DIR/Brewfile" > "$tmp"
    brew bundle --file="$tmp" || warn "Some Brewfile entries failed to install."
    rm -f "$tmp"
  fi
}

symlink_dotfiles() {
  info "Symlinking dotfiles"
  link "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
  link "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
  link "$DOTFILES_DIR/starship.toml" "$HOME/.config/starship.toml"
  link "$DOTFILES_DIR/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"
  link "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"
}

check_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"
  if [ -n "$zsh_path" ] && [ "${SHELL:-}" != "$zsh_path" ]; then
    warn "zsh is installed but isn't your default shell yet. Run: chsh -s $zsh_path"
  fi
}

install_packages
symlink_dotfiles
check_default_shell

info "Done. Open a new terminal (or WezTerm window) to see the changes."
if [ -d "$BACKUP_DIR" ]; then
  info "Pre-existing files were backed up to: $BACKUP_DIR"
fi
