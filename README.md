# Speech-To-Text

Minimalist **push-to-talk** dictation for **Hyprland**: hold a hotkey to talk, release to drop the transcribed text into your clipboard.

A small bash script pipes your mic to a local [Speaches](https://speaches.ai) (Whisper) server — fully offline, language auto-picked from your keyboard layout.

## Setup

Run from a terminal:

```sh
curl -fsSL https://stt.demo.land/setup.sh | bash
```

Automatic installation steps:

1. Check dependencies (`docker`, `ffmpeg`, `wl-clipboard`, `libnotify`, `jq`, `hyprland`).\
   _On Arch/Omarchy it offers to install missing ones via pacman._
2. Create `~/.config/stt/config.json` from the default configuration (if not already present).
3. Copy `model_aliases.json` to `~/.config/stt/aliases.json`.
4. Download the scripts into user binaries.
5. Start the Speaches server and download the default (`multi`) model.
6. Add the Hyprland keybinding (`SUPER` + `` ` ``).

Re-running is safe. Linux/Hyprland only.

> The first transcription after switching to a new language will pause while the model downloads — it's cached after that.

## Configuration

`~/.config/stt/config.json` is generated on first install using the [default configuration](./config/default.json). Use it as a starting point and customise it to suit your workflow.

### Model aliases

Language-to-model mapping lives in [`config/model_aliases.json`](./config/model_aliases.json) and is served directly to the Speaches server. Each key is an ISO 639-1 language code (or `multi` for the multilingual fallback); the value is a Hugging Face model ID.

The active keyboard layout (detected via `hyprctl`) automatically picks the matching alias — no extra config needed. Language models are downloaded **on first use**, so only the models you actually speak are ever fetched. Re-run setup after editing `model_aliases.json` to push the updated aliases to `~/.config/stt/aliases.json`.

> **Upgrading from v0.3.0?** Config files moved to `~/.config/stt/`. Remove the old files before re-running setup:
> ```sh
> rm -f ~/.config/stt.json ~/.config/stt-aliases.json
> ```

## Uninstall

```sh
curl -fsSL https://stt.demo.land/setup.sh | bash -s -- --uninstall
```

Removes the scripts, the config, the keybinding, the server, and the downloaded models.
