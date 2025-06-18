//
//  MusicAsset.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/12/25.
//

import Foundation
import SwiftUI

struct Music: Identifiable, Hashable {
    var id: String { fileName }
    let url: URL
    var fileName: String { url.lastPathComponent }
    let originalName: String
}
