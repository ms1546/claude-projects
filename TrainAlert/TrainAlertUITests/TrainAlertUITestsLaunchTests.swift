//
//  TrainAlertUITestsLaunchTests.swift
//  TrainAlertUITests
//
//  Created by Claude on 2024/01/08.
//

import XCTest

final class TrainAlertUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCTUIApplication()
        app.launch()

        // Insert steps here to perform after the app has launched.
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}