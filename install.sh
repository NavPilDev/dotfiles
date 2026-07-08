#!/usr/bin/env bash
#
# Sets up this dotfiles repo on macOS or Linux:
#   1. Installs Homebrew (if missing)
#   2. Installs packages from Brewfile (casks/VS Code extensions are
#      macOS-only and are skipped on Linux)
#   3. Symlinks configs into ~/.config, backing up anything that already
#      exists, so nothing further is needed for tools to pick them up
#
# Usage: ./install.sh
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1"; }

# Overall progress is pinned to the last row of the terminal via a scroll
# region (DECSTBM), so brew/curl's own download progress bars keep scrolling
# normally above it instead of the overall bar getting buried by them.
IS_TTY=0
if [ -t 1 ] && [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ] && command -v tput >/dev/null 2>&1; then
  IS_TTY=1
fi

footer_init() {
  [ "$IS_TTY" = 1 ] || return
  local lines; lines="$(tput lines)"
  [ "$lines" -gt 2 ] || { IS_TTY=0; return; }
  tput csr 0 $((lines - 2))
  tput cup $((lines - 2)) 0
}

footer_reset() {
  [ "$IS_TTY" = 1 ] || return
  local lines; lines="$(tput lines)"
  tput csr 0 $((lines - 1))
  tput cup $((lines - 1)) 0
  tput el
}
trap footer_reset EXIT INT TERM

footer_draw() {
  if [ "$IS_TTY" != 1 ]; then
    printf '%s\n' "$1"
    return
  fi
  local lines; lines="$(tput lines)"
  tput sc
  tput cup $((lines - 1)) 0
  tput el
  printf '%s' "$1"
  tput rc
}

TOTAL_STEPS=4
CURRENT_STEP=0
progress() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  local width=30
  local filled=$((CURRENT_STEP * width / TOTAL_STEPS))
  local empty=$((width - filled))
  local bar
  bar="$(printf '%*s' "$filled" '' | tr ' ' '#')$(printf '%*s' "$empty" '' | tr ' ' '-')"
  info "Step $CURRENT_STEP/$TOTAL_STEPS: $1"
  footer_draw "$(printf '\033[1;32m[%s]\033[0m %3d%% - Step %d/%d: %s' \
    "$bar" $((CURRENT_STEP * 100 / TOTAL_STEPS)) "$CURRENT_STEP" "$TOTAL_STEPS" "$1")"
}

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

migrate_legacy() {
  # Earlier versions of this script (or a plain, pre-existing dotfile) put
  # git/zsh config directly in $HOME. Clear those out of the way (backed up,
  # not deleted) so they can't shadow the XDG locations below - git and zsh
  # both prefer a $HOME-level file over the ~/.config one if both exist.
  for legacy in "$HOME/.gitconfig" "$HOME/.zshrc"; do
    if [ -e "$legacy" ] || [ -L "$legacy" ]; then
      mkdir -p "$BACKUP_DIR"
      info "Moving legacy $legacy out of the way -> $BACKUP_DIR/"
      mv "$legacy" "$BACKUP_DIR/"
    fi
  done
}

symlink_dotfiles() {
  info "Symlinking dotfiles into ~/.config"
  migrate_legacy
  link "$DOTFILES_DIR/.gitconfig" "$HOME/.config/git/config"
  link "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"
  link "$DOTFILES_DIR/.zshrc" "$HOME/.config/zsh/.zshrc"
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

footer_init

progress "Installing Homebrew"
install_homebrew

progress "Installing packages from Brewfile"
install_packages

progress "Symlinking dotfiles into ~/.config"
symlink_dotfiles

progress "Checking default shell"
check_default_shell

footer_reset
info "Done. Everything now lives under ~/.config - open a new terminal (or WezTerm window) to pick up the changes, no further action needed."
if [ -d "$BACKUP_DIR" ]; then
  info "Pre-existing files were backed up to: $BACKUP_DIR"
fi
