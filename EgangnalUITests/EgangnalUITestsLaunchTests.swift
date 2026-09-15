//
//  EgangnalUITestsLaunchTests.swift
//  EgangnalUITests
//
//  Created by LBH on 2026/8/2.
//

import XCTest

final class EgangnalUITestsLaunchTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchDarkTheme() throws {
        try verifyLaunch(
            additionalArguments: [],
            expectedAppearance: "深色主题",
            attachmentName: "Launch Dark Theme"
        )
    }

    @MainActor
    func testLaunchLightTheme() throws {
        try verifyLaunch(
            additionalArguments: ["--ui-testing-light-theme"],
            expectedAppearance: "浅色主题",
            attachmentName: "Launch Light Theme"
        )
    }

    @MainActor
    func testLaunchWarmTheme() throws {
        try verifyLaunch(
            additionalArguments: ["--ui-testing-warm-theme"],
            expectedAppearance: "暖纸主题",
            attachmentName: "Launch Warm Theme"
        )
    }

    @MainActor
    private func verifyLaunch(
        additionalArguments: [String],
        expectedAppearance: String,
        attachmentName: String
    ) throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launchArguments.append(contentsOf: additionalArguments)
        app.launch()
        app.activate()

        XCTAssertTrue(
            app.staticTexts["dashboard.title"].waitForExistence(timeout: 3),
            "应用启动后应显示总览工作台"
        )
        XCTAssertEqual(
            app.buttons["dashboard.appearanceToggle"].value as? String,
            expectedAppearance
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = attachmentName
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
