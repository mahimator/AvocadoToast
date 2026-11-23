//
//  AppCoordinatorTests.swift
//  AvocadoToastTests
//
//  Phase 1 · Launch → Navigation → Now Playing open/dismiss
//

import XCTest

@MainActor
final class AppCoordinatorTests: XCTestCase {
    var coordinator: AppCoordinator!

    override func setUp() {
        super.setUp()
        coordinator = AppCoordinator()
    }

    func testNavigateBetweenAllFourTabs() {
        let destinations: [NavigationDestination] = [.home, .search, .library, .settings]
        for destination in destinations {
            coordinator.selection = destination
            XCTAssertEqual(coordinator.selection, destination)
        }
    }

    func testSelectionDefaultsToHome() {
        XCTAssertEqual(coordinator.selection, .home)
    }

    func testNowPlayingOpenAndDismiss() {
        XCTAssertFalse(coordinator.showingNowPlaying)
        coordinator.showingNowPlaying = true
        XCTAssertTrue(coordinator.showingNowPlaying)
        coordinator.showingNowPlaying = false
        XCTAssertFalse(coordinator.showingNowPlaying)
    }

    func testPlaybackStateTransitions() {
        XCTAssertEqual(coordinator.playbackState, .idle)
        coordinator.playbackState = .playing
        XCTAssertEqual(coordinator.playbackState, .playing)
        coordinator.playbackState = .paused
        XCTAssertEqual(coordinator.playbackState, .paused)
        coordinator.playbackState = .idle
        XCTAssertEqual(coordinator.playbackState, .idle)
    }

    func testMiniPlayerVisibility() {
        XCTAssertFalse(coordinator.showMiniPlayer)
        coordinator.showMiniPlayer = true
        XCTAssertTrue(coordinator.showMiniPlayer)
        coordinator.showMiniPlayer = false
        XCTAssertFalse(coordinator.showMiniPlayer)
    }
}
