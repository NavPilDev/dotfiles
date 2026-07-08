<#
.SYNOPSIS
    Sets up this dotfiles repo on native Windows.

.DESCRIPTION
    Installs the closest winget equivalents of the tools in Brewfile, then
    symlinks the shared configs (nvim, starship, wezterm, git) into place,
    backing up anything that already exists.

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

function Info($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "!! $msg" -ForegroundColor Yellow }

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
        "DEVCOM.JetBrainsMonoNerdFont",
        "Microsoft.VisualStudioCode"
    )

    foreach ($pkg in $packages) {
        Info "winget install $pkg"
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

function Set-Symlinks {
    Info "Symlinking dotfiles"
    New-Link -Target (Join-Path $DotfilesDir ".gitconfig") -Link (Join-Path $env:USERPROFILE ".gitconfig")
    New-Link -Target (Join-Path $DotfilesDir "starship.toml") -Link (Join-Path $env:USERPROFILE ".config\starship.toml")
    New-Link -Target (Join-Path $DotfilesDir "wezterm\wezterm.lua") -Link (Join-Path $env:USERPROFILE ".wezterm.lua")
    New-Link -Target (Join-Path $DotfilesDir "nvim") -Link (Join-Path $env:LOCALAPPDATA "nvim")
}

if (-not (Test-Admin)) {
    Warn "Not running as Administrator. Symlink creation will fail unless Developer Mode is enabled (Settings > Update & Security > For developers)."
}

Install-Packages
Set-Symlinks

Info "Done. Open a new terminal (or WezTerm window) to see the changes."
Info "Note: .zshrc, zsh-autosuggestions, zsh-syntax-highlighting and tmux are POSIX-shell tools and are not set up here. Use WSL + install.sh if you want those too."
if (Test-Path $BackupDir) {
    Info "Pre-existing files were backed up to: $BackupDir"
}
