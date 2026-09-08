import XCTest

final class FlowTests: XCTestCase {
    private func shot(_ app: XCUIApplication, _ name: String) {
        let att = XCTAttachment(screenshot: app.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    func testFullFlow() {
        let app = XCUIApplication()
        // 上一轮跑完的主题/开关会留在 UserDefaults 里,不覆盖的话截图跟步骤对不上
        app.launchArguments += ["-themeId", "ocean", "-colorfulDigits", "NO", "-followSystem", "NO"]
        app.launch()

        app.buttons["size-9"].tap()
        XCTAssertTrue(app.buttons["level-0"].waitForExistence(timeout: 5))
        app.buttons["tab-medium"].tap()
        shot(app, "01-levels")

        app.buttons["level-0"].tap()
        XCTAssertTrue(app.buttons["tool-提示"].waitForExistence(timeout: 5))
        app.otherElements["cell-2"].tap()
        app.buttons["key-4"].tap()
        app.buttons["tool-提示"].tap()
        shot(app, "02-play9")

        app.buttons["tool-笔记"].tap()
        app.otherElements["cell-4"].tap()
        app.buttons["key-1"].tap()
        app.buttons["key-6"].tap()
        app.buttons["key-9"].tap()
        shot(app, "03-notes")

        app.buttons["back"].tap()
        app.buttons["back"].tap()
        XCTAssertTrue(app.buttons["nav-settings"].waitForExistence(timeout: 5))
        app.buttons["nav-settings"].tap()
        XCTAssertTrue(app.switches["toggle-彩色数字"].waitForExistence(timeout: 5))
        app.switches["toggle-彩色数字"].tap()
        shot(app, "04-settings")

        app.buttons["back"].tap()
        app.buttons["size-4"].tap()
        XCTAssertTrue(app.buttons["level-0"].waitForExistence(timeout: 5))
        app.buttons["level-0"].tap()
        XCTAssertTrue(app.buttons["tool-提示"].waitForExistence(timeout: 5))
        app.otherElements["cell-1"].tap()
        app.buttons["key-2"].tap()
        app.buttons["tool-提示"].tap()
        shot(app, "05-play4-colorful")

        app.buttons["back"].tap()
        app.buttons["back"].tap()
        app.buttons["nav-settings"].tap()
        app.buttons["theme-deepsea"].tap()
        app.buttons["back"].tap()
        app.buttons["size-9"].tap()
        app.buttons["level-0"].tap()
        XCTAssertTrue(app.buttons["tool-提示"].waitForExistence(timeout: 5))
        shot(app, "06-deepsea")
    }
}
