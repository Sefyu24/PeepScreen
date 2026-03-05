//
//  PeepScreenApp.swift
//  PeepScreen
//
//  Created by Youcef Benabdallah on 2026-03-05.
//

import SwiftUI

@main
struct PeepScreenApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
