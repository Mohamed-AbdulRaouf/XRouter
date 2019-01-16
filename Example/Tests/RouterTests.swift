//
//  RouteTransitionTests.swift
//  XRouter_Tests
//
//  Created by Reece Como on 7/1/19.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import XCTest
import UIKit
@testable import XRouter

// swiftlint:disable force_try force_unwrapping
// We are skipping force_try and force_unwrapping for these tests

/**
 Router Tests
 */
class RouterTests: XCTestCase {
    
    /// For making sure our custom error is thrown
    static let routeProviderMockErrorCode = 12345
    
    /// Home view controller
    static let homeViewController = UIViewController()
    
    /// Test routing works as expected when the root view controller is a navigation controller
    func testRoutingWithUINavigationController() {
        // Create initial navigation stack
        let navigationController = UINavigationController(rootViewController: RouterTests.homeViewController)
        let router = MockRouter<TestRoute>(rootViewController: navigationController)
        
        assertRoutingPathsWork(using: router)
    }
    
    /// Test routing works as expected when the root view controller is a tab bar controller
    func testRoutingWithUITabBarController() {
        // Create initial navigation stack
        let tabBarController = UITabBarController()
        let nestedNavigationController = UINavigationController(rootViewController: RouterTests.homeViewController)
        tabBarController.setViewControllers([nestedNavigationController], animated: false)
        
        let router = MockRouter<TestRoute>(rootViewController: tabBarController)
        
        assertRoutingPathsWork(using: router)
        
        navigate(router, to: .secondHomeVC)
        XCTAssertEqual(router.currentRoute!, .secondHomeVC)
        XCTAssertEqual(router.currentRoute!.transition, .set)
    }
    
    /// Test navigate throws an error when the route transition requires a navigation controller, but one is not available
    func testNavigateFailsWhenNoNavigationControllerPresentButIsRequiredByTransition() {
        // Create initial navigation stack with a single tab bar controller containing a view controller
        let tabBarController = UITabBarController()
        tabBarController.setViewControllers([RouterTests.homeViewController], animated: false)
        let router = MockRouter<TestRoute>(rootViewController: tabBarController)
        
        // This will throw an RouterError.missingRequiredNavigationController(for: .push)
        navigateExpectError(router, to: .settingsVC, error: RouterError.missingRequiredNavigationController(for: .push))
    }
    
    /// Test navigate succeeds when the route transition requires a navigation controller, and one is available
    func testNavigateSucceedsNavigationControllerPresentAndIsRequiredByTransition() {
        // Create initial navigation stack
        let tabBarController = UITabBarController()
        let nestedNavigationController = UINavigationController(rootViewController: RouterTests.homeViewController)
        tabBarController.setViewControllers([nestedNavigationController], animated: false)
        
        let router = MockRouter<TestRoute>(rootViewController: tabBarController)
        
        navigate(router, to: .settingsVC)
        XCTAssertEqual(router.currentRoute, .settingsVC)
        XCTAssertEqual(router.currentRoute?.transition, .push)
    }
    
    /// Test that errors thrown in `RouteProvider(_:).prepareForTransition` are passed through to `navigate(to:animated:)`
    func testFowardsErrorsThrownInRouteProviderPrepareForTransition() {
        let router = MockRouter<TestRoute>(rootViewController: UIViewController())
        
        guard let error = navigate(router, to: .alwaysFails, failOnError: false) else {
            XCTFail("Expected error, but none received")
            return
        }
        
        XCTAssertEqual((error as NSError).code, RouterTests.routeProviderMockErrorCode)
    }
    
    /// Test custom transition delegate is triggered
    func testCustomTransitionDelegateIsTriggered() {
        let mockCustomTransitionDelegate = MockRouterCustomTransitionDelegate()
        let router = MockRouter<TestRoute>(rootViewController: UIViewController())
        router.customTransitionDelegate = mockCustomTransitionDelegate
        
        XCTAssertNil(mockCustomTransitionDelegate.lastTransitionPerformed)
        navigate(router, to: .customTransitionVC)
        XCTAssertEqual(mockCustomTransitionDelegate.lastTransitionPerformed, .custom(identifier: "customTransition"))
    }
    
    /// Test
    func testURLRouterFailsSilentlyWhenNoRoutesRegistered() {
        let router = MockRouter<TestRoute>(rootViewController: UIViewController())
        
        try! router.openURL(URL(string: "http://example.com/static/route")!)
        XCTAssertNil(router.currentRoute)
    }
    
