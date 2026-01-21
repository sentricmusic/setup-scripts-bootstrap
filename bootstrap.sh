#!/usr/bin/env bash
#
# One-command bootstrap for Sentric development environment.
#
# This script can be run from anywhere and will set up the Sentric development
# environment with the following structure:
#
#   <base>/
#   ├── .gitconfig              ← Git config (created later by multi-account setup)
#   ├── .gitconfig-work         ← Work account settings
#   ├── .gitconfig-personal     ← Personal account settings
#   ├── sentric/                ← Sentric organization repos
#   │   └── ...                 ← Other repos (cloned later via workspace tools)
#   ├── workspace/              ← Main workspace tools (cloned by this script)
#   │   └── projects/           ← Symlinks to sentric/* (created by workspace tools)
#   └── personal/               ← Personal repos (optional, created later)
#
# The script will:
# 1. Prompt for the base directory location
# 2. Install GitHub CLI (if needed)
# 3. Authenticate with GitHub (if needed)
# 4. Create the sentric/ folder structure
# 5. Clone the workspace repository
# 6. Output the command to run the full setup
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sentricmusic/setup-scripts-bootstrap/main/bootstrap.sh | bash
#
# Options:
#   --base-path PATH    The base directory (parent of sentric/)
#

set -e

# Configuration
ORG_NAME="sentricmusic"
REPO_NAME="workspace"
BASE_PATH=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
WHITE='\033[1;37m'
NC='\033[0m'

write_banner() {
    echo ""
    echo -e "${CYAN}+======================================================+${NC}"
    echo -e "${CYAN}|        Sentric Development Environment Setup         |${NC}"
    echo -e "${CYAN}+======================================================+${NC}"
    echo ""
}

write_status() {
    echo -e "${CYAN}-> $1${NC}"
}

write_structure() {
    local base_dir="$1"
    echo ""
    echo -e "  ${WHITE}Directory structure to be created:${NC}"
    echo ""
    echo -e "    ${GRAY}$base_dir/${NC}"
    echo -e "    ${GREEN}+-- sentric/${NC}                     ${GRAY}<- Sentric repos (cloned later)${NC}"
    echo -e "    ${GREEN}+-- workspace/${NC}                   ${GRAY}<- Workspace tools${NC}"
    echo -e "    ${GREEN}|   +-- projects/${NC}                ${GRAY}<- Symlinks to sentric/*${NC}"
    echo -e "    ${YELLOW}+-- personal/${NC}                    ${GRAY}<- Personal repos (optional)${NC}"
    echo ""
}

write_success() {
    echo -e "${GREEN}[OK] $1${NC}"
}

write_warning() {
    echo -e "${YELLOW}[!] $1${NC}"
}

write_error() {
    echo -e "${RED}[X] $1${NC}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_github_cli() {
    write_status "Installing GitHub CLI..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command_exists brew; then
            brew install gh
        else
            write_error "Homebrew is not available. Please install GitHub CLI manually from https://cli.github.com/"
            exit 1
        fi
    elif command_exists apt-get; then
        # Debian/Ubuntu
        write_status "Using apt to install GitHub CLI..."
        (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
            && sudo mkdir -p -m 755 /etc/apt/keyrings \
            && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
            && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
            && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
            && sudo apt update \
            && sudo apt install gh -y
    elif command_exists dnf; then
        # Fedora/RHEL
        sudo dnf install 'dnf-command(config-manager)' -y
        sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
        sudo dnf install gh -y
    else
        write_error "Could not find a supported package manager."
        write_error "Please install GitHub CLI manually from https://cli.github.com/"
        exit 1
    fi
}

check_github_auth() {
    gh auth status >/dev/null 2>&1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --base-path)
                BASE_PATH="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
}

expand_base_path() {
    # Expand a leading '~' to $HOME. Avoid eval to prevent arbitrary expansion.
    if [[ -n "$BASE_PATH" && "${BASE_PATH:0:1}" == "~" ]]; then
        BASE_PATH="$HOME${BASE_PATH:1}"
    fi
}

