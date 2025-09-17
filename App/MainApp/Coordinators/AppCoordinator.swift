//
//  AppCoordinator.swift
//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import UIKit
import SwiftUI

@MainActor
final class AppCoordinator {
    private let window: UIWindow
    private var mainViewController: UIViewController?
    
    init(window: UIWindow) {
        self.window = window
    }
    
    func start() {
        let mainVC = createMainViewController()
        self.mainViewController = mainVC
        
        let navController = UINavigationController(rootViewController: mainVC)
        navController.navigationBar.prefersLargeTitles = true
        
        window.rootViewController = navController
        window.makeKeyAndVisible()
    }
    
    private func createMainViewController() -> UIViewController {
        let citySearchView = CitySearchView()
        let hostingController = UIHostingController(rootView: citySearchView)
        hostingController.title = "Cities"
        
        return hostingController
    }
}
