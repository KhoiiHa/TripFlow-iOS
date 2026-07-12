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

        let documentTitle = app.staticTexts["Hotelbuchung"]
        scrollUntilVisible(documentTitle, in: app)
        XCTAssertTrue(documentTitle.waitForExistence(timeout: 4))
        documentTitle.tap()

        let reviewTitle = app.staticTexts["Review"]
        XCTAssertTrue(reviewTitle.waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1.0)
        try saveScreenshot(named: "03-document-review", in: screenshotDirectory)
    }

    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication, maxAttempts: Int = 6) {
        var attempts = 0

        while element.exists == false && attempts < maxAttempts {
            app.swipeUp()
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
