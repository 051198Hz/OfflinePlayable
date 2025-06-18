//
//  YoutubeDownloadView.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/18/25.
//

import SwiftUI
import YouTubeKit
import OSLog

struct YoutubeDownloadView: View {
    @State var urlInput: String = ""
    
    let dg = downloadDelegate()
    let store: MusicAssetStore
    let player: AudioPlayer
    let session: URLSession
    
    init(store: MusicAssetStore, player: AudioPlayer) {
        session = URLSession(configuration: .default, delegate: dg, delegateQueue: nil)
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
                player.set(music)
            }
            return (m4aUrl, .m4a)
        } catch {
            os_log(.error, "\(error)")
        }
        return nil
    }
    
    private func download(from remoteURL: URL) async -> URL? {
        
        do {
            let (tempURL, _) = try await session.download(from: remoteURL, delegate: dg)
            return tempURL
        } catch {
            os_log(.error, "\(error)")
        }
        return nil
    }

}

class downloadDelegate: NSObject {
    let logger = Logger(subsystem: "com.example.app", category: "download")
}

extension downloadDelegate: URLSessionDelegate {
    // this is intentionally blank

    // obviously, if you implement any delegate methods for this protocol, put them here
}

extension downloadDelegate: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        print(#function)
        
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            print(progress)
            logger.debug("📥 다운로드 진행률: \(progress)")
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        print(#function)
    }
}

extension downloadDelegate: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        print(#function, error ?? "No error")
    }
}
