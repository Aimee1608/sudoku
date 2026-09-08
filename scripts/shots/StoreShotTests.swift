import XCTest

/// 上架截图。这个文件**不在 UITests target 里**,平时不会跑;要出图时复制进
/// UITests/ 跑一次,导出后删掉:
///
///   cp scripts/shots/StoreShotTests.swift UITests/
///   xcodebuild -project Sudoku.xcodeproj -scheme Sudoku \
///     -destination 'id=<模拟器UDID>' -resultBundlePath /tmp/store.xcresult test
///   xcrun xcresulttool export attachments --path /tmp/store.xcresult --output-path /tmp/storeshots
///   rm UITests/StoreShotTests.swift
final class StoreShotTests: XCTestCase {
    private func shot(_ app: XCUIApplication, _ name: String) {
        let att = XCTAttachment(screenshot: app.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    private func launch(colorful: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-demoProgress",
            "-themeId", "ocean",
            "-colorfulDigits", colorful ? "YES" : "NO",
            "-followSystem", "NO",
        ]
        app.launch()
        return app
    }

    func testStoreScreens() {
        var app = launch(colorful: false)
        XCTAssertTrue(app.buttons["size-9"].waitForExistence(timeout: 8))
        shot(app, "1-home")

        app.buttons["size-9"].tap()
        XCTAssertTrue(app.buttons["tab-medium"].waitForExistence(timeout: 5))
        app.buttons["tab-medium"].tap()
        shot(app, "2-levels")

        app.buttons["level-27"].tap()
        XCTAssertTrue(app.buttons["tool-提示"].waitForExistence(timeout: 5))
        app.buttons["tool-提示"].tap()
        shot(app, "3-play9")

        app.terminate()

        app = launch(colorful: true)
        XCTAssertTrue(app.buttons["size-4"].waitForExistence(timeout: 8))
        app.buttons["size-4"].tap()
        XCTAssertTrue(app.buttons["level-3"].waitForExistence(timeout: 5))
        app.buttons["level-3"].tap()
        XCTAssertTrue(app.buttons["tool-提示"].waitForExistence(timeout: 5))
        app.buttons["tool-提示"].tap()
        shot(app, "4-play4")

        app.buttons["back"].tap()
        app.buttons["back"].tap()
        XCTAssertTrue(app.buttons["nav-settings"].waitForExistence(timeout: 5))
        app.buttons["nav-settings"].tap()
        XCTAssertTrue(app.buttons["theme-mocha"].waitForExistence(timeout: 5))
        shot(app, "5-themes")

        app.buttons["back"].tap()
        app.buttons["nav-stats"].tap()
        XCTAssertTrue(app.staticTexts["已完成的题目"].waitForExistence(timeout: 5))
        shot(app, "6-stats")
    }
}
