# Sentric Setup Bootstrap

One-command bootstrap for Sentric development environment.

## Quick Start

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/sentricmusic/setup-scripts-bootstrap/main/bootstrap.ps1 | iex
```

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/sentricmusic/setup-scripts-bootstrap/main/bootstrap.sh | bash
```

## What It Does

The bootstrap script will:

1. **Prompt for base directory** - choose from suggested locations or enter custom path
2. **Install GitHub CLI** - if not already installed
3. **Authenticate with GitHub** - opens browser for secure login
4. **Create directory structure** - sets up `<base>/sentric/` folder
5. **Clone the platform repository** - to `<base>/sentric/platform`
6. **Output the setup command** - run it to complete environment setup

## What Happens Next (The Setup Wizard)

Once the bootstrap completes, you will run the main `dev-setup` wizard which handles:

1. **📦 Package Manager Check** - Ensures winget (Windows) or brew (macOS) is installed
2. **👤 Development Roles Selection** - Choose your role (Frontend, Backend, Data Science, etc.)
3. **🛠️ Developer Tools** - IDEs, Git tools, language tools, Docker, databases, etc.
4. **🔧 GitHub and Git Setup** - Git configuration and GitHub authentication
5. **🔀 Multi-Account Setup** - Optional: Configure separate work/personal GitHub accounts
6. **🐳 WSL & Docker** - Optional: WSL (Windows) and Docker Desktop setup
7. **🎨 Terminal Customization** - Optional: Oh My Posh, fonts, and profile
8. **📂 Repository Cloning** - Optional: Clone Sentric repositories

## Directory Structure

The script creates the following structure:

```text
<base>/
+-- sentric/                <- Sentric organization repos
|   +-- platform/           <- Main platform tools (cloned by this script)
|   +-- ...                  <- Other repos (cloned later via platform tools)
+-- personal/                <- Personal repos (optional, created later)
```

## Custom Location

To specify a custom base directory:

**Windows:**

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/sentricmusic/setup-scripts-bootstrap/main/bootstrap.ps1 -OutFile bootstrap.ps1
./bootstrap.ps1 -BasePath C:\dev
```

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/sentricmusic/setup-scripts-bootstrap/main/bootstrap.sh -o bootstrap.sh
chmod +x bootstrap.sh
./bootstrap.sh --base-path ~/dev
```

## Requirements

- **Windows**: Windows 10/11 with PowerShell 5.1+ and winget
- **macOS**: macOS 10.15+ (Homebrew will be installed if needed)
- **Linux**: Debian/Ubuntu or Fedora/RHEL based distros

## Troubleshooting

### "Cannot be loaded because running scripts is disabled"

On Windows, you may need to enable script execution:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Authentication Issues

If GitHub authentication fails, try manually:

```bash
gh auth login --hostname github.com --git-protocol ssh --web
```

Then run the bootstrap script again.

### WinGet SSL/Network Issues (Windows)

> ⚠️ **Warning:** WinGet uses "certificate pinning" for the Microsoft Store source. If your network uses a proxy, firewall (like Palo Alto or Zscaler), or antivirus (like Kaspersky) that inspects SSL traffic, the certificate gets swapped, and WinGet blocks the connection.

If you encounter SSL errors during tool installation, you may need to temporarily disconnect from VPNs or strict corporate networks during the initial setup.

## License

Internal use only - Sentric Music
