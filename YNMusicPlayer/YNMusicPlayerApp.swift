//
//  YNMusicPlayerApp.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/11/25.
//

import SwiftUI

@main
struct YNMusicPlayerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
