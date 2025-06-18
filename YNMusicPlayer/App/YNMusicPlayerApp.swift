//
//  YNMusicPlayerApp.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/11/25.
//

import SwiftUI

@main
struct YNMusicPlayerApp: App {
    @State private var store = MusicAssetStore.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView(store: MusicAssetStore.shared)
        }
    }
}
