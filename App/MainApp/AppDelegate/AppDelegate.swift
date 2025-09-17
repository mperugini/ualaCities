//
//  AppDelegate.swift
//  SmartCityExploration
//
//  Created by Mariano Perugini on 1/07/25.
//

import UIKit
import SwiftUI

@main
@MainActor
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    private var appCoordinator: AppCoordinator?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        window = UIWindow(frame: UIScreen.main.bounds)
        
        appCoordinator = AppCoordinator(window: window!)
        appCoordinator?.start()
        
        return true
    }
}
