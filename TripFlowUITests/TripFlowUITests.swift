//
//  TripFlowUITests.swift
//  TripFlowUITests
//
//  Created by Vu Minh Khoi Ha on 05.07.26.
//

import XCTest

final class TripFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testCapturePortfolioScreenshots() throws {
        let screenshotDirectory = ProcessInfo.processInfo.environment["TRIPFLOW_SCREENSHOT_DIR"]
            ?? "/tmp/tripflow-screenshots-new"

        let app = XCUIApplication()
        app.launchArguments = ["-tripflowDemoData"]
        app.launch()

        let tripTitle = app.staticTexts["Berlin Sommertrip"]
        XCTAssertTrue(tripTitle.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1.5)
        try saveScreenshot(named: "01-trip-list", in: screenshotDirectory)

        tripTitle.tap()

        let hotelStop = app.staticTexts["Hotel Check-in"]
        XCTAssertTrue(hotelStop.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1.0)
        try saveScreenshot(named: "02-trip-detail", in: screenshotDirectory)

        let documentTitle = app.staticTexts["ICE 100 Berlin-Prag"]
        scrollUntilVisible(documentTitle, in: app)
        XCTAssertTrue(documentTitle.waitForExistence(timeout: 4))
        documentTitle.tap()

        let reviewTitle = app.staticTexts["Review"]
        XCTAssertTrue(reviewTitle.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1.0)
        try saveScreenshot(named: "03-document-review", in: screenshotDirectory)

        let createStopSuggestion = app.buttons["Stop daraus erstellen"]
        scrollUntilVisible(createStopSuggestion, in: app)
        XCTAssertTrue(createStopSuggestion.waitForExistence(timeout: 4))
        createStopSuggestion.tap()

        let stopReviewTitle = app.navigationBars["Neuer Stop"]
        XCTAssertTrue(stopReviewTitle.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Vor dem Speichern bearbeiten"].exists)
        let swapDayAndMonth = app.buttons["Tag und Monat tauschen"]
        XCTAssertTrue(swapDayAndMonth.waitForExistence(timeout: 4))
        Thread.sleep(forTimeInterval: 1.0)
        try saveScreenshot(named: "04-stop-review", in: screenshotDirectory)

        swapDayAndMonth.tap()

        XCTAssertTrue(swapDayAndMonth.waitForNonExistence(timeout: 4))

        app.buttons["Erstellen"].tap()

        let savedStop = app.staticTexts["Bahnfahrt ICE100"]
        let backButton = app.navigationBars["ICE 100 Berlin-Prag"].buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 4))
        backButton.tap()

        scrollDownUntilHittable(savedStop, in: app)
        XCTAssertTrue(savedStop.waitForExistence(timeout: 4))
        XCTAssertTrue(savedStop.isHittable)
        Thread.sleep(forTimeInterval: 1.0)
        try saveScreenshot(named: "05-stop-saved", in: screenshotDirectory)
    }

    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication, maxAttempts: Int = 6) {
        var attempts = 0

        while element.exists == false && attempts < maxAttempts {
            app.swipeUp()
            attempts += 1
        }
    }

    private func scrollDownUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxAttempts: Int = 8
    ) {
        var attempts = 0

        while element.isHittable == false && attempts < maxAttempts {
            app.swipeDown()
            attempts += 1
        }
    }

    private func saveScreenshot(named name: String, in directory: String) throws {
        let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let screenshotURL = directoryURL.appendingPathComponent("\(name).png")
        let screenshot = XCUIScreen.main.screenshot()
        try screenshot.pngRepresentation.write(to: screenshotURL, options: .atomic)
    }
}
