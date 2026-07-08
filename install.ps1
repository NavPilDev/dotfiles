<#
.SYNOPSIS
    Sets up this dotfiles repo on native Windows.

.DESCRIPTION
    Installs the closest winget equivalents of the tools in Brewfile, then
    symlinks the shared configs (nvim, starship, wezterm, git) into
    %USERPROFILE%\.config, backing up anything that already exists.

    Persists XDG_CONFIG_HOME=%USERPROFILE%\.config for the user account so
    nvim and WezTerm (which default elsewhere on Windows) pick up their
    config from ~/.config with no further action needed.

    zsh-only pieces (.zshrc, zsh-autosuggestions, zsh-syntax-highlighting,
    tmux) are skipped here — use WSL + install.sh for full parity with
    macOS/Linux.

.NOTES
    Creating symlinks on Windows requires either an elevated (Administrator)
    PowerShell session, or Developer Mode enabled under
    Settings > Update & Security > For developers.
#>

$ErrorActionPreference = "Stop"

$DotfilesDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupDir = Join-Path $env:USERPROFILE ".dotfiles-backup\$(Get-Date -Format yyyyMMdd-HHmmss)"
$ConfigHome = Join-Path $env:USERPROFILE ".config"

function Info($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "!! $msg" -ForegroundColor Yellow }

# Overall progress is pinned to the last row of the console via a scroll
# region (same ANSI/VT approach as install.sh's footer), so winget's own
# download progress bars keep scrolling normally above it. Write-Progress
# was tried first, but hosts pin it near the top, not the bottom - and it
# can't be told otherwise. Falls back to plain log lines on hosts without
# VT support (older Windows PowerShell 5.1 outside Windows Terminal).
$Esc = [char]27
$SupportsAnsi = ($PSVersionTable.PSVersion.Major -ge 6) -or [bool]$env:WT_SESSION -or [bool]$env:TERM_PROGRAM

function Get-ConsoleHeight {
    try { return $Host.UI.RawUI.WindowSize.Height } catch { return 0 }
}

function Initialize-Footer {
    if (-not $SupportsAnsi) { return }
    $h = Get-ConsoleHeight
    if ($h -lt 3) { $script:SupportsAnsi = $false; return }
    Write-Host -NoNewline "$Esc[1;$($h - 1)r$Esc[$($h - 1);1H"
}

function Reset-Footer {
    if (-not $SupportsAnsi) { return }
    $h = Get-ConsoleHeight
    if ($h -lt 1) { return }
    Write-Host -NoNewline "$Esc[1;${h}r$Esc[$h;1H$Esc[2K"
}

function Write-Footer([string]$Text) {
    if (-not $SupportsAnsi) {
        Info $Text
        return
    }
    $h = Get-ConsoleHeight
    Write-Host -NoNewline "$Esc[s$Esc[$h;1H$Esc[2K$Text$Esc[u"
}

$TotalSteps = 3
$script:CurrentStep = 0
function Step($label) {
    $script:CurrentStep++
    $width = 30
    $filled = [int]($script:CurrentStep * $width / $TotalSteps)
    $bar = ("#" * $filled).PadRight($width, "-")
    $pct = [int](($script:CurrentStep / $TotalSteps) * 100)
    Info "[$($script:CurrentStep)/$TotalSteps] $label"
    Write-Footer "[$bar] $pct% - Step $($script:CurrentStep)/$TotalSteps`: $label"
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function New-Link {
    param([string]$Target, [string]$Link)

    $linkDir = Split-Path -Parent $Link
    if (-not (Test-Path $linkDir)) {
        New-Item -ItemType Directory -Path $linkDir -Force | Out-Null
    }

    $existing = Get-Item -Path $Link -Force -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.LinkType -eq "SymbolicLink" -and $existing.Target -eq $Target) {
            return
        }
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        Info "Backing up existing $Link -> $BackupDir\"
        Move-Item -Path $Link -Destination $BackupDir -Force
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Link -Target $Target -Force | Out-Null
        Info "Linked $Link -> $Target"
    } catch {
        Warn "Could not create symlink at $Link. Re-run PowerShell as Administrator, or enable Developer Mode. Error: $_"
    }
}

