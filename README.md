# Ebb Shout

A fully local, open-source macOS dictation app. The name is a deliberate inversion of Wispr Flow.

Speak → Transcribe locally (Whisper) → Enhance locally (Gemma via Ollama) → Type into any app.

## Prerequisites

- macOS 14 (Sonoma) or later
- Xcode 15 or later
- [Ollama](https://ollama.com) installed and running
- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) built locally

## Setup

```bash
ollama pull gemma4:latest

git clone https://github.com/ggml-org/whisper.cpp
cd whisper.cpp
cmake -B build
cmake --build build -j --config Release
sh ./models/download-ggml-model.sh base.en
```

In Ebb Shout Settings → Models, set:
- `whisper-cli`: `/path/to/whisper.cpp/build/bin/whisper-cli`
- `GGML model`: `/path/to/whisper.cpp/models/ggml-base.en.bin`

Ebb Shout runs whisper.cpp with `--no-gpu` by default for the most reliable local path.

## Build & Run

Open `EbbShout.xcodeproj` in Xcode and press ⌘R, or:

```bash
xcodebuild build -scheme EbbShout -destination 'platform=macOS'
```

## First Launch

Ebb Shout will guide you through:
1. Verifying Ollama is reachable
2. Configuring the local Whisper model
3. Granting Microphone access
4. Granting Accessibility access (System Settings → Privacy & Security → Accessibility)

Then press ⌥Space to start dictating. You can change this shortcut in Settings → Hotkey.

## Design

See [docs/superpowers/specs/2026-05-11-ebb-shout-design.md](docs/superpowers/specs/2026-05-11-ebb-shout-design.md).