main() {
    parse_args "$@"
    expand_base_path
    
    write_banner
    
    # Define location options
    local option1="$HOME/code"
    local option2="/opt/code"
    local option3="$(pwd)"
     
     local sentricPath=""
     local workspacePath=""
     
    # If base path not provided, prompt for location
    if [ -z "$BASE_PATH" ]; then
        echo ""
        echo -e "  ${WHITE}Choose where to set up your development environment:${NC}"
        echo ""
        echo -e "    ${CYAN}[1]${NC} $option1"
        echo -e "    ${CYAN}[2]${NC} $option2"
        echo -e "    ${CYAN}[3]${NC} $option3 (Current directory)"
        echo ""
        echo -e "  ${GRAY}This will create: [your choice]/sentric/${NC}"
        echo ""

        # Use /dev/tty to ensure we read from user input even if script is piped (curl | bash)
        read -p "  Enter 1, 2, 3, or a custom path (default: 1): " choice < /dev/tty

        if [[ -z "$choice" || "$choice" == "1" ]]; then
            BASE_PATH="$option1"
        elif [[ "$choice" == "2" ]]; then
            BASE_PATH="$option2"
        elif [[ "$choice" == "3" ]]; then
            BASE_PATH="$option3"
        else
            BASE_PATH="$choice"
        fi

        expand_base_path
    fi
    
    sentricPath="$BASE_PATH/sentric"
    workspacePath="$BASE_PATH/workspace"
    
    # Show structure preview
    write_structure "$BASE_PATH"
    
    # Confirm before proceeding (only if repository doesn't exist yet)
    if [ ! -d "$workspacePath/.git" ]; then
        read -p "  Proceed with this location? (Y/n): " confirm < /dev/tty
        if [[ "$confirm" =~ ^[Nn] ]]; then
            echo ""
            echo -e "  ${GRAY}Exiting without changes.${NC}"
            exit 0
        fi
    fi
    
    echo ""
    
    # Step 1: Check for GitHub CLI
    write_status "Checking for GitHub CLI..."
    if command_exists gh; then
        write_success "GitHub CLI is installed"
    else
        write_warning "GitHub CLI is not installed"
        install_github_cli
        
        if command_exists gh; then
            write_success "GitHub CLI installed successfully"
        else
            write_error "Failed to install GitHub CLI. Please install manually from https://cli.github.com/"
            exit 1
        fi
    fi
    
    # Step 2: Check GitHub authentication
    echo ""
    write_status "Checking GitHub authentication..."
    if check_github_auth; then
        write_success "Already authenticated with GitHub"
    else
        write_warning "Not authenticated with GitHub"
        echo ""
        echo -e "  ${YELLOW}Please authenticate with your GitHub account.${NC}"
        echo -e "  ${YELLOW}A browser window will open for authentication.${NC}"
        echo ""
        
        gh auth login --web --git-protocol https
        
        if check_github_auth; then
            write_success "Successfully authenticated with GitHub"
        else
            write_error "GitHub authentication failed. Please try again."
            exit 1
        fi
    fi
    
    # Step 3: Create directory structure
    echo ""
    write_status "Creating directory structure..."
    if [ ! -d "$sentricPath" ]; then
        mkdir -p "$sentricPath"
        write_success "Created: $sentricPath"
    else
        write_success "Exists: $sentricPath"
    fi

    # Step 4: Clone or update workspace repository
    echo ""
    if [ -d "$workspacePath/.git" ]; then
        write_success "Workspace repository already exists at: $workspacePath"

        pushd "$workspacePath" > /dev/null

        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

        if [ "$current_branch" = "main" ]; then
            if git fetch origin main 2>/dev/null && git merge-base --is-ancestor HEAD origin/main 2>/dev/null; then
                write_status "Fast-forwarding main branch..."
                if git merge --ff-only origin/main 2>/dev/null; then
                    write_success "Repository updated successfully"
                else
                    write_warning "Cannot fast-forward (you may have local changes)"
                fi
            else
                write_warning "Branch is not on main or cannot fast-forward, skipping update"
            fi
        else
            write_warning "Not on main branch ($current_branch), skipping update"
        fi

        popd > /dev/null
    else
        write_status "Cloning workspace repository..."

        if gh repo clone "$ORG_NAME/$REPO_NAME" "$workspacePath"; then
            write_success "Workspace repository cloned"
        else
            write_error "Failed to clone workspace repository. Check your GitHub access."
            exit 1
        fi
    fi
    
    # Done - show next steps
    echo ""
    echo -e "${GREEN}+======================================================+${NC}"
    echo -e "${GREEN}|                    Bootstrap Complete                |${NC}"
    echo -e "${GREEN}+======================================================+${NC}"
    echo ""
    echo -e "  ${WHITE}Your Sentric environment is set up at:${NC}"
    echo -e "    ${CYAN}$sentricPath${NC}"
    echo ""
    echo -e "  ${WHITE}Available setup steps:${NC}"
    echo ""
    (cd "$workspacePath" && bash setup.sh --list)
    echo ""
    echo -e "  ${WHITE}Run this command to begin:${NC}"
    echo ""
    echo -e "    ${YELLOW}cd \"$workspacePath\" && ./setup.sh${NC}"
    echo ""
}

main "$@"
