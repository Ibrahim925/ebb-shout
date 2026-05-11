# Contributing to Ebb Shout

## Reporting Bugs

Open an issue and include:
- macOS version
- Ollama version (`ollama --version`)
- Steps to reproduce
- What you expected vs what happened

## Proposing Features

Open an issue to discuss before opening a PR. Unsolicited large PRs may be closed.

## Code Style

- SwiftFormat with default rules (`brew install swiftformat && swiftformat .`)
- No force unwraps (`!`) — use `guard let` or `if let`
- Shared mutable state must live in a Swift `actor`
- One type per file

## PR Checklist

- [ ] Builds with zero warnings (`xcodebuild build -scheme EbbShout`)
- [ ] New behaviour has a test in `EbbShoutTests`
- [ ] Manually tested the changed flow end-to-end
