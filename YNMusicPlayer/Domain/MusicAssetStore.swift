//
//  MusicAssetStore.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/12/25.
//

import CoreData
import Observation
import OSLog

@Observable
class MusicAssetStore: @unchecked Sendable {
    @MainActor static let shared = MusicAssetStore()
    private let logger: Logger
    private let persistenceController = PersistenceController.shared
    var musics: [Music] = []
    private var musicModels: [MusicAsset] = []
    
    var selectedMusic = ""
    var selectedMusicAsset: Music?
    
    private init(logger: Logger = Logger()) {
        self.logger = logger
        Task {
            let fetchMusics = loadMusic()
            guard let fetchMusics else { return }
            musicModels = fetchMusics
            musics = fetchMusics.map {
                Music(url: sandBoxURL(fileName: $0.fileName!), originalName: $0.originalName!)
            }
        }
    }
    
    private func loadMusic() -> [MusicAsset]? {
        return persistenceController.loadMusic()
    }
    
    func addMusic(url: URL, extensionString: String? = nil) async {
        guard let (url, originalName) = copyToAppSandbox(originalURL: url, extensionString: extensionString) else { return }
        let music = Music(url: url, originalName: originalName)
        
        guard let musicAsset = persistenceController.addMusic(music) else { return }
        musicModels.append(musicAsset)
        musics.append(music)
    }
    
    func deleteMusic(offsets: IndexSet) async {
        for offset in offsets {
            let music = musicModels[offset]
            guard persistenceController.deleteMusic(music) else { continue }
            musics.remove(at: offset)
            musicModels.remove(at: offset)
        }
    }
    @MainActor
    func nextMusic(at asset: Music) -> Music? {
        guard let currentMusicIndex = musics.firstIndex(of: asset) else { return nil }
        guard currentMusicIndex < musics.count - 1 else { return nil }
        let nextMusic = musics[currentMusicIndex + 1]
        selectedMusic = nextMusic.fileName
        selectedMusicAsset = nextMusic
        return nextMusic
    }
    @MainActor
    func prevMusic(at asset: Music) -> Music? {
        guard let currentMusicIndex = musics.firstIndex(of: asset) else { return nil }
        guard currentMusicIndex > 0 else { return nil }
        let prevMusic = musics[currentMusicIndex - 1]
        selectedMusic = prevMusic.fileName
        selectedMusicAsset = prevMusic
        return prevMusic
    }
    
    func checkSet(_ asset: Music) -> Bool {
        return selectedMusicAsset == asset
    }
}

private extension MusicAssetStore {
    func sandBoxURL(fileName: String) -> URL {
        let sandboxURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        
        return sandboxURL
    }
    
    func copyToAppSandbox(originalURL: URL, extensionString: String?) -> (URL, String)? {

        let fileName = UUID().uuidString + "." + originalURL.pathExtension
        var destinationURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        if let extensionString {
            destinationURL = destinationURL.deletingPathExtension().appendingPathExtension(extensionString)
        }
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: originalURL, to: destinationURL)
            
            logger.debug("✅ 복사 완료: \(destinationURL.lastPathComponent)")
        } catch {
            logger.debug("🔴 복사 실패: \(error.localizedDescription)")
            return nil
        }
        return (destinationURL, originalURL.deletingPathExtension().lastPathComponent)
    }
}
