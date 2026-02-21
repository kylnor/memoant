#!/bin/bash
#==============================================================================
# Memoant Installer
# Unified audio pipeline: record meetings, transcribe voice memos,
# structure into Oracle DB + Obsidian notes.
#
# Usage: ./install.sh
#==============================================================================

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "  > $1"; }
success() { echo -e "  ${GREEN}✓${NC} $1"; }
warn()    { echo -e "  ${YELLOW}!${NC} $1"; }
fail()    { echo -e "  ${RED}✗${NC} $1" >&2; exit 1; }

echo ""
echo -e "${BOLD}  Memoant Installer${NC}"
echo ""

[[ "$(uname)" == "Darwin" ]] || fail "Memoant requires macOS"

MACOS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
[[ "$MACOS_MAJOR" -ge 12 ]] || fail "macOS 12.3+ required"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. System dependencies
echo -e "${BOLD}[1/5] System dependencies${NC}"

command -v brew &>/dev/null || fail "Homebrew required: https://brew.sh"
command -v ffmpeg &>/dev/null && success "ffmpeg" || { brew install ffmpeg; success "ffmpeg installed"; }
command -v ollama &>/dev/null && success "Ollama" || { brew install ollama; success "Ollama installed"; }

# 2. Python environment
echo -e "\n${BOLD}[2/5] Python environment${NC}"

command -v uv &>/dev/null || { info "Installing uv..."; brew install uv; }
success "uv $(uv --version 2>&1 | awk '{print $2}')"

cd "$PROJECT_DIR"
if [[ ! -d ".venv" ]]; then
    info "Creating venv (Python 3.12)..."
    uv venv --python 3.12
fi
success "venv at .venv/"

info "Installing dependencies..."
uv sync --quiet
success "Python dependencies installed"

# 3. Swift binaries
echo -e "\n${BOLD}[3/5] Swift binaries${NC}"

cd "$PROJECT_DIR/swift"
make -s
success "WindowPicker + WindowRecorder compiled"
cd "$PROJECT_DIR"

# 4. Ollama model
echo -e "\n${BOLD}[4/5] AI model${NC}"

if ! curl -s http://localhost:11434/api/tags &>/dev/null; then
    info "Starting Ollama..."
    ollama serve &>/dev/null &
    sleep 3
fi

if ollama list 2>/dev/null | grep -q "llama3.1:8b"; then
    success "llama3.1:8b ready"
else
    info "Pulling llama3.1:8b..."
    ollama pull llama3.1:8b
    success "llama3.1:8b downloaded"
fi

# 5. Directories + config
echo -e "\n${BOLD}[5/5] Setup${NC}"

mkdir -p ~/.memoant/inbox ~/.memoant/archive ~/.memoant/state
mkdir -p ~/.config/memoant

if [[ ! -f ~/.config/memoant/config.toml ]]; then
    info "Creating default config..."
    cat > ~/.config/memoant/config.toml << 'EOF'
[recording]
audio_device = "default"
sample_rate = 48000
channels = 2

[processing]
whisper_model = "mlx-community/whisper-large-v3-turbo"
ollama_model = "llama3.1:8b"
ollama_url = "http://127.0.0.1:11434"
default_mode = "auto"

[output]
oracle_db = "~/.oracle/oracle.db"
notes_dir = "~/Code/vault/kylnor/02 - Store/Meetings"
recordings_dir = "~/Documents/Memoant/Recordings"
archive_dir = "~/.memoant/archive"

[watch]
voice_memos = true
inbox_dir = "~/.memoant/inbox"
EOF
    success "Config at ~/.config/memoant/config.toml"
else
    success "Config exists"
fi

# Check HuggingFace token
if [[ -f "$HOME/.env" ]] && grep -q "HUGGINGFACE_TOKEN" "$HOME/.env" 2>/dev/null; then
    success "HuggingFace token configured (diarization enabled)"
else
    warn "No HUGGINGFACE_TOKEN in ~/.env (diarization will be skipped)"
    echo "       Get one at: https://huggingface.co/settings/tokens"
fi

echo ""
echo -e "${GREEN}${BOLD}  Memoant installed!${NC}"
echo ""
echo "  Usage:"
echo "    uv run memoant record              # Record audio"
echo "    uv run memoant record --screen     # Record a window"
echo "    uv run memoant stop                # Stop + process"
echo "    uv run memoant process file.m4a    # Process existing file"
echo "    uv run memoant watch               # Start watcher daemon"
echo "    uv run memoant devices             # List audio devices"
echo ""
