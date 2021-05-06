//
//  testConnectApp.swift
//  testConnect WatchKit Extension
//
//  Created by Karl Lellep on 05.04.2021.
//

import SwiftUI

@main
struct testConnectApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView().environmentObject(WorkoutManager())
            }
        }
    }
}
