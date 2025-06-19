//
//  YoutubeDownloadView.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/18/25.
//

import SwiftUI
@preconcurrency import YouTubeKit
import OSLog

struct YoutubeDownloadView: View {
    @State var urlInput: String = ""
    
    let store: MusicAssetStore
    let player: AudioPlayer
    
    init(store: MusicAssetStore, player: AudioPlayer) {
        self.store = store
        self.player = player
    }
    
    var body: some View {
        VStack {
            TextEditor(text: $urlInput)
                .scrollContentBackground(.hidden)
                .background(Color(.red))
                .frame(height: 100)
            Button {
                Task {
                    guard let (audioUrl, `extension`) = await toURL(from: urlInput) else { return }
                    guard let tmpUrl = await download(from: audioUrl) else { return }
                    await store.addMusic(url: tmpUrl, extensionString: `extension`.rawValue)
                }
            } label: {
                Label("다운로드", systemImage: "download")
            }
        }
    }
    
    private func toURL(from urlString: String) async -> (URL, FileExtension)?{
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let m4a = try await YouTube(url: url).streams
                .filterAudioOnly()
                .filter { $0.isNativelyPlayable }
                .highestResolutionStream()
            
            guard let m4aUrl = m4a?.url else { return nil }
            os_log(.debug, "\(m4aUrl.absoluteString)")
            
            if let metaData = try await YouTube(url: url).metadata {
                if let thumbnail = metaData.thumbnail {
                    os_log(.debug, "\(thumbnail.url.absoluteString)")
                }
                os_log(.debug, "\(metaData.title)")
                
                let music = Music(url: m4aUrl, originalName: "\(metaData.title)")
                await player.set(music)
            }
            return (m4aUrl, .m4a)
        } catch {
            os_log(.error, "\(error)")
        }
        return nil
    }
    
    private func download(from remoteURL: URL) async -> URL? {
        
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
            return tempURL
        } catch {
            os_log(.error, "\(error)")
        }
        return nil
    }

}
