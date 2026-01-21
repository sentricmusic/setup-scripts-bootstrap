#!/usr/bin/env pwsh
<#
.SYNOPSIS
    One-command bootstrap for Sentric development environment.

.DESCRIPTION
    This script can be run from anywhere and will set up the Sentric development
    environment with the following structure:

    <base>/
    ├── .gitconfig              ← Git config (created later by multi-account setup)
    ├── .gitconfig-work         ← Work account settings
    ├── .gitconfig-personal     ← Personal account settings
    ├── sentric/                ← Sentric organization repos
    │   └── ...                 ← Other repos (cloned later via workspace tools)
    ├── workspace/              ← Main workspace tools (cloned by this script)
    │   └── projects/           ← Symlinks to sentric/* (created by workspace tools)
    └── personal/               ← Personal repos (optional, created later)

    The script will:
    1. Prompt for the base directory location
    2. Install GitHub CLI (if needed)
    3. Authenticate with GitHub (if needed)
    4. Create the sentric/ folder structure
     5. Clone the workspace repository
     6. Output the command to run the full setup

.PARAMETER BasePath
    The base directory (parent of sentric/).
    If not provided, prompts the user interactively.

.EXAMPLE
    # Run from PowerShell (will prompt for location):
    ./bootstrap.ps1

.EXAMPLE
    # Specify the base path:
     ./bootstrap.ps1 -BasePath "C:\dev"
      # Creates: C:\dev\workspace, C:\dev\sentric

.EXAMPLE
    # One-liner from PowerShell (downloads and runs):
    irm https://raw.githubusercontent.com/sentricmusic/setup-scripts-bootstrap/main/bootstrap.ps1 | iex
#>

param(
    [string]$BasePath
)

$ErrorActionPreference = "Stop"

# Configuration
$OrgName = "sentricmusic"
$RepoName = "workspace"

function Write-Banner {
    Write-Host ""
    Write-Host "+======================================================+" -ForegroundColor Cyan
    Write-Host "|        Sentric Development Environment Setup         |" -ForegroundColor Cyan
    Write-Host "+======================================================+" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Structure {
    param([string]$BaseDir)
    Write-Host ""
    Write-Host "  Directory structure to be created:" -ForegroundColor White
    Write-Host ""
    Write-Host "    $BaseDir/" -ForegroundColor Gray
    Write-Host "    +-- sentric/                     " -ForegroundColor Green -NoNewline
    Write-Host "<- Sentric repos (cloned later)" -ForegroundColor DarkGray
    Write-Host "    +-- workspace/                   " -ForegroundColor Green -NoNewline
    Write-Host "<- Workspace tools" -ForegroundColor DarkGray
    Write-Host "    |   +-- projects/                " -ForegroundColor Green -NoNewline
    Write-Host "<- Symlinks to sentric/*" -ForegroundColor DarkGray
    Write-Host "    +-- personal/                    " -ForegroundColor Yellow -NoNewline
    Write-Host "<- Personal repos (optional)" -ForegroundColor DarkGray
      Write-Host ""
}

function Write-Status {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "-> $Message" -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[X] $Message" -ForegroundColor Red
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Install-GitHubCLI {
    Write-Status "Installing GitHub CLI..."

    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        if (Test-CommandExists "winget") {
            winget install GitHub.cli --accept-package-agreements --accept-source-agreements

            # Refresh PATH
            $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
            $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
            $env:Path = $machinePath + ";" + $userPath
        }
        else {
            Write-ErrorMsg "winget is not available. Please install GitHub CLI manually from https://cli.github.com/"
            exit 1
        }
    }
    else {
        # macOS/Linux
        if (Test-CommandExists "brew") {
            brew install gh
        }
        else {
            Write-ErrorMsg "Homebrew is not available. Please install GitHub CLI manually from https://cli.github.com/"
            exit 1
        }
    }
}

function Test-GitHubAuth {
    try {
        $null = gh auth status 2>&1
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

function Main {
    Write-Banner

    # Determine base path options
    $option1 = "C:\code"
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        $option2 = Join-Path $env:USERPROFILE "code"
    }
    else {
        $option1 = Join-Path $HOME "code"
        $option2 = "/opt/code"
    }
    $option3 = Get-Location

    if (-not $BasePath) {
        Write-Host "  Where would you like to set up your Sentric development environment?" -ForegroundColor White
        Write-Host ""
        Write-Host "  Suggested locations:" -ForegroundColor Gray
        Write-Host "    [1] $option1" -ForegroundColor White
        Write-Host "    [2] $option2" -ForegroundColor White
        Write-Host "    [3] $option3 (Current Directory)" -ForegroundColor White
        Write-Host ""
        Write-Host "  This will create: [your choice]/sentric/" -ForegroundColor DarkGray
        Write-Host ""

        $inputPath = Read-Host "  Enter 1, 2, 3, or a custom path (default: 1)"

        if ([string]::IsNullOrWhiteSpace($inputPath) -or $inputPath -eq "1") {
            $BasePath = $option1
        }
        elseif ($inputPath -eq "2") {
            $BasePath = $option2
        }
        elseif ($inputPath -eq "3") {
            $BasePath = $option3
        }
        else {
            $BasePath = $inputPath.Trim()
        }
    }

    # Expand any ~ or environment variables
    $BasePath = [System.Environment]::ExpandEnvironmentVariables($BasePath)
    if ($BasePath.StartsWith("~")) {
        $BasePath = $BasePath.Replace("~", $HOME)
    }

     # Define paths
      $sentricPath = Join-Path $BasePath "sentric"
      $workspacePath = Join-Path $BasePath "workspace"

    # Show what will be created
    Write-Structure -BaseDir $BasePath

     # Confirm before proceeding (only if repository doesn't exist yet)
     if (-not (Test-Path (Join-Path $workspacePath ".git"))) {
        $confirm = Read-Host "  Proceed with this location? (Y/n)"
        if ($confirm -eq "n" -or $confirm -eq "N") {
            Write-Host ""
            Write-Warning "Setup cancelled. Run again to choose a different location."
            exit 0
        }
    }

    Write-Host ""

    # Step 1: Check for GitHub CLI
    Write-Status "Checking for GitHub CLI..."
    if (Test-CommandExists "gh") {
        Write-Success "GitHub CLI is installed"
    }
    else {
        Write-Warning "GitHub CLI is not installed"
        Install-GitHubCLI

        if (Test-CommandExists "gh") {
            Write-Success "GitHub CLI installed successfully"
        }
        else {
            Write-ErrorMsg "Failed to install GitHub CLI. Please install manually from https://cli.github.com/"
            exit 1
        }
    }

    # Step 2: Check GitHub authentication
    Write-Host ""
    Write-Status "Checking GitHub authentication..."
    if (Test-GitHubAuth) {
        Write-Success "Already authenticated with GitHub"
    }
    else {
        Write-Warning "Not authenticated with GitHub"
        Write-Host ""
        Write-Host "  Please authenticate with your GitHub account." -ForegroundColor Yellow
        Write-Host "  A browser window will open for authentication." -ForegroundColor Yellow
        Write-Host ""

        gh auth login --web --git-protocol https

        if (Test-GitHubAuth) {
            Write-Success "Successfully authenticated with GitHub"
        }
        else {
            Write-ErrorMsg "GitHub authentication failed. Please try again."
            exit 1
        }
    }

    # Step 3: Create directory structure
    Write-Host ""
    Write-Status "Creating directory structure..."

    if (-not (Test-Path $sentricPath)) {
        New-Item -ItemType Directory -Path $sentricPath -Force | Out-Null
        Write-Success "Created: $sentricPath"
    }
    else {
        Write-Success "Exists: $sentricPath"
    }

     # Step 4: Clone workspace repository
     Write-Host ""
     if (Test-Path (Join-Path $workspacePath ".git")) {
         Write-Success "Workspace repository already exists at: $workspacePath"
         
         Push-Location $workspacePath
        try {
            $currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
            
            if ($currentBranch -eq "main") {
                git fetch origin main 2>&1 | Out-Null
                $isAncestor = git merge-base --is-ancestor HEAD origin/main 2>$null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Status "Fast-forwarding main branch..."
                    git merge --ff-only origin/main 2>&1 | Out-Null
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Repository updated successfully"
                    }
                    else {
                        Write-Warning "Cannot fast-forward (you may have local changes)"
                    }
                }
                else {
                    Write-Warning "Branch is not on main or cannot fast-forward, skipping update"
                }
            }
            else {
                Write-Warning "Not on main branch ($currentBranch), skipping update"
            }
         }
         catch {
             Write-Warning "Could not update workspace repository"
         }
        finally {
            Pop-Location
        }
    }
     else {
         Write-Status "Cloning workspace repository..."
         gh repo clone "$OrgName/$RepoName" $workspacePath

         if ($LASTEXITCODE -eq 0) {
             Write-Success "Workspace repository cloned"
         }
         else {
             Write-ErrorMsg "Failed to clone workspace repository. Check your GitHub access."
             exit 1
         }
     }

    # Done - show next steps
    Write-Host ""
    Write-Host "+======================================================+" -ForegroundColor Green
    Write-Host "|                    Bootstrap Complete                |" -ForegroundColor Green
    Write-Host "+======================================================+" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Your Sentric environment is set up at:" -ForegroundColor White
    Write-Host "    $sentricPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Available setup steps:" -ForegroundColor White
    Write-Host ""
    Push-Location $workspacePath
    try {
        & ".\setup.ps1" --list
    }
    finally {
        Pop-Location
    }
    Write-Host ""
    Write-Host "  Run this command to begin:" -ForegroundColor White
    Write-Host ""
    Write-Host "    cd `"$workspacePath`"; .\setup.ps1" -ForegroundColor Yellow
    Write-Host ""
}

Main