function Install-Packages {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Warn "winget not found. Install 'App Installer' from the Microsoft Store, then re-run this script."
        return
    }

    Info "Installing packages via winget (equivalents of Brewfile entries)"
    $packages = @(
        "Git.Git",
        "GitHub.cli",
        "Neovim.Neovim",
        "OpenJS.NodeJS.LTS",
        "Starship.Starship",
        "wez.wezterm",
        "Yarn.Yarn",
        "pyenv-win.pyenv-win",
        "DEVCOM.JetBrainsMonoNerdFont"
    )

    for ($i = 0; $i -lt $packages.Count; $i++) {
        $pkg = $packages[$i]
        Info "winget install $pkg ($($i + 1)/$($packages.Count))"
        try {
            winget install --id $pkg -e --source winget --accept-package-agreements --accept-source-agreements
        } catch {
            Warn "Failed to install $pkg (it may already be installed, or the winget id may have changed - try 'winget search <name>'). $_"
        }
    }

    if (Get-Command code -ErrorAction SilentlyContinue) {
        Info "Installing VS Code extensions from Brewfile"
        Get-Content (Join-Path $DotfilesDir "Brewfile") | Where-Object { $_ -match '^vscode "([^"]+)"' } | ForEach-Object {
            $ext = $matches[1]
            try { code --install-extension $ext } catch { Warn "Failed to install VS Code extension $ext" }
        }
    } else {
        Warn "VS Code CLI ('code') not on PATH yet - skipping extension install. Open VS Code once, run 'Shell Command: Install code command in PATH', then re-run this script."
    }
}

function Set-XdgConfigHome {
    # nvim and WezTerm only look in ~/.config on Windows if XDG_CONFIG_HOME
    # is set - persist it for the user account (registry), and set it for
    # this session too so later steps in this script see it.
    [Environment]::SetEnvironmentVariable("XDG_CONFIG_HOME", $ConfigHome, "User")
    $env:XDG_CONFIG_HOME = $ConfigHome
    Info "Set XDG_CONFIG_HOME=$ConfigHome (persisted for future sessions)"
}

function Move-Legacy {
    param([string]$Path)
    # Earlier versions of this script (or a plain, pre-existing dotfile) put
    # config directly under $HOME/%LOCALAPPDATA% instead of ~/.config. Clear
    # those out of the way (backed up, not deleted) so they can't shadow the
    # new locations.
    if (Test-Path $Path) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        Info "Moving legacy $Path out of the way -> $BackupDir\"
        Move-Item -Path $Path -Destination $BackupDir -Force
    }
}

function Set-Symlinks {
    Info "Symlinking dotfiles into $ConfigHome"
    Move-Legacy (Join-Path $env:USERPROFILE ".gitconfig")
    Move-Legacy (Join-Path $env:USERPROFILE ".wezterm.lua")
    Move-Legacy (Join-Path $env:LOCALAPPDATA "nvim")

    New-Link -Target (Join-Path $DotfilesDir ".gitconfig") -Link (Join-Path $ConfigHome "git\config")
    New-Link -Target (Join-Path $DotfilesDir "starship.toml") -Link (Join-Path $ConfigHome "starship.toml")
    New-Link -Target (Join-Path $DotfilesDir "wezterm\wezterm.lua") -Link (Join-Path $ConfigHome "wezterm\wezterm.lua")
    New-Link -Target (Join-Path $DotfilesDir "nvim") -Link (Join-Path $ConfigHome "nvim")
}

if (-not (Test-Admin)) {
    Warn "Not running as Administrator. Symlink creation will fail unless Developer Mode is enabled (Settings > Update & Security > For developers)."
}

Initialize-Footer
try {
    Step "Setting XDG_CONFIG_HOME"
    Set-XdgConfigHome

    Step "Installing packages via winget"
    Install-Packages

    Step "Symlinking dotfiles"
    Set-Symlinks
} finally {
    # Always restore the console's scroll region, even on error/Ctrl-C,
    # otherwise the last row stays reserved for the rest of the session.
    Reset-Footer
}

Info "Done. Everything now lives under $ConfigHome - open a new terminal (or WezTerm window) to pick up the changes, no further action needed."
Info "Note: .zshrc, zsh-autosuggestions, zsh-syntax-highlighting and tmux are POSIX-shell tools and are not set up here. Use WSL + install.sh if you want those too."
if (Test-Path $BackupDir) {
    Info "Pre-existing files were backed up to: $BackupDir"
}
