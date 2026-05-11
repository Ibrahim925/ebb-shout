# Ebb Shout

A fully local, open-source macOS dictation app. The name is a deliberate inversion of Wispr Flow.

Speak → Transcribe (Whisper) → Enhance (Gemma) → Type into any app. Nothing leaves your machine.

## Prerequisites

- macOS 14 (Sonoma) or later
- Xcode 15 or later
- [Ollama](https://ollama.com) installed and running

## Setup

```bash
ollama pull whisper
ollama pull gemma3:4b
```

## Build & Run

Open `EbbShout.xcodeproj` in Xcode and press ⌘R, or:

```bash
xcodebuild build -scheme EbbShout -destination 'platform=macOS'
```

## First Launch

Ebb Shout will guide you through:
1. Verifying Ollama is reachable
2. Pulling required models if missing
3. Granting Microphone access
4. Granting Accessibility access (System Settings → Privacy & Security → Accessibility)

Then press ⌥Space to start dictating.

## Design

See [docs/superpowers/specs/2026-05-11-ebb-shout-design.md](docs/superpowers/specs/2026-05-11-ebb-shout-design.md).
