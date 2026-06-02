import XCTest

final class AnkiOpenUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["潮语闪卡"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["开始学习"].exists)
        XCTAssertTrue(app.buttons["导入 CSV"].exists)
        XCTAssertTrue(app.buttons["潮语词典"].exists)
    }
}
