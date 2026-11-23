//
//  AppConfigTests.swift
//  AvocadoToastTests
//
//  Phase 4 · Visual QA · Settings (Glass, themes, Reduce Motion, ambience)
//

import Foundation
import XCTest

@MainActor
final class AppConfigTests: XCTestCase {
    let config = AppConfig.shared

    override func tearDown() {
        // Restore sensible defaults so tests do not leak into one another via UserDefaults.
        config.enableGlassEffects = true
        config.reduceMotion = false
        config.artworkBackgroundEnabled = true
        config.selectedAppearance = .dark
        super.tearDown()
    }

    func testGlassEffectsTogglePersists() {
        XCTAssertTrue(config.enableGlassEffects)
        config.enableGlassEffects = false
        XCTAssertFalse(config.enableGlassEffects)
        config.enableGlassEffects = true
        XCTAssertTrue(config.enableGlassEffects)
    }

    func testReduceMotionTogglePersists() {
        XCTAssertFalse(config.reduceMotion)
        config.reduceMotion = true
        XCTAssertTrue(config.reduceMotion)
        config.reduceMotion = false
        XCTAssertFalse(config.reduceMotion)
    }

    func testArtworkAmbienceTogglePersists() {
        XCTAssertTrue(config.artworkBackgroundEnabled)
        config.artworkBackgroundEnabled = false
        XCTAssertFalse(config.artworkBackgroundEnabled)
        config.artworkBackgroundEnabled = true
        XCTAssertTrue(config.artworkBackgroundEnabled)
    }

    func testAppearanceModes() {
        for appearance in AppConfig.Appearance.allCases {
            config.selectedAppearance = appearance
            XCTAssertEqual(config.selectedAppearance, appearance)
        }
    }
}
