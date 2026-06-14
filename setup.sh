#!/usr/bin/env bash
#
# Setup for stt push-to-talk — run it straight from the web:
#   curl -fsSL https://stt.demo.land/setup.sh | bash
#
# Downloads the scripts, starts the speaches server, downloads the model, and
# adds the Hyprland keybinding. Re-running is safe. Undo with:
#   curl -fsSL https://stt.demo.land/setup.sh | bash -s -- --uninstall
#
set -euo pipefail

REPO="${STT_REPO:-SubZtep/stt}"
REF="${STT_REF:-v0.7.0}"
BASE="https://raw.githubusercontent.com/$REPO/$REF"
CONFIG_FILE="$HOME/.config/stt/config.json"

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------- checks

# command -> Arch package
declare -A PKG=(
  [docker]=docker [ffmpeg]=ffmpeg [curl]=curl
  [wl-copy]=wl-clipboard [notify-send]=libnotify [jq]=jq [hyprctl]=hyprland
)

missing_pkgs=""
for cmd in "${!PKG[@]}"; do
  have "$cmd" || missing_pkgs="$missing_pkgs ${PKG[$cmd]}"
done
missing_pkgs="$(echo "$missing_pkgs" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/^ *//;s/ *$//')"

is_arch() { [ -r /etc/os-release ] && grep -qiE '^(ID|ID_LIKE)=.*arch' /etc/os-release; }

if [ -n "$missing_pkgs" ]; then
  echo "Missing dependencies: $missing_pkgs"
  if is_arch; then
    read -p "Install via pacman? [y/N] " -n 1 -r </dev/tty
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      # shellcheck disable=SC2086  # intentional: pass packages as separate args
      sudo pacman -S --needed --noconfirm $missing_pkgs ||
        echo "WARNING: pacman install failed — install manually and re-run." >&2
    else
      echo "Install them with:"
      echo "  sudo pacman -S --needed $missing_pkgs"
    fi
  else
    echo "Install them with your package manager, then re-run."
  fi
fi

# hard requirements to proceed
have curl || { echo "ERROR: curl is required." >&2; exit 1; }
have docker || { echo "ERROR: docker is required." >&2; exit 1; }
have jq || { echo "ERROR: jq is required." >&2; exit 1; }

# ---------------------------------------------------------------- config

if [ ! -f "$CONFIG_FILE" ]; then
  mkdir -p "$(dirname "$CONFIG_FILE")"

  local_default="$(dirname "$0")/config/default.json"
  if [ -f "$local_default" ]; then
    cat "$local_default" > "$CONFIG_FILE"
  else
    curl -fsSL "$BASE/config/default.json" -o "$CONFIG_FILE"
  fi

  echo "Created config: $CONFIG_FILE"
fi

ALIASES_FILE="$HOME/.config/stt/aliases.json"
SPEACHES_ALIASES_FILE="$HOME/.config/stt/speaches_aliases.json"
local_aliases="$(dirname "$0")/config/model_aliases.json"
if [ -f "$local_aliases" ]; then
  cp "$local_aliases" "$ALIASES_FILE"
else
  curl -fsSL "$BASE/config/model_aliases.json" -o "$ALIASES_FILE"
fi
# Speaches needs a flat { "lang": "model-id" } map; transform from the rich format
jq 'map_values(.model // empty) | with_entries(select(.value != ""))' "$ALIASES_FILE" > "$SPEACHES_ALIASES_FILE"
echo "Aliases: $ALIASES_FILE"

cfg() { jq -r "$1 // empty" "$CONFIG_FILE"; }
expand() { eval echo "$1"; } # expand $HOME etc. in config values

BIN_DIR="$(expand "$(cfg '.bin')")"; BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
CONTAINER="$(cfg '.container')"; CONTAINER="${CONTAINER:-speaches}"
MODEL="$(cfg '.model')"; MODEL="${MODEL:-Systran/faster-whisper-small}"
HYPR_CONF="$(expand "$(cfg '.hypr.config')")"; HYPR_CONF="${HYPR_CONF:-$HOME/.config/hypr/bindings.conf}"
KEY="$(cfg '.hypr.key')"; KEY="${KEY:-SUPER, grave}"
MARK_START="$(cfg '.hypr.mark[0]')"; MARK_START="${MARK_START:-# >>> stt >>>}"
MARK_END="$(cfg '.hypr.mark[1]')"; MARK_END="${MARK_END:-# <<< stt <<<}"

# ---------------------------------------------------------------- uninstall

