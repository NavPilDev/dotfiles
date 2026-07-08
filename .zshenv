# Relocates zsh's config into ~/.config/zsh (XDG Base Directory).
# This file has to live at ~/.zshenv itself: zsh reads it before ZDOTDIR
# can take effect, so it can't be moved into ~/.config like everything else.
export ZDOTDIR="$HOME/.config/zsh"
