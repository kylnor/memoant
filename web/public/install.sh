#!/bin/bash
#==============================================================================
# Memoant Installer
# One-command setup: meeting recording + AI transcription + Raycast
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kylenorthup/meeting-recorder/main/install.sh | bash
#   or: ./install.sh
#
# What it does:
#   1. Installs dependencies (Homebrew, ffmpeg, jq, Ollama, Node.js, WhisperX)
#   2. Clones/updates the repo
#   3. Compiles native Swift binaries
#   4. Pulls the AI model
#   5. Builds + imports the Raycast extension
#   6. Walks you through configuration
#==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="${MEMOANT_DIR:-$HOME/Code/meeting-recorder}"
CONFIG_DIR="$HOME/.config/memoant"
CONFIG_FILE="$CONFIG_DIR/config"
REPO_URL="https://github.com/kylnor/memoant.git"

# Counters
INSTALLED=0
SKIPPED=0
WARNINGS=0

info()    { echo -e "  ${BLUE}>${NC} $1"; }
success() { echo -e "  ${GREEN}✓${NC} $1"; INSTALLED=$((INSTALLED + 1)); }
skip()    { echo -e "  ${DIM}- $1 (already installed)${NC}"; SKIPPED=$((SKIPPED + 1)); }
warn()    { echo -e "  ${YELLOW}!${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
fail()    { echo -e "  ${RED}✗${NC} $1" >&2; exit 1; }
step()    { echo ""; echo -e "${BOLD}[$1/$TOTAL_STEPS] $2${NC}"; }

ask() {
    local prompt="$1"
    local default="$2"
    local result=""
    echo -ne "  ${prompt} ${DIM}[${default}]${NC}: "
    read -r result
    echo "${result:-$default}"
}

TOTAL_STEPS=7

echo ""
echo -e "${BOLD}  ╔══════════════════════════════════╗${NC}"
echo -e "${BOLD}  ║         Memoant Installer         ║${NC}"
echo -e "${BOLD}  ║   Meeting recorder + AI notes     ║${NC}"
echo -e "${BOLD}  ╚══════════════════════════════════╝${NC}"
echo ""

# Pre-flight
[[ "$(uname)" == "Darwin" ]] || fail "Memoant requires macOS 12.3+"

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [[ "$MACOS_MAJOR" -lt 12 ]]; then
    fail "macOS 12.3+ required (you have $MACOS_VERSION)"
fi

#==============================================================================
step 1 "Dependencies"
#==============================================================================

# Homebrew
if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    success "Homebrew installed"
else
    skip "Homebrew $(brew --version | head -1 | awk '{print $2}')"
fi

# ffmpeg
if ! command -v ffmpeg &>/dev/null; then
    info "Installing ffmpeg..."
    brew install ffmpeg
    success "ffmpeg installed"
else
    skip "ffmpeg $(ffmpeg -version 2>&1 | head -1 | awk '{print $3}')"
fi

# jq
if ! command -v jq &>/dev/null; then
    info "Installing jq..."
    brew install jq
    success "jq installed"
else
    skip "jq $(jq --version 2>&1)"
fi

# Node.js (for Raycast extension)
if ! command -v node &>/dev/null; then
    info "Installing Node.js..."
    brew install node
    success "Node.js installed"
else
    skip "Node.js $(node --version)"
fi

# Ollama
if ! command -v ollama &>/dev/null; then
    info "Installing Ollama..."
    brew install ollama
    success "Ollama installed"
else
    skip "Ollama"
fi

# Python 3
if ! command -v python3 &>/dev/null; then
    info "Installing Python 3..."
    brew install python@3
    success "Python 3 installed"
else
    skip "Python $(python3 --version | awk '{print $2}')"
fi

# WhisperX
if command -v whisperx &>/dev/null; then
    skip "WhisperX at $(which whisperx)"
else
    # Check common install locations
    WHISPERX_FOUND=""
    for p in "$HOME/Library/Python/3.9/bin/whisperx" "$HOME/Library/Python/3.11/bin/whisperx" "$HOME/Library/Python/3.12/bin/whisperx" "$HOME/.local/bin/whisperx"; do
        if [[ -f "$p" ]]; then
            WHISPERX_FOUND="$p"
            break
        fi
    done

    if [[ -n "$WHISPERX_FOUND" ]]; then
        skip "WhisperX at $WHISPERX_FOUND"
    else
        info "Installing WhisperX (transcription engine)..."
        pip3 install --user whisperx 2>/dev/null || pip3 install --user --break-system-packages whisperx 2>/dev/null || {
            warn "WhisperX auto-install failed. Try manually: pip3 install whisperx"
        }
        info "Pinning PyTorch 2.5.1 for diarization compatibility..."
        pip3 install --user torch==2.5.1 torchaudio==2.5.1 2>/dev/null || pip3 install --user --break-system-packages torch==2.5.1 torchaudio==2.5.1 2>/dev/null || true

        if command -v whisperx &>/dev/null; then
            success "WhisperX installed"
        else
            warn "WhisperX may need PATH update. Check: pip3 show whisperx"
        fi
    fi
fi

#==============================================================================
step 2 "Memoant source code"
#==============================================================================

if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "Updating existing installation..."
    git -C "$INSTALL_DIR" pull --ff-only 2>/dev/null && success "Updated $INSTALL_DIR" || skip "Already up to date"
elif [[ -d "$INSTALL_DIR" ]]; then
    skip "Memoant at $INSTALL_DIR (not a git repo, skipping update)"
else
    info "Cloning Memoant..."
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$REPO_URL" "$INSTALL_DIR"
    success "Cloned to $INSTALL_DIR"
fi

cd "$INSTALL_DIR"

#==============================================================================
step 3 "Compile native binaries"
#==============================================================================

compile_swift() {
    local src="$1"
    local bin="$2"
    shift 2
    local frameworks=("$@")

    if [[ ! -f "$bin" ]] || [[ "$src" -nt "$bin" ]]; then
        local fw_args=""
        for fw in "${frameworks[@]}"; do
            fw_args="$fw_args -framework $fw"
        done
        info "Compiling $bin..."
        eval swiftc -o "$bin" "$src" $fw_args 2>&1 | head -5 || {
            warn "Failed to compile $bin. Xcode Command Line Tools may be needed: xcode-select --install"
            return 1
        }
        chmod +x "$bin"
        success "$bin compiled"
    else
        skip "$bin up to date"
    fi
}

compile_swift WindowRecorder.swift WindowRecorder ScreenCaptureKit AVFoundation AppKit
compile_swift WindowPickerThumbs.swift WindowPicker ScreenCaptureKit Cocoa
chmod +x record-meeting.sh

#==============================================================================
step 4 "AI model"
#==============================================================================

# Start Ollama if not running
if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
    info "Starting Ollama service..."
    ollama serve &>/dev/null &
    sleep 3
fi

if ollama list 2>/dev/null | grep -q "gpt-oss:20b"; then
    skip "gpt-oss:20b model ready"
else
    info "Pulling gpt-oss:20b (13GB download, this takes a few minutes)..."
    ollama pull gpt-oss:20b
    success "gpt-oss:20b model downloaded"
fi

#==============================================================================
step 5 "Raycast extension"
#==============================================================================

if [[ -d "$INSTALL_DIR/raycast-extension" ]]; then
    cd "$INSTALL_DIR/raycast-extension"

    if [[ ! -d "node_modules" ]]; then
        info "Installing extension dependencies..."
        npm install --silent 2>/dev/null
        success "Dependencies installed"
    else
        skip "Dependencies already installed"
    fi

    info "Building extension..."
    npx ray build 2>/dev/null && success "Raycast extension built" || {
        warn "Raycast extension build failed. You can build it manually:"
        echo "       cd $INSTALL_DIR/raycast-extension && npm run build"
    }

    # Try to open Raycast import (this URL scheme may not work on all versions)
    if command -v open &>/dev/null && [[ -d "/Applications/Raycast.app" ]]; then
        info "Opening Raycast to import extension..."
        open "raycast://extensions/import?path=$INSTALL_DIR/raycast-extension" 2>/dev/null || {
            info "Import manually: Raycast > Settings > Extensions > + > Add Script Directory"
            echo "       Path: $INSTALL_DIR/raycast-extension"
        }
        success "Raycast extension ready"
    elif [[ -d "/Applications/Raycast.app" ]]; then
        warn "Import the extension in Raycast:"
        echo "       Raycast > Settings > Extensions > + > Add Script Directory"
        echo "       Path: $INSTALL_DIR/raycast-extension"
    else
        warn "Raycast not found. Install from https://raycast.com then import the extension."
    fi

    cd "$INSTALL_DIR"
else
    warn "Raycast extension directory not found"
fi

#==============================================================================
step 6 "Configuration"
#==============================================================================

mkdir -p "$CONFIG_DIR"

if [[ -f "$CONFIG_FILE" ]]; then
    info "Existing config found at $CONFIG_FILE"
    RECONFIGURE=$(ask "Reconfigure?" "n")
    if [[ "$RECONFIGURE" != "y" && "$RECONFIGURE" != "Y" ]]; then
        skip "Keeping existing configuration"
        source "$CONFIG_FILE"
    fi
fi

if [[ ! -f "$CONFIG_FILE" ]] || [[ "${RECONFIGURE:-n}" == "y" ]] || [[ "${RECONFIGURE:-n}" == "Y" ]]; then
    echo ""
    info "Where should Memoant save files?"
    echo ""

    RECORDINGS_DIR=$(ask "Recordings folder" "$HOME/Documents/Memoant/Recordings")
    NOTES_DIR=$(ask "Notes folder (Obsidian, etc.)" "$HOME/Documents/Memoant/Notes")

    # Detect WhisperX path
    WHISPERX_PATH=""
    if command -v whisperx &>/dev/null; then
        WHISPERX_PATH="$(which whisperx)"
    else
        for p in "$HOME/Library/Python/3.9/bin/whisperx" "$HOME/Library/Python/3.11/bin/whisperx" "$HOME/Library/Python/3.12/bin/whisperx" "$HOME/.local/bin/whisperx"; do
            if [[ -f "$p" ]]; then
                WHISPERX_PATH="$p"
                break
            fi
        done
    fi

    # Detect Ollama model
    OLLAMA_MODEL="gpt-oss:20b"

    cat > "$CONFIG_FILE" << EOF
# Memoant Configuration
# Edit this file to change settings, or re-run the installer.

# Where to save recordings (audio/video files)
MEMOANT_RECORDINGS_DIR="$RECORDINGS_DIR"

# Where to save meeting notes (markdown files)
MEMOANT_NOTES_DIR="$NOTES_DIR"

# Ollama model for metadata extraction
MEMOANT_OLLAMA_MODEL="$OLLAMA_MODEL"

# Tool paths (auto-detected, override if needed)
# MEMOANT_WHISPERX="$WHISPERX_PATH"
# MEMOANT_OLLAMA="$(command -v ollama 2>/dev/null || echo "/usr/local/bin/ollama")"
# MEMOANT_FFMPEG="$(command -v ffmpeg 2>/dev/null || echo "/opt/homebrew/bin/ffmpeg")"
EOF

    # Create output directories
    mkdir -p "$RECORDINGS_DIR"
    mkdir -p "$NOTES_DIR"

    success "Config saved to $CONFIG_FILE"
fi

#==============================================================================
step 7 "Final checks"
#==============================================================================

# HuggingFace token
if [[ -f "$HOME/.env" ]] && grep -q "HF_TOKEN" "$HOME/.env" 2>/dev/null; then
    HF_VAL=$(grep "HF_TOKEN=" "$HOME/.env" | head -1 | cut -d= -f2)
    if [[ -n "$HF_VAL" ]]; then
        skip "HuggingFace token configured (speaker diarization enabled)"
    else
        warn "HF_TOKEN is empty in ~/.env"
    fi
else
    echo ""
    warn "Speaker diarization needs a HuggingFace token (optional)."
    echo "       Without it, transcription works but without speaker labels."
    echo ""
    echo "       To set up later:"
    echo "       1. Get token: https://huggingface.co/settings/tokens"
    echo "       2. Accept:    https://huggingface.co/pyannote/speaker-diarization-3.1"
    echo "       3. Add to ~/.env:"
    echo "          echo 'HF_TOKEN=hf_your_token_here' >> ~/.env"
fi

# Screen Recording permissions
echo ""
warn "Screen recording requires a one-time permission grant:"
echo "       System Settings > Privacy & Security > Screen Recording"
echo "       Enable for: Terminal, iTerm, and/or Raycast"

# Add CLI shortcut
SHELL_RC=""
if [[ -f "$HOME/.zshrc" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]]; then
    if ! grep -q "memoant" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Memoant - meeting recorder" >> "$SHELL_RC"
        echo "alias memoant='$INSTALL_DIR/record-meeting.sh'" >> "$SHELL_RC"
        success "Added 'memoant' alias to $(basename "$SHELL_RC")"
    else
        skip "'memoant' alias already in $(basename "$SHELL_RC")"
    fi
fi

#==============================================================================
# Done
#==============================================================================

echo ""
echo -e "  ${BOLD}══════════════════════════════════${NC}"
echo -e "  ${GREEN}${BOLD}Memoant installed!${NC}"
echo -e "  ${DIM}$INSTALLED installed, $SKIPPED already present, $WARNINGS warnings${NC}"
echo -e "  ${BOLD}══════════════════════════════════${NC}"
echo ""
echo "  Quick start:"
echo ""
echo -e "    ${BOLD}memoant audio${NC}    Start recording"
echo -e "    ${BOLD}memoant stop${NC}     Stop and transcribe"
echo -e "    ${BOLD}memoant status${NC}   Show configuration"
echo ""
echo "  Or use Raycast: search 'Record Audio' or 'Record Screen'"
echo ""
echo -e "  Config: ${DIM}$CONFIG_FILE${NC}"
echo -e "  Docs:   ${DIM}https://memoant.com${NC}"
echo ""
