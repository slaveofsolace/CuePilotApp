import XCTest

final class CuePilotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeAndPrimaryDestinations() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["CuePilot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start Live Assist"].exists)
        XCTAssertTrue(app.buttons["Resume Match"].exists)
        XCTAssertTrue(app.buttons["Calibration"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)

        attachScreenshot(named: "Home", app: app)

        app.buttons["Start Live Assist"].tap()
        XCTAssertTrue(
            app.navigationBars["Live Assist Setup"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["1. Start Broadcast"].exists)
        XCTAssertTrue(app.staticTexts["2. Start Picture in Picture"].exists)
        attachScreenshot(named: "Live Assist Setup", app: app)
    }

    @MainActor
    func testSettingsAndPrivacyDetails() {
        let app = launchApp()

        app.buttons["Settings"].tap()
        XCTAssertTrue(
            app.navigationBars["Settings"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["Analysis"].exists)
        XCTAssertTrue(app.staticTexts["On-device only"].exists)

        app.buttons["Privacy Details"].tap()
        XCTAssertTrue(
            app.navigationBars["Privacy"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["No retained recording"].exists)
        attachScreenshot(named: "Privacy", app: app)
    }

    @MainActor
    func testMatchStateControls() {
        let app = launchApp()

        app.buttons["Resume Match"].tap()
        XCTAssertTrue(
            app.navigationBars["Match Session"]
                .waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["YOUR TURN"].exists)
        XCTAssertTrue(app.switches["Your turn"].exists)
        XCTAssertTrue(app.buttons["Return to Live Assist"].exists)
        attachScreenshot(named: "Match Session", app: app)
    }

    @MainActor
    func testCalibrationCorrectionFlow() {
        let app = launchApp()

        app.buttons["Calibration"].tap()
        XCTAssertTrue(
            app.navigationBars["Calibration"].waitForExistence(timeout: 3)
        )
        XCTAssertTrue(app.staticTexts["Calibration"].exists)
        attachScreenshot(named: "Calibration", app: app)
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }

    @MainActor
    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(
            screenshot: app.screenshot()
        )
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
