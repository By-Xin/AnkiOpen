import XCTest

final class AnkiOpenUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Notebooks"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Study"].exists)
        XCTAssertTrue(app.tabBars.buttons["Import"].exists)
        XCTAssertTrue(app.tabBars.buttons["Dictionary"].exists)
    }
}
