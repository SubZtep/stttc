# Speech-To-Text

Minimalist **push-to-talk** dictation for **Hyprland**: hold a hotkey to talk, release to drop the transcribed text into your clipboard.

A small bash script pipes your mic to a local [Speaches](https://speaches.ai) (Whisper) server — fully offline, language auto-picked from your keyboard layout.

## Setup

Run from a terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/SubZtep/stt/v0.1.0/setup.sh | bash
```

Automatic installation steps:

1. Check dependencies (`docker`, `ffmpeg`, `wl-clipboard`, `libnotify`, `jq`, `hyprland`).\
   _On Arch/Omarchy it offers to install missing ones via pacman._
2. Create `~/.config/stt.json` from defaults (if not already present).
3. Download the scripts into user binaries.
4. Start the Speaches server and download the configured models.
5. Add the Hyprland keybinding (`SUPER` + `` ` ``).

Re-running is safe. Linux/Hyprland only.

> The first transcription after install can be slow while the model loads; it's fast after that.

## Configuration

`~/.config/stt.json` is created on first install. Edit it to customise behaviour:

```jsonc
{
  "url": "http://localhost:8000/v1",        // Speaches API endpoint
  "model": "Systran/faster-whisper-small",  // default (multi-language) model
  "device": "default",                      // ffmpeg/pulse mic input
  "bin": "$HOME/.local/bin",                // where scripts are installed
  "container": "speaches",                  // Docker container name
  "hypr": {
    "config": "$HOME/.config/hypr/bindings.conf",
    "key": "SUPER, grave",
    "mark": ["# >>> stt >>>", "# <<< stt <<<"]
  },
  "models": {
    "en": "Systran/faster-whisper-medium.en",
    "hu": "Maxdorger29/whisper-large-v3-turbo-hungarian-lora"
  }
}
```

**`models`** maps ISO 639-1 language codes to Hugging Face model IDs. The active keyboard layout (detected via `hyprctl`) automatically selects the right model — no extra config needed. Re-run setup after adding a language to download its model.

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/SubZtep/stt/v0.1.0/setup.sh | bash -s -- --uninstall
```

Removes the scripts, the config, the keybinding, the server, and the downloaded models.
