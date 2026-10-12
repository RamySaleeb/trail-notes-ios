// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TrailNotesCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "TrailNotesCore", targets: ["TrailNotesCore"])],
    targets: [
        .target(name: "TrailNotesCore", path: "TrailNotes/Core"),
        .testTarget(name: "TrailNotesCoreTests", dependencies: ["TrailNotesCore"])
    ]
)
