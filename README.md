# Trail Notes

An original native iOS field journal built with Swift and SwiftUI. Capture small moments, find them by title, place, or notes, and keep favorites close.

**Status:** working iOS simulator demo. Built with Xcode 26.6 and manually checked on iPhone 17 Pro / iOS 26.5. Four Swift Testing core tests pass. Source is public on GitHub. Not distributed through TestFlight or the App Store.

<img src="preview.png" width="320" alt="Trail Notes showing two saved field notes with Favorites only enabled on an iPhone simulator">

## Native by design

- SwiftUI navigation, search, sheets, forms, and system controls.
- Semantic colors and scalable system typography.
- On-device JSON persistence with atomic writes and serialized actor access.
- Explicit loading and save failures; corrupt journals are not silently replaced.
- No account, network requests, analytics, third-party libraries, or private source.

The included entries are fictional examples. Data is stored in the app's Application Support directory. This prototype does not implement encryption beyond platform protections, cloud sync, export, editing, or deletion. Removing the app can remove its data.

## Code map

| Path | Responsibility |
| --- | --- |
| `TrailNotes/Core/Journal.swift` | Codable value model, query rules, actor-backed disk repository |
| `TrailNotes/TrailNotesApp.swift` | SwiftUI app, observable state, navigation, composition |
| `Tests/TrailNotesCoreTests/JournalTests.swift` | Filtering, ordering, round trips, missing/empty/corrupt data |

The core is a standalone Swift package. The presentation layer depends on the core; storage does not depend on SwiftUI. State changes are committed only after a successful save. A failed new-note save keeps the draft available.

## Run the tests

Requires Swift 6 or later on macOS:

```sh
swift test
```

## Run the iOS app

1. Open `TrailNotes.xcodeproj` in Xcode 26.6 or later.
2. Select the **TrailNotes** scheme and an iOS 26.5 or later simulator.
3. Press Run. No credentials, backend, or package downloads are needed.

The checked-in project retains the template's iOS 26.5 deployment target. The same core files are compiled by both the app's synchronized source folder and the standalone test package, so no duplicate implementation or package-linking step is needed.

```sh
xcodebuild -project TrailNotes.xcodeproj -scheme TrailNotes \
  -sdk iphonesimulator -configuration Debug \
  -derivedDataPath /tmp/TrailNotesBuild CODE_SIGNING_ALLOWED=NO build
```

To run on a physical device, choose your own signing team in Xcode. This native demo is not a browser application.

## Walkthrough

1. Launch to see two clearly fictional field notes.
2. Search `ridge` or a word within a note; combine search with Favorites only.
3. Open a note and toggle its favorite state.
4. Create a note using the compose button. A nonblank title is required.
5. Relaunch to confirm saved notes persist.

Verified on iPhone 17 Pro / iOS 26.5: launch, note details, favorite label updates, favorite filtering, search, new-note save, and persistence after terminating and relaunching the app. The screenshot shows fictional sample entries after favoriting both.

Still to validate: VoiceOver reading order, full keyboard navigation, accessibility text sizes, iPad layouts, and physical-device behavior. The four automated tests cover core behavior; there is not yet an automated UI test target.

## Contributing

Keep changes focused, include tests for behavior changes, and describe simulator/OS versions used for UI verification. Please use synthetic sample data only. Suggested next steps after app validation: edit/delete with confirmation, export, and injected storage failure tests for the presentation layer.
