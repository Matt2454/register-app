import XCTest

final class LaunchTests: XCTestCase {
  func testZAppleCalendarExportAndDuplicatePrevention() throws {
    #if targetEnvironment(simulator)
    continueAfterFailure = false
    let app = XCUIApplication()
    addUIInterruptionMonitor(withDescription: "Expected simulator permissions") { alert in
      if alert.buttons["Not Now"].exists { alert.buttons["Not Now"].tap(); return true }
      let allow = alert.buttons.matching(NSPredicate(format:
        "(label CONTAINS[c] 'Allow' OR label CONTAINS[c] 'Erlauben' OR label CONTAINS[c] 'Add Events' OR label CONTAINS[c] 'Hinzufügen') AND NOT label CONTAINS[c] 'Don' AND NOT label CONTAINS[c] 'Nicht'")).firstMatch
      if allow.exists { allow.tap(); return true }
      return false
    }
    app.launch()
    let school = app.textFields["Schule"]
    if school.waitForExistence(timeout: 5) {
    school.tap()
    school.typeText("Vinzentinum\n")
    let username = app.textFields["Benutzername"]
    username.tap()
    username.typeText("demo-user-6540\n")
    let password = app.textFields["Passwort"].exists ? app.textFields["Passwort"] : app.secureTextFields["Passwort"]
    password.tap()
    app.typeText("demo\n")
    app.staticTexts["Login"].tap()
    }
    let menu = app.buttons.matching(NSPredicate(format: "label == 'Open navigation menu' OR label == 'Navigationsmenü öffnen'")).firstMatch
    XCTAssertTrue(menu.waitForExistence(timeout: 20), app.debugDescription)
    app.tap() // Process the initial notification-permission interruption, if any.
    menu.tap()
    app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Kalender'")).firstMatch.tap()
    let export = app.buttons["In Apple Kalender exportieren"]
    XCTAssertTrue(export.waitForExistence(timeout: 15))

    export.tap()
    XCTAssertTrue(app.staticTexts["In Apple Kalender exportieren"].waitForExistence(timeout: 5))
    app.buttons["Abbrechen"].tap()
    XCTAssertTrue(export.exists)

    func exportWeek() {
      export.tap()
      XCTAssertTrue(app.buttons["Kalender auswählen"].isEnabled, app.debugDescription)
      app.buttons["Kalender auswählen"].tap()
      let permission = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
      if permission.waitForExistence(timeout: 3) {
        print("Calendar permission prompt: \(permission.debugDescription)")
        let allow = permission.buttons.matching(NSPredicate(format:
          "NOT label CONTAINS[c] 'Don' AND NOT label CONTAINS[c] 'Nicht' AND label != 'Cancel'")).firstMatch
        if allow.exists { allow.tap() }
      }
      let done = app.navigationBars.buttons.matching(NSPredicate(format: "label == 'Done' OR label == 'Fertig'")).firstMatch
      XCTAssertTrue(done.waitForExistence(timeout: 15), app.debugDescription)
      if !done.isEnabled { app.tables.cells.firstMatch.tap() }
      done.tap()
    }
    exportWeek()
    let result = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Termine exportiert' AND label CONTAINS 'bereits vorhanden'")).firstMatch
    XCTAssertTrue(result.waitForExistence(timeout: 15), app.debugDescription)
    let firstCounts = result.label.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    XCTAssertEqual(firstCounts.count, 2, result.label)
    let expectedTotal = firstCounts.reduce(0, +)
    XCTAssertGreaterThan(expectedTotal, 0, result.label)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Apple Calendar export result"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    app.buttons["OK"].tap()
    exportWeek()
    XCTAssertTrue(result.waitForExistence(timeout: 10))
    XCTAssertTrue(result.label.hasPrefix("0 Termine exportiert"), result.label)
    XCTAssertTrue(result.label.contains("\(expectedTotal) bereits vorhanden"), result.label)
    app.buttons["OK"].tap()
    #else
    throw XCTSkip("Calendar export tests run only in a disposable simulator.")
    #endif
  }

  func testStandaloneAppLaunches() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launch()
    if app.textFields["Schule"].waitForExistence(timeout: 5) {
      XCTAssertTrue(app.textFields["Benutzername"].exists)
      app.scrollViews.firstMatch.swipeUp()
      XCTAssertTrue(app.staticTexts["Login"].waitForExistence(timeout: 10))
      XCTAssertTrue(app.textFields["Passwort"].exists)
    } else {
      let menu = app.buttons.matching(NSPredicate(format: "label == 'Open navigation menu' OR label == 'Navigationsmenü öffnen'")).firstMatch
      XCTAssertTrue(menu.waitForExistence(timeout: 30), app.debugDescription)
    }
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Register running from Xcode"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
}
