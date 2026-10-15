import XCTest

/// Smoke tests exercise the app's visible mathematical conclusions. Every launch
/// uses an isolated, cleared preference suite with sound and haptics disabled.
final class EulerUITests: XCTestCase {
    @MainActor
    func testFindEShowsNaturalGrowthAndRecordsDiscovery() {
        let app = launch(lab: "grow")
        let hero = app.staticTexts["heroReadout"]
        expectLabel(hero, equals: "2.71828")
        tapAndExpectLabel(app.buttons["reset"], readout: hero, equals: "1.00000", in: app)
        expectLabel(app.staticTexts["growthTimeValue"], equals: "0.00")

        tapAndExpectLabel(app.buttons["findE"], readout: hero, equals: "2.71828", in: app)

        let observation = app.staticTexts["observation"]
        reveal(observation, in: app)
        XCTAssertTrue(observation.label.contains("One time unit at k = 1"))
        XCTAssertTrue(observation.label.contains("2.71828"))
        expectDiscovery("One unit. Exactly e.", in: app)

        app.tabBars.buttons["Discoveries"].tap()
        expectLabel(app.staticTexts["discoveryCount"], equals: "1 / 9")
    }

    @MainActor
    func testVerticalPageScrollOverGrowthPlotPreservesTime() {
        let app = launch(lab: "grow")
        let hero = app.staticTexts["heroReadout"]
        let time = app.staticTexts["growthTimeValue"]
        expectLabel(hero, equals: "2.71828")
        expectLabel(time, equals: "1.00")

        // Ordinary center-origin swipes begin over the interactive growth plot.
        // They must scroll the page instead of scrubbing time or blocking scroll.
        let page = app.scrollViews.firstMatch
        page.swipeUp()
        page.swipeUp()

        let findE = app.buttons["findE"]
        let reachable = NSPredicate(format: "exists == true AND hittable == true")
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: reachable, object: findE)],
            timeout: 5
        )
        XCTAssertEqual(result, .completed, "Vertical swipes over the plot must reveal the lower controls.")
        expectLabel(time, equals: "1.00")
        expectLabel(hero, equals: "2.71828")
    }

    @MainActor
    func testHalfTurnReachesEulerIdentity() {
        let app = launch(lab: "rotate")

        tap(app.buttons["angleDetent2"], in: app)

        expectLabel(app.staticTexts["heroReadout"], equals: "1.00π")
        let observation = app.staticTexts["observation"]
        reveal(observation, in: app)
        XCTAssertTrue(observation.label.contains("A half-turn lands at −1"))
        XCTAssertTrue(observation.label.contains("eⁱπ + 1 = 0"))
        expectDiscovery("Five constants. One half-turn.", in: app)
    }

    @MainActor
    func testTwelfthSemitoneDoublesPitchWithSoundInitiallyOff() {
        let app = launch(lab: "tune")
        expectLabel(app.staticTexts["heroReadout"], equals: "220.0")

        app.scrollViews["pianoKeyboard"].swipeLeft()
        tap(app.buttons["pianoKey12"], in: app)

        expectLabel(app.staticTexts["heroReadout"], equals: "440.0")
        let sound = app.switches["soundToggle"]
        reveal(sound, in: app)
        XCTAssertEqual(sound.value as? String, "0", "UI test launches must remain silent.")
        let observation = app.staticTexts["observation"]
        reveal(observation, in: app)
        XCTAssertTrue(observation.label.contains("12 semitones"))
        XCTAssertTrue(observation.label.contains("2.00000"))
        expectDiscovery("Twelve steps. Twice the pitch.", in: app)
    }

    @MainActor
    func testHatBatchCountsActualTrialsAndSeparatesFiniteChanceFromLimit() {
        let app = launch(lab: "shuffle")
        let crowd = app.steppers["hatCount"]
        reveal(crowd, in: app)
        let decrement = app.buttons["hatCount-Decrement"]
        XCTAssertTrue(decrement.waitForExistence(timeout: 5))
        // Three participants have an exact 1/3 no-match chance, visibly different
        // from the asymptotic 1/e limit. Changing n must clear previous trials.
        for expected in stride(from: 7, through: 3, by: -1) {
            tapAndExpectLabel(decrement, readout: app.staticTexts["heroReadout"], equals: "\(expected)", in: app)
        }

        app.buttons["batchShuffles"].tap()

        let observation = app.staticTexts["observation"]
        reveal(observation, in: app)
        XCTAssertTrue(observation.label.contains("of 100 shuffles"))
        XCTAssertTrue(observation.label.contains("finite-crowd chance is 33.33%"))
        XCTAssertTrue(observation.label.contains("measured result will fluctuate"))
        let exact = readout(containing: "EXACT", and: "33.33%", in: app)
        let limit = readout(containing: "LIMIT", and: "36.79%", in: app)
        XCTAssertTrue(exact.exists, "Show the exact finite-crowd probability separately.")
        XCTAssertTrue(limit.exists, "Show the 1/e limit separately.")
        expectDiscovery("The shuffled-hat surprise.", in: app)

        app.buttons["reset"].tap()
        expectLabel(app.staticTexts["heroReadout"], equals: "3")
        XCTAssertTrue(app.staticTexts["observation"].label.contains("hats begin with their owners"))
    }

    @MainActor
    func testBellBatchCollectsFiveHundredSumsAndRecordsDiscovery() {
        let app = launch(lab: "bell")
        expectLabel(app.staticTexts["heroReadout"], equals: "0")

        app.buttons["batchSamples"].tap()

        expectLabel(app.staticTexts["heroReadout"], equals: "500")
        let observation = app.staticTexts["observation"]
        reveal(observation, in: app)
        XCTAssertTrue(observation.label.contains("12 independent small surprises"))
        XCTAssertTrue(observation.label.contains("measured density"))
        XCTAssertTrue(observation.label.contains("ideal normal density"))
        expectDiscovery("Randomness has a shape.", in: app)

        app.buttons["reset"].tap()
        expectLabel(app.staticTexts["heroReadout"], equals: "0")
    }

    @MainActor
    func testCompoundingApproachesEThroughFiveHundredTwelveSteps() {
        let app = launch(lab: "compound")
        let hero = app.staticTexts["heroReadout"]
        expectLabel(hero, equals: "2.44141")
        let steps = app.staticTexts["compoundStepsValue"]
        reveal(steps, in: app)
        expectLabel(steps, equals: "4")

        // A tap changes the state and re-renders the controls. Wait for the
        // visible step counter after each action instead of sending seven taps
        // while those updates are still in flight.
        for expected in [8, 16, 32, 64, 128, 256, 512] {
            tapAndExpectLabel(app.buttons["primaryAction"], readout: steps, equals: "\(expected)", in: app)
        }

        expectLabel(hero, equals: "2.71563")
        let amount = Double(hero.label)
        XCTAssertNotNil(amount)
        if let amount {
            XCTAssertGreaterThan(amount, 2.715)
            XCTAssertLessThan(amount, 2.71828)
            XCTAssertLessThan(2.71828 - amount, 0.003)
        }
        let observation = app.staticTexts["observation"]
        reveal(observation, in: app)
        XCTAssertTrue(observation.label.contains("512 reinvestments"))
        XCTAssertTrue(observation.label.contains("gap to e is 0.00265"))
        expectDiscovery("Small steps become e.", in: app)
    }

    @MainActor
    func testConnectionsOpensSelectedExperimentInPlay() {
        let app = launch(lab: "grow")
        app.buttons["chooseExperiment"].tap()

        let rotation = app.buttons["connection_rotate"]
        tap(rotation, in: app)

        expectLabel(app.staticTexts["experimentTitle"], equals: "Imaginary turns")
        XCTAssertTrue(app.buttons["angleDetent2"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["findE"].exists)
    }

    @MainActor
    private func launch(lab: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--lab", lab,
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
        ]
        app.launch()
        XCTAssertTrue(app.staticTexts["heroReadout"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    private func expectLabel(
        _ element: XCUIElement,
        equals expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let condition = NSPredicate(format: "exists == true AND label == %@", expected)
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: condition, object: element)],
            timeout: 5
        )
        XCTAssertEqual(result, .completed, "Expected \(expected); found \(element.label)", file: file, line: line)
    }

    @MainActor
    private func reveal(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<7 {
            if element.isHittable { break }
            // The circle has a two-dimensional drag gesture. Start outside the
            // plot in the scroll view's left gutter so scrolling remains a
            // scroll, rather than changing the mathematical parameter.
            let lowerGutter = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.75))
            let upperGutter = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.25))
            lowerGutter.press(forDuration: 0.05, thenDragTo: upperGutter)
        }
        XCTAssertTrue(element.isHittable, "Element should be reachable by scrolling.", file: file, line: line)
    }

    @MainActor
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        reveal(element, in: app)
        let ready = NSPredicate(format: "exists == true AND enabled == true AND hittable == true")
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: ready, object: element)],
            timeout: 5
        )
        XCTAssertEqual(result, .completed, "Control must be enabled and hittable before tapping.")
        element.tap()
    }

    @MainActor
    private func tapAndExpectLabel(
        _ button: XCUIElement,
        readout: XCUIElement,
        equals expected: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        tap(button, in: app)
        expectLabel(readout, equals: expected, file: file, line: line)
    }

    @MainActor
    private func expectDiscovery(_ title: String, in app: XCUIApplication) {
        let banner = app.descendants(matching: .any).matching(identifier: "discoveryBanner").firstMatch
        let detail = app.staticTexts[title]
        reveal(detail, in: app)
        XCTAssertTrue(banner.exists, "The discovery should appear in its dedicated banner.")
    }

    @MainActor
    private func readout(containing first: String, and second: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", first, second)
        ).firstMatch
    }
}
