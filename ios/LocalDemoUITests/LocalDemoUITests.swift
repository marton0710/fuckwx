import XCTest

@MainActor
final class LocalDemoUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-demo"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.me"].waitForExistence(timeout: 10))
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func replace(_ field: XCUIElement, with text: String) {
        field.tap()
        let old = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + text)
    }

    func testTabLayoutsAndWorkRetry() {
        screenshot("me")
        for tab in ["messages", "docs", "contacts", "work"] {
            app.buttons["tab.\(tab)"].tap()
            XCTAssertTrue(app.buttons["tab.\(tab)"].isHittable)
            screenshot(tab)
        }
        app.buttons["work.item.0.0"].tap()
        let retry = app.buttons["web.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 6))
        XCTAssertTrue(retry.label.contains("ERR_TIMED_OUT"))
        screenshot("work-error")
        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: 6))
    }

    func testProfilePersistsAcrossLaunches() {
        app.buttons["openProfile"].tap()
        app.buttons["profile.name"].tap()
        replace(app.textFields["editor.value"], with: "Tester16")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.buttons["profile.name"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["profile.name"].label.contains("Tester16"))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["openProfile"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["openProfile"].label.contains("Tester16"))
        app.buttons["openProfile"].tap()
        screenshot("profile")
        app.buttons["profile.name"].tap()
        replace(app.textFields["editor.value"], with: "")
        app.buttons["editor.save"].tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts.staticTexts["请输入姓名"].exists)
    }

    func testSettingsUpdateGroupNames() {
        app.buttons["openSettings"].tap()
        replace(app.textViews["settings.groupNames"], with: "Alpha\nBeta")
        app.buttons["settings.save"].tap()
        app.buttons["tab.messages"].tap()
        XCTAssertTrue(app.staticTexts["Alpha"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Beta"].exists)
    }

    func testMemberChatIsMemoryOnly() {
        openFirstMember()
        app.textFields["chat.input"].tap()
        app.textFields["chat.input"].typeText("Local message 16")
        app.buttons["chat.send"].tap()
        XCTAssertTrue(app.staticTexts["Local message 16"].waitForExistence(timeout: 3))
        screenshot("chat-keyboard")
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        openFirstMember()
        XCTAssertFalse(app.staticTexts["Local message 16"].exists)
    }

    private func openFirstMember() {
        XCTAssertTrue(app.buttons["openProfile"].waitForExistence(timeout: 10))
        app.buttons["openProfile"].tap()
        let department = app.buttons["profile.department"]
        for _ in 0..<3 where !department.isHittable { app.swipeUp() }
        department.tap()
        XCTAssertTrue(app.buttons["member.0"].waitForExistence(timeout: 3))
        app.buttons["member.0"].tap()
        XCTAssertTrue(app.textFields["chat.input"].waitForExistence(timeout: 3))
    }
}
