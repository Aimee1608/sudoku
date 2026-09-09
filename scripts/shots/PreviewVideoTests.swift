import XCTest

/// App 预览录屏的操作脚本。**不在 UITests target 里**,录制时才复制进 UITests/。
/// 配合 `xcrun simctl io <udid> recordVideo` 一起跑,节奏靠 sleep 控制,总长约 23 秒
/// (ASC 要求 15~30 秒)。填的数字是题库第 28 题的正解,硬编码在这里,免得录出满屏红。
final class PreviewVideoTests: XCTestCase {
    private func pause(_ seconds: Double) { Thread.sleep(forTimeInterval: seconds) }

    func testRecordPreview() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-demoProgress", "-themeId", "ocean", "-colorfulDigits", "NO", "-followSystem", "NO",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["size-9"].waitForExistence(timeout: 10))
        pause(2.2)

        app.buttons["size-9"].tap()
        XCTAssertTrue(app.buttons["tab-medium"].waitForExistence(timeout: 5))
        pause(0.9)
        // 必须切到中等档:下面填的是 bank-9-medium 第 28 题的正解,入门档的同号题不是这个盘
        app.buttons["tab-medium"].tap()
        pause(1.0)

        app.buttons["level-27"].tap()
        XCTAssertTrue(app.buttons["tool-提示"].waitForExistence(timeout: 5))
        pause(1.2)

        for (cell, value) in [(0, 8), (6, 6), (11, 6)] {
            app.otherElements["cell-\(cell)"].tap()
            pause(0.35)
            app.buttons["key-\(value)"].tap()
            pause(0.5)
        }

        app.buttons["tool-提示"].tap()
        pause(2.2)

        app.buttons["back"].tap()
        app.buttons["back"].tap()
        XCTAssertTrue(app.buttons["nav-settings"].waitForExistence(timeout: 5))
        app.buttons["nav-settings"].tap()
        XCTAssertTrue(app.switches["toggle-彩色数字"].waitForExistence(timeout: 5))
        pause(0.6)
        app.switches["toggle-彩色数字"].tap()
        pause(0.5)
        app.buttons["theme-deepsea"].tap()
        pause(1.6)

        app.buttons["back"].tap()
        app.buttons["size-4"].tap()
        XCTAssertTrue(app.buttons["level-0"].waitForExistence(timeout: 5))
        pause(0.5)
        app.buttons["level-0"].tap()
        XCTAssertTrue(app.buttons["tool-提示"].waitForExistence(timeout: 5))
        pause(0.9)
        app.buttons["tool-提示"].tap()
        pause(2.2)
    }
}
