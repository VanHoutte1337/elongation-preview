//
//  AppDelegate.swift
//  ElongationPreviewDemo
//
//  Created by Abdurahim Jauzee on 08/02/2017.
//  Copyright © 2017 Ramotion. All rights reserved.
//

import ElongationPreview
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        // Add dark view behind the status bar
//        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
//            let view = UIView(frame: UIApplication.shared.statusBarFrame)
//            view.backgroundColor = UIColor.black
//            view.alpha = 0.4
//            self.window?.addSubview(view)
//            self.window?.bringSubview(toFront: view)
//        }

        // Customize ElongationConfig
        var config = ElongationConfig()
        config.scaleViewScaleFactor = 0.9
        config.topViewHeight = 190
        config.bottomViewHeight = 170
        config.bottomViewOffset = 20
        config.parallaxFactor = 100
        config.separatorHeight = 0.5
        config.separatorColor = UIColor.white
        
        config.enableDimmedView = false
        config.containerViewBackgroundColor = .clear
        config.cellPreviewBackgroundColor = .clear

        // Durations for presenting/dismissing detail screen
        config.detailPresentingDuration = 0.4
        config.detailDismissingDuration = 2.0

        // Customize behaviour
        config.headerTouchAction = .collpaseOnBoth

        // Save created appearance object as default
        ElongationConfig.shared = config

        return true
    }
}