    //
    // MARK: - Implementation
    //
    
    /// Assert routing works in current circumstance, given this router
    private func assertRoutingPathsWork(using router: MockRouter<TestRoute>) {
        // Navigate to home view controller (even though we're already there)
        navigate(router, to: .homeVC)
        XCTAssertEqual(router.currentRoute!, .homeVC)
        XCTAssertEqual(router.currentRoute!.transition, .set)
        
        navigate(router, to: .settingsVC)
        XCTAssertEqual(router.currentRoute!, .settingsVC)
        XCTAssertEqual(router.currentRoute!.transition, .push)
        
        navigate(router, to: .nestedModalGroup)
        XCTAssertEqual(router.currentRoute!, .nestedModalGroup)
        XCTAssertEqual(router.currentRoute!.transition, .modal)
        
        // Missing custom navigation delegate
        navigateExpectError(router, to: .customTransitionVC, error: RouterError.missingCustomTransitionDelegate)
        
        // Lets navigate now to a second popover modal before moving back to .home
        navigate(router, to: .nestedModalGroup)
        XCTAssertEqual(router.currentRoute!, .nestedModalGroup)
        XCTAssertEqual(router.currentRoute!.transition, .modal)
        
        navigate(router, to: .singleModalVC)
        XCTAssertEqual(router.currentRoute!, .singleModalVC)
        XCTAssertEqual(router.currentRoute!.transition, .modal)
        
        // Test that going back to a route with a `.set` transition succeeds
        navigate(router, to: .homeVC)
        XCTAssertEqual(router.currentRoute!, .homeVC)
        
        // Test calling a failing/cancelled route does not change the current route
        navigate(router, to: .alwaysFails, failOnError: false)
        XCTAssertEqual(router.currentRoute!, .homeVC)
    }
    
    /// Blocking helper function
    @discardableResult
    func navigate<Route: RouteProvider>(_ router: Router<Route>, to route: Route, failOnError: Bool = true) -> Error? {
        let expectation = self.expectation(description: "Navigate to router")
        var receivedError: Error?
        
        router.navigate(to: route, animated: false) { error in
            receivedError = error
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
        
        if failOnError, let error = receivedError {
            XCTFail("Unexpected error occured: \(error.localizedDescription)")
        }
        
        return receivedError
    }
    
    /// Blocking helper function
    func navigateExpectError<Route: RouteProvider>(_ router: Router<Route>, to route: Route, error expectedError: Error) {
        let actualError = navigate(router, to: route, failOnError: false)
        XCTAssertEqual(actualError?.localizedDescription, expectedError.localizedDescription)
    }
    
}

private enum TestRoute: RouteProvider {
    
    /// Set transition, static omnipresent single view controller
    case homeVC // See `RouterTests.homeViewController`
    
    /// Set transition, single view controller
    case secondHomeVC
    
    /// Push transition, single view controller
    case settingsVC
    
    /// Custom transition, single view controller
    case customTransitionVC
    
    /// Modal transition, single view controller
    case singleModalVC
    
    /// Modal transition, navigation controller with embedded view controller
    case nestedModalGroup
    
    /// *Always cancels transition*
    case alwaysFails
    
    var transition: RouteTransition {
        switch self {
        case .homeVC,
             .secondHomeVC:
            return .set
        case .settingsVC,
             .alwaysFails:
            return .push
        case .nestedModalGroup,
             .singleModalVC:
            return .modal
        case .customTransitionVC:
            return .custom(identifier: "customTransition")
        }
    }
    
    func prepareForTransition(from viewController: UIViewController) throws -> UIViewController {
        switch self {
        case .homeVC,
             .secondHomeVC:
            return RouterTests.homeViewController
        case .settingsVC,
             .singleModalVC,
             .customTransitionVC:
            return UIViewController()
        case .nestedModalGroup:
            return UINavigationController(rootViewController: UIViewController())
        case .alwaysFails:
            throw NSError(domain: "Cancelled route: \(name)", code: RouterTests.routeProviderMockErrorCode, userInfo: nil)
        }
    }
    
}

private class MockRouterCustomTransitionDelegate: RouterCustomTransitionDelegate {
    
    private(set) var lastTransitionPerformed: RouteTransition?
    
    func performTransition(to viewController: UIViewController,
                           from sourceViewController: UIViewController,
                           transition: RouteTransition,
                           animated: Bool,
                           completion: ((Error?) -> Void)?) {
        lastTransitionPerformed = transition
        completion?(nil)
    }
    
}