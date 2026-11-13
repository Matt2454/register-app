import XCTest

final class LaunchTests: XCTestCase {
  private func find(_ query: XCUIElementQuery, _ labels: [String]) -> XCUIElement {
    query.matching(NSPredicate(format: "label IN %@", labels as NSArray)).firstMatch
  }

  private func testMenu(_ app: XCUIApplication) -> XCUIElement {
    find(app.buttons, ["Open navigation menu", "Navigationsmenü öffnen", "Apri il menu di navigazione"])
  }

  private func selectTestLanguage(_ name: String, app: XCUIApplication) {
    let picker = find(app.buttons, ["Sprache", "Language", "Lingua"])
    if !picker.exists {
      testMenu(app).tap()
      app.staticTexts.matching(NSPredicate(format:
        "label BEGINSWITH 'Einstellungen' OR label BEGINSWITH 'Settings' OR label BEGINSWITH 'Impostazioni'")).firstMatch.tap()
    }
    XCTAssertTrue(picker.waitForExistence(timeout: 10), app.debugDescription)
    picker.tap()
    app.buttons[name].firstMatch.tap()
  }

  private func attachScreen(_ name: String, app: XCUIApplication) {
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = name
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  func testLanguageSwitchingPersistsAndWidgetLinksOpenToday() throws {
    #if !targetEnvironment(simulator)
    throw XCTSkip("Language feature tests run only in a disposable simulator.")
    #else
    guard #available(iOS 16.4, *) else { throw XCTSkip("URL testing requires iOS 16.4 or later.") }
    continueAfterFailure = false
    addUIInterruptionMonitor(withDescription: "Demo login permissions") { alert in
      let later = self.find(alert.buttons, ["Not Now", "Jetzt nicht", "Non ora"])
      if later.exists { later.tap(); return true }
      let allow = alert.buttons.matching(NSPredicate(format:
        "(label CONTAINS[c] 'Allow' OR label CONTAINS[c] 'Erlauben' OR label CONTAINS[c] 'Consenti') AND NOT label CONTAINS[c] 'Don' AND NOT label CONTAINS[c] 'Nicht'")).firstMatch
      if allow.exists { allow.tap(); return true }
      return false
    }
    let app = XCUIApplication()
    app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
    app.launch()
    let school = find(app.textFields, ["Schule", "School", "Scuola"])
    if school.waitForExistence(timeout: 5) {
      school.tap(); school.typeText("Vinzentinum\n")
      let username = find(app.textFields, ["Benutzername", "Username", "Nome utente"])
      username.tap(); username.typeText("demo-user-6540\n")
      let plain = find(app.textFields, ["Passwort", "Password"])
      let password = plain.exists ? plain : find(app.secureTextFields, ["Passwort", "Password"])
      password.tap(); app.typeText("demo\n")
      find(app.staticTexts, ["Login", "Sign in", "Accedi"]).tap()
    }
    XCTAssertTrue(testMenu(app).waitForExistence(timeout: 25), app.debugDescription)
    app.tap()
    selectTestLanguage("Italiano", app: app)
    XCTAssertTrue(app.staticTexts["Impostazioni"].waitForExistence(timeout: 10), app.debugDescription)
    app.terminate(); app.launch()
    XCTAssertTrue(app.staticTexts["Oggi"].waitForExistence(timeout: 20), app.debugDescription)
    attachScreen("Today in Italian", app: app)
    selectTestLanguage("English", app: app)
    app.open(URL(string: "register9457://tasks")!)
    XCTAssertTrue(app.staticTexts["Register"].waitForExistence(timeout: 15), app.debugDescription)
    app.open(URL(string: "register9457://today")!)
    XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 15), app.debugDescription)
    attachScreen("Today in English", app: app)
    selectTestLanguage("Deutsch", app: app)
    app.open(URL(string: "register9457://today")!)
    XCTAssertTrue(app.staticTexts["Heute"].waitForExistence(timeout: 15), app.debugDescription)
    attachScreen("Today in German", app: app)
    #endif
  }

  func testZAppleCalendarExportAndDuplicatePrevention() throws {
    #if targetEnvironment(simulator)
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
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
    let menu = testMenu(app)
    XCTAssertTrue(menu.waitForExistence(timeout: 20), app.debugDescription)
    app.tap() // Process the initial notification-permission interruption, if any.
    selectTestLanguage("Deutsch", app: app)
    if #available(iOS 16.4, *) {
      app.open(URL(string: "register9457://calendar")!)
    } else {
      throw XCTSkip("URL testing requires iOS 16.4 or later.")
    }
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
    app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
    app.launch()
    if find(app.textFields, ["Schule", "School", "Scuola"]).waitForExistence(timeout: 5) {
      XCTAssertTrue(find(app.textFields, ["Benutzername", "Username", "Nome utente"]).exists)
      app.scrollViews.firstMatch.swipeUp()
      XCTAssertTrue(find(app.staticTexts, ["Login", "Sign in", "Accedi"]).waitForExistence(timeout: 10))
      XCTAssertTrue(find(app.textFields, ["Passwort", "Password"]).exists)
    } else {
      let menu = testMenu(app)
      XCTAssertTrue(menu.waitForExistence(timeout: 30), app.debugDescription)
    }
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Register running from Xcode"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  func testZZHomeScreenWidgetOpensAppFromColdStart() throws {
    #if !targetEnvironment(simulator)
    throw XCTSkip("Widget placement tests run only in a disposable simulator.")
    #else
    guard #available(iOS 16.4, *) else { throw XCTSkip("Widget automation requires iOS 16.4 or later.") }
    continueAfterFailure = false
    XCUIDevice.shared.press(.home)
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    if springboard.searchFields.firstMatch.exists {
      XCUIDevice.shared.press(.home)
    }
    let previousDone = springboard.buttons["Done"].firstMatch
    if previousDone.exists && previousDone.isHittable { previousDone.tap() }
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(testMenu(app).waitForExistence(timeout: 25), app.debugDescription)
    selectTestLanguage("English", app: app)
    app.open(URL(string: "register9457://today")!)
    XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 15))
    XCUIDevice.shared.press(.home)
    let icon = springboard.icons["Register"].firstMatch
    if !icon.isHittable { springboard.swipeLeft() }
    XCTAssertTrue(icon.waitForExistence(timeout: 10), springboard.debugDescription)
    icon.press(forDuration: 1.5)
    let editHome = springboard.buttons["Edit Home Screen"]
    XCTAssertTrue(editHome.waitForExistence(timeout: 5), springboard.debugDescription)
    editHome.tap()
    let edit = springboard.buttons["Edit"]
    if edit.waitForExistence(timeout: 3) { edit.tap() }
    let add = springboard.buttons["Add Widget"]
    XCTAssertTrue(add.waitForExistence(timeout: 5), springboard.debugDescription)
    add.tap()
    let search = springboard.searchFields.firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 5), springboard.debugDescription)
    search.tap(); search.typeText("Register")
    let row = springboard.cells.matching(NSPredicate(format: "label == 'Register'")).firstMatch
    if row.waitForExistence(timeout: 5) { row.tap() }
    else { springboard.staticTexts["Register"].firstMatch.tap() }
    let addWidget = springboard.buttons.matching(NSPredicate(format: "label CONTAINS 'Add Widget'")).firstMatch
    XCTAssertTrue(addWidget.waitForExistence(timeout: 10), springboard.debugDescription)
    addWidget.tap()
    let done = springboard.buttons["Done"].firstMatch
    if done.waitForExistence(timeout: 5) { done.tap() }
    let visibleWidget = springboard.descendants(matching: .any).matching(NSPredicate(format:
      "label CONTAINS 'Room ' OR label == 'Now' OR label == 'Next' OR label CONTAINS 'Next lesson'")).firstMatch
    XCTAssertTrue(visibleWidget.waitForExistence(timeout: 20), springboard.debugDescription)
    attachScreen("Register Home Screen widget", app: springboard)
    app.terminate()
    visibleWidget.tap()
    let opened = NSPredicate { _, _ in app.state == .runningForeground && app.staticTexts["Today"].exists }
    expectation(for: opened, evaluatedWith: app)
    waitForExpectations(timeout: 25)
    attachScreen("Widget opened Today from cold start", app: app)
    #endif
  }
}
