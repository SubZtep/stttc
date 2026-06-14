# Speech-To-Text

Minimalist **push-to-talk** dictation for **Hyprland**: hold a hotkey to talk, release to drop the transcribed text into your clipboard.

A small bash script pipes your mic 🎤 **live** to a local [Speaches](https://speaches.ai) (Whisper) server — fully offline. Your language and speech recognition model are auto-picked from the active keyboard layout _(input.kb_layout in hyprland.conf)_.

## Setup

Run from a terminal:

```sh
curl -fsSL https://stt.demo.land/setup.sh | bash
```

Automatic installation steps:

1. Check dependencies (`docker`, `ffmpeg`, `wl-clipboard`, `libnotify`, `jq`, `hyprland`).\
   _On Arch/Omarchy it offers to install missing ones via pacman._
2. Create `~/.config/stt/config.json` from the [default configuration](./config/default.json) (if not already present).
3. Copy [`model_aliases.json`](./config/model_aliases.json) to `~/.config/stt/aliases.json`.
4. Download the scripts into user binaries.
5. Start the Speaches server and download the default (`multi`) model.
6. Add the Hyprland keybinding (`SUPER` + `` ` ``).

Re-running is safe. Linux/Hyprland only.

## How it works

```
[hold key]  → detect layout → "stt · Magyar / Hallgatom…" notification
             → ffmpeg streams WAV live to Speaches during recording
[release]   → recording stops → "Írás…" → Speaches transcribes
             → result copied to clipboard + typed via notification
```

Audio is piped directly to Speaches while you speak, so by the time you release the key the server has already received everything and just needs to run inference.

### Missed release fallback

If you release the modifier key (`SUPER`) before the actual key (`` ` ``), Hyprland's `bindr` may not fire. A second **fallback release binding** is installed: releasing the naked key alone will also stop the recording — but only if a recording is actually in progress (guarded by `/tmp/stt.recording`).

### Toggle mode

Prefer toggle over push-to-talk? Replace the Hyprland bindings with:

```
bind = SUPER, grave, exec, stt-toggle
```

Press once to start, press again to stop and transcribe. No reliance on key-release events at all.

Pressing the key while a transcription is already in progress cancels it and starts a fresh recording — no stuck processes. The recording also auto-caps at 20 seconds in case a release event is completely lost.

If the model for your current language isn't downloaded yet, `multi` (the multilingual fallback) handles that request while the correct model downloads in the background — seamless next time.

## Configuration

`~/.config/stt/config.json` is generated on first install using the [default configuration](./config/default.json). Use it as a starting point and customise it to suit your workflow.

### Model aliases

Language-to-model mapping lives in [`config/model_aliases.json`](./config/model_aliases.json). Each key is an ISO 639-1 language code (or `multi` for the multilingual fallback):

```json
{
  "hu": {
    "model": "SubZtep/whisper-large-v3-hu-ct2-int8",
    "name": "Magyar",
    "listening": "Hallgatom…",
    "typing": "Írás…"
  }
}
```

The active keyboard layout (detected via `hyprctl`) automatically picks the matching alias — no extra config needed. Language models are downloaded **on first use**, so only the models you actually speak are ever fetched.

Notifications use the `name`, `listening`, and `typing` strings from the alias, so the UI speaks your language. `setup.sh` transforms this into the flat format Speaches expects and keeps the rich version in `~/.config/stt/aliases.json` for the client scripts to read.

Re-run setup after editing `model_aliases.json` to apply changes.

### Environment overrides

| Variable | Description |
|---|---|
| `STT_URL` | Speaches base URL (default: `http://localhost:8000/v1`) |
| `STT_MODEL` | Model/alias to use (overrides config) |
| `STT_LANGUAGE` | ISO 639-1 code — overrides layout detection |
| `STT_DEVICE` | PulseAudio/PipeWire input device |
| `STT_DEBUG` | Set to `1` to print HTTP status and raw response to stderr |

## Debugging

Run from a terminal to see what's happening:

```sh
STT_DEBUG=1 STT_LANGUAGE=en stt
```

Check which models are available on your server:

```sh
stt-check
```

## Uninstall

```sh
curl -fsSL https://stt.demo.land/setup.sh | bash -s -- --uninstall
```

Removes the scripts, the config, the keybinding, the server, and the downloaded models.

## Language models

Speaches runs Whisper models — these are speech recognition (ASR) models, not language models. They do one thing: convert audio waveforms to text. No reasoning, no generation, no chat.

The VAD (Voice Activity Detection) is an even smaller separate model that just detects whether audio contains speech before passing it to Whisper.