if [ "${1:-}" = "--uninstall" ]; then
  echo "Uninstalling stt…"

  rm -f "$BIN_DIR/stt" "$BIN_DIR/stt-layout-lang" "$BIN_DIR/stt-check" "$BIN_DIR/stt-download" "$BIN_DIR/stt-toggle"
  echo "  removed scripts"

  rm -rf "$HOME/.local/share/stt"
  echo "  removed sound files"

  if [ -f "$CONFIG_FILE" ]; then
    rm -f "$CONFIG_FILE"
    echo "  removed config ($CONFIG_FILE)"
  fi

  rm -f "$HOME/.config/stt/aliases.json" "$HOME/.config/stt/speaches_aliases.json"
  echo "  removed aliases"
  rmdir --ignore-fail-on-non-empty "$HOME/.config/stt" 2>/dev/null || true

  if [ -f "$HYPR_CONF" ] && grep -qF "$MARK_START" "$HYPR_CONF"; then
    cp "$HYPR_CONF" "$HYPR_CONF.bak"
    sed -i "/$MARK_START/,/$MARK_END/d" "$HYPR_CONF"
    have hyprctl && hyprctl reload >/dev/null 2>&1 || true
    echo "  removed keybinding (backup: $HYPR_CONF.bak)"
  fi

  if have docker && docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    docker rm -f "$CONTAINER" >/dev/null
    echo "  removed container '$CONTAINER'"
  fi

  if have docker && docker volume ls --format '{{.Name}}' | grep -qx "hf-hub-cache"; then
    docker volume rm hf-hub-cache >/dev/null 2>&1 && echo "  removed downloaded models" || true
  fi

  echo "Done."
  exit 0
fi

# ---------------------------------------------------------------- scripts

echo "Downloading scripts -> $BIN_DIR"
mkdir -p "$BIN_DIR"
for f in stt stt-layout-lang stt-check stt-download stt-toggle; do
  curl -fsSL "$BASE/$f" -o "$BIN_DIR/$f"
  chmod +x "$BIN_DIR/$f"
  echo "  $f"
done

case ":$PATH:" in
*":$BIN_DIR:"*) ;;
*) echo "NOTE: $BIN_DIR is not on PATH — add it to your shell profile." ;;
esac

SOUND_DIR="$HOME/.local/share/stt"
SOUND_FILE="$SOUND_DIR/open-a-wine.mp3"
mkdir -p "$SOUND_DIR"
local_sound="$(dirname "$0")/assets/827991__spinopel__open-a-wine.mp3"
if [ -f "$local_sound" ]; then
  cp "$local_sound" "$SOUND_FILE"
else
  curl -fsSL "$BASE/assets/827991__spinopel__open-a-wine.mp3" -o "$SOUND_FILE"
fi
echo "Sound: $SOUND_FILE"

# ---------------------------------------------------------------- server

url="$(cfg '.url')"; url="${url:-http://localhost:8000/v1}"

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "Server: container '$CONTAINER' already exists — leaving it."
else
  echo "Starting speaches server…"
  _speaches_tag="0.9.0-rc.3"
  _docker_extra_args=()
  if have nvidia-smi && nvidia-smi --query-gpu=name --format=csv,noheader >/dev/null 2>&1; then
    echo "  NVIDIA GPU detected — using CUDA image"
    _speaches_tag="${_speaches_tag}-cuda"
    _docker_extra_args+=(--gpus all)
  else
    echo "  No GPU detected — using CPU image"
    _speaches_tag="${_speaches_tag}-cpu"
  fi
  docker run -d \
    --name "$CONTAINER" \
    -p 8000:8000 \
    -e ENABLE_UI=False \
    "${_docker_extra_args[@]}" \
    -v "$SPEACHES_ALIASES_FILE":/home/ubuntu/speaches/model_aliases.json \
    -v hf-hub-cache:/home/ubuntu/.cache/huggingface/hub \
    "ghcr.io/speaches-ai/speaches:${_speaches_tag}" >/dev/null
fi

echo "Downloading default model (multi)…"
# wait for server to be ready then download via stt-download
for _ in $(seq 1 30); do
  curl -fsS "$url/models" >/dev/null 2>&1 && break
  sleep 1
done
STT_ALIASES="$ALIASES_FILE" STT_CONFIG="$CONFIG_FILE" "$BIN_DIR/stt-download" multi

# ---------------------------------------------------------------- keybinding

if have hyprctl; then
  mkdir -p "$(dirname "$HYPR_CONF")"
  touch "$HYPR_CONF"

  if grep -qF "$MARK_START" "$HYPR_CONF"; then
    echo "Keybinding already present — leaving it."
  else
    cp "$HYPR_CONF" "$HYPR_CONF.bak" 2>/dev/null || true
    {
      echo "$MARK_START"
      echo "bind  = $KEY, exec, STT_LANGUAGE=\$(stt-layout-lang) stt"
      # Kill the exact ffmpeg PID recorded by the stt script, guarded by lockfile.
      echo "bindr = $KEY, exec, sh -c '[ -f /tmp/stt.recording ] && kill -INT \"\$(cat /tmp/stt.ffmpeg.pid 2>/dev/null)\" 2>/dev/null || true'"
      # Fallback: if the modifier is released before the key, the naked key
      # release still stops the recording (guarded by /tmp/stt.recording).
      _key_only="${KEY##*, }"
      echo "bindr = , $_key_only, exec, sh -c '[ -f /tmp/stt.recording ] && kill -INT \"\$(cat /tmp/stt.ffmpeg.pid 2>/dev/null)\" 2>/dev/null || true'"
      echo "$MARK_END"
    } >>"$HYPR_CONF"
    hyprctl reload >/dev/null 2>&1 || true
    echo "Added keybinding ($KEY) -> $HYPR_CONF"
  fi
else
  echo "NOTE: hyprctl not found — skipped keybinding (see README to add it manually)."
fi

echo "Done. Hold $KEY to talk, release to transcribe."
