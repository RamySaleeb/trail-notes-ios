# Contributing to Trail Notes

Thanks for helping make this small native iOS example easier to learn from. Documentation fixes, focused tests, accessibility improvements, and well-scoped features are welcome.

## Start here

1. Read the [README](README.md) and [open roadmap issues](https://github.com/RamySaleeb/trail-notes-ios/issues).
2. Comment on the issue you want to tackle to avoid duplicated effort. For a larger design change, describe the approach before implementing it.
3. Fork the repository, create a topic branch, and keep the pull request focused on one behavior.

## Local setup and checks

Use macOS with Xcode 26.6 and the iOS 26.5 SDK or newer. No backend, credentials, paid signing team, or third-party dependencies are needed for simulator development.

```sh
git clone https://github.com/YOUR-USERNAME/trail-notes-ios.git
cd trail-notes-ios
swift test --parallel
xcodebuild -project TrailNotes.xcodeproj -scheme TrailNotes \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/TrailNotesBuild CODE_SIGNING_ALLOWED=NO build
```

Open `TrailNotes.xcodeproj` to run the app. The core tests use Swift Testing through `Package.swift`. The separate `TrailNotesUITests` target exercises journal flows, keyboard shortcuts, largest text sizes, and selected accessibility audits with fictional in-memory fixtures.

```sh
xcodebuild -project TrailNotes.xcodeproj -scheme TrailNotes \
  -destination 'platform=iOS Simulator,name=iPhone 17e,OS=latest' \
  -parallel-testing-enabled NO -resultBundlePath /tmp/TrailNotesAccessibility.xcresult \
  CODE_SIGNING_ALLOWED=NO test
```

Repeat with `name=iPad mini (A17 Pro)`. CI runs core tests, an unsigned build, and both UI destinations on pushes to main, pull requests, and manual dispatch. Result bundles retain screenshots and audit diagnostics for 14 days. See the [validation record](docs/ACCESSIBILITY.md) for scope and the remaining physical-device VoiceOver checklist. Passing automated checks does not establish accessibility conformance.

CI pins Xcode 26.6 on `macos-26`; if the runner image retires that version, update the pin and document the new verified toolchain together. See the [official runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md).

## Code boundaries

- `TrailNotes/Core/Journal.swift`: value models, search rules, and actor-backed JSON storage. The same source is compiled by the app and test package.
- `TrailNotes/Core/JournalModel.swift`: injectable main-actor model and compose draft state.
- `TrailNotes/TrailNotesApp.swift`: SwiftUI presentation.
- `Tests/TrailNotesCoreTests`: deterministic behavior tests with isolated temporary files.
- `TrailNotes/Core/JournalAccessibility.swift`: concise semantic row labels and favorite state.
- `TrailNotesUITests`: simulator flow tests and accessibility audits.

Keep disk access out of views, avoid unneeded packages, preserve existing data on failures, and use semantic system colors and text styles. Do not silently change the on-disk format; explain compatibility and recovery if a change requires migration.

## Pull request checklist

- [ ] Explain the problem, behavior change, and related issue.
- [ ] Add meaningful tests for changed behavior; run the checks above.
- [ ] For UI changes, include fictional-data screenshots and the device, OS, and Xcode versions used.
- [ ] Check relevant large-text, light/dark, and VoiceOver behavior; state any checks not performed.
- [ ] Update the walkthrough when user-visible behavior changes.
- [ ] Exclude build output, user-specific Xcode settings, credentials, personal journal entries, and private or employer-owned source.

## Reporting a bug

Include reproduction steps, expected and actual behavior, relevant toolchain/device versions, and minimal sanitized logs. Use fictional notes in screenshots. For a feature idea, describe the user need, smallest useful scope, and how it can be tested.

Be respectful and review the implementation, not the person. Roadmap issues describe proposed work, not delivery promises.
