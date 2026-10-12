import XCTest

@MainActor
final class AccessibilityTests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }

  private let fixtureID = "note-00000000-0000-0000-0000-000000000001"
  private func launch(_ scenario: String = "normal", largeText: Bool = false, dark: Bool = false)
    -> XCUIApplication
  {
    let app = XCUIApplication()
    app.launchEnvironment["TRAIL_NOTES_UI_TEST"] = scenario
    app.launchEnvironment["TRAIL_NOTES_APPEARANCE"] = dark ? "dark" : "light"
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    if largeText {
      app.launchArguments += [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
      ]
    }
    app.launch()
    return app
  }
  private func capture(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  private func reveal(_ element: XCUIElement, app: XCUIApplication) {
    for _ in 0..<8 where !element.isHittable { app.swipeUp() }
    XCTAssertTrue(element.isHittable, "Expected reachable element: \(element)")
  }
  private func audit(_ app: XCUIApplication) throws {
    try app.performAccessibilityAudit(for: [
      .textClipped, .sufficientElementDescription, .hitRegion, .contrast,
    ])
  }

  func testSearchAndFavoriteSemantics() throws {
    let app = launch()
    let note = app.buttons[fixtureID]
    XCTAssertTrue(app.buttons["newNote"].waitForExistence(timeout: 10))
    reveal(note, app: app)
    XCTAssertEqual(note.label, "A quiet morning beside the winding river, Willow trail")
    XCTAssertEqual(note.value as? String, "Favorite")
    reveal(note, app: app)
    note.tap()
    let favorite = app.buttons["favoriteNote"]
    XCTAssertTrue(favorite.waitForExistence(timeout: 5))
    XCTAssertEqual(favorite.label, "Remove from favorites")
    XCTAssertEqual(favorite.value as? String, "Favorite")
    favorite.tap()
    XCTAssertEqual(favorite.label, "Add to favorites")
    XCTAssertEqual(favorite.value as? String, "Not a favorite")
    try audit(app)
    capture("detail-default-light", app: app)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let search = app.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 5))
    search.tap()
    search.typeText("No matching fictional note")
    XCTAssertTrue(app.staticTexts["No notes here yet"].waitForExistence(timeout: 5))
    capture("empty-search", app: app)
  }

  func testComposeKeyboardSaveFailureAndRetry() throws {
    let app = launch("save-error")
    XCTAssertTrue(app.buttons["newNote"].waitForExistence(timeout: 10))
    app.typeKey("n", modifierFlags: .command)
    let title = app.textFields["draftTitle"]
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    XCTAssertEqual(title.label, "Title, required")
    XCTAssertFalse(app.buttons["saveNote"].isEnabled)
    title.tap()
    title.typeText("Keyboard note")
    app.typeKey(.tab, modifierFlags: [])
    app.textFields["draftPlace"].typeText("Willow trail")
    XCTAssertEqual(app.textFields["draftPlace"].value as? String, "Willow trail")
    app.typeKey(.tab, modifierFlags: [])
    app.textViews["draftNotes"].typeText("A fictional keyboard-only entry.")
    XCTAssertEqual(app.textViews["draftNotes"].value as? String, "A fictional keyboard-only entry.")
    app.typeKey(.tab, modifierFlags: .shift)
    app.textFields["draftPlace"].typeText(" extension")
    XCTAssertEqual(app.textFields["draftPlace"].value as? String, "Willow trail extension")
    app.typeKey("s", modifierFlags: .command)
    XCTAssertTrue(app.alerts["Could not save"].waitForExistence(timeout: 5))
    capture("save-error-retained-draft", app: app)
    app.alerts.buttons["OK"].tap()
    XCTAssertEqual(title.value as? String, "Keyboard note")
    XCTAssertEqual(app.textViews["draftNotes"].value as? String, "A fictional keyboard-only entry.")
    app.typeKey("s", modifierFlags: .command)
    XCTAssertTrue(app.buttons["newNote"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["saveNote"].waitForNonExistence(timeout: 5))
    app.typeKey("n", modifierFlags: .command)
    XCTAssertTrue(app.buttons["saveNote"].waitForExistence(timeout: 5))
    app.buttons["cancelNote"].tap()
    XCTAssertTrue(app.buttons["saveNote"].waitForNonExistence(timeout: 5))
  }

  func testLoadErrorAndRetry() throws {
    let app = launch("load-error")
    XCTAssertTrue(app.alerts["Journal unavailable"].waitForExistence(timeout: 10))
    capture("load-error", app: app)
    app.alerts.buttons["OK"].tap()
    let retry = app.buttons["retryLoad"]
    reveal(retry, app: app)
    XCTAssertFalse(app.buttons["newNote"].isEnabled)
    retry.tap()
    XCTAssertTrue(app.buttons[fixtureID].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["newNote"].isEnabled)
  }

  func testEditAndDeleteDialogsPreserveTheNote() throws {
    let app = launch()
    let note = app.buttons[fixtureID]
    XCTAssertTrue(app.buttons["newNote"].waitForExistence(timeout: 10))
    reveal(note, app: app)
    note.tap()
    let edit = app.buttons["editNote"]
    reveal(edit, app: app)
    edit.tap()
    XCTAssertTrue(app.textFields["draftTitle"].waitForExistence(timeout: 5))
    XCTAssertEqual(
      app.textFields["draftTitle"].value as? String, "A quiet morning beside the winding river")
    app.buttons["cancelNote"].tap()
    XCTAssertTrue(app.textFields["draftTitle"].waitForNonExistence(timeout: 5))
    XCTAssertTrue(edit.isHittable)
    let delete = app.buttons["deleteNote"]
    reveal(delete, app: app)
    delete.tap()
    XCTAssertTrue(app.alerts["Delete this note?"].waitForExistence(timeout: 5))
    capture("delete-confirmation", app: app)
    app.alerts.buttons["Cancel"].tap()
    XCTAssertTrue(delete.waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["editNote"].exists)
  }

  func testLargestTextInLightAndDark() throws {
    for dark in [false, true] {
      let app = launch(largeText: true, dark: dark)
      XCTAssertTrue(app.buttons["newNote"].waitForExistence(timeout: 10))
      capture("largest-text-list-\(dark ? "dark" : "light")", app: app)
      try audit(app)
      let note = app.buttons[fixtureID]
      reveal(note, app: app)
      capture("largest-text-row-\(dark ? "dark" : "light")", app: app)
      note.tap()
      let favorite = app.buttons["favoriteNote"]
      XCTAssertTrue(app.staticTexts["detailTitle"].waitForExistence(timeout: 5))
      capture("largest-text-detail-top-\(dark ? "dark" : "light")", app: app)
      try audit(app)
      reveal(favorite, app: app)
      capture("largest-text-detail-\(dark ? "dark" : "light")", app: app)
      favorite.tap()
      XCTAssertEqual(favorite.value as? String, "Not a favorite")
      app.navigationBars.buttons.element(boundBy: 0).tap()
      app.buttons["newNote"].tap()
      let title = app.textFields["draftTitle"]
      XCTAssertTrue(title.waitForExistence(timeout: 5))
      title.tap()
      title.typeText("A fictional note at the largest text size")
      app.buttons["Done"].tap()
      XCTAssertTrue(app.buttons["saveNote"].isHittable)
      XCTAssertTrue(app.buttons["Cancel"].isHittable)
      capture("largest-text-compose-\(dark ? "dark" : "light")", app: app)
      try audit(app)
      app.buttons["saveNote"].tap()
      XCTAssertTrue(app.buttons["newNote"].waitForExistence(timeout: 5))
      app.terminate()
    }
  }
}
