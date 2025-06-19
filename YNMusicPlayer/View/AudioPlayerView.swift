//
//  AudioPlayerView.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/12/25.
//
import SwiftUI
import OSLog

struct AudioPlayerView: View {
    private let logger = Logger()
    @Bindable var audioPlayer: AudioPlayer
    
    @State private var title: String = "재생 중이 아님"
    @State private var artist: String = ""
    @State private var artwork: UIImage? = nil
    @State private var isShowingFullImage = false
    
    var body: some View {
        GeometryReader { geometry in
            let imageSize = geometry.size.height * 0.6
            
            VStack(spacing: 16) {
                // 앨범 아트
                if let image = artwork {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageSize, height: imageSize)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding(.top, 12)
                        .onTapGesture {
                            isShowingFullImage = true
                        }
                        .contextMenu {
                            Button(action: {
                                UIPasteboard.general.image = image
                            }) {
                                Label("복사", systemImage: "doc.on.doc")
                            }
                            Button(action: {
                                let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                                
                                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let root = scene.windows.first?.rootViewController {
                                    root.topMostViewController.present(activityVC, animated: true)
                                }
                            }) {
                                Label("공유", systemImage: "square.and.arrow.up")
                            }
                        }
                        .sheet(isPresented: $isShowingFullImage) {
                            ImageZoomSheet(image: image)
                        }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: imageSize, height: imageSize)
                        .cornerRadius(12)
                        .padding(.top, 12)
                }
                
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        MarqueeText(text: title)
                            .padding(.horizontal)
                            .bold()
                        
                        Text(artist)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }.padding(.horizontal)
                    
                    HStack {
                        AudioSlider(audioPlayer: $audioPlayer)
                        
                        Button {
                            audioPlayer.isRepeating.toggle()
                        } label: {
                            Image(systemName: "repeat")
                                .font(.system(size: 20))
                                .foregroundColor(audioPlayer.isRepeating ? .blue.opacity(0.7) : .gray)
                        }
                    }
                    .padding(.horizontal)
                    
                    playbackControls
                }
            }
        }
        .onChange(of: audioPlayer.currentAsset, initial: true) { _, newAsset in
            Task {
                await loadMetadata(from: newAsset)
            }
        }
    }
    
    var playbackControls: some View {
        HStack(spacing: 40) {
            Button {
                Task {
                    await audioPlayer.playPrevMusic()
                }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.primary)
            }
            
            Button {
                Task {
                    await audioPlayer.isPlaying ? audioPlayer.stop() : audioPlayer.play()
                }
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.primary)
            }
            
            Button {
                Task {
                    await audioPlayer.playNextMusic()
                }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.primary)
            }
        }
    }
    
    private func loadMetadata(from asset: Music?) async {
        guard let asset else { return }
        do {
            let metadata = try await MetadataStore.shared.loadIfNeeded(for: asset)
            title = metadata.title
            artist = metadata.artist
            if let artworkData = metadata.artwork {
                artwork = UIImage(data: artworkData)
            } else {
                artwork = nil
            }
        } catch {
            logger.debug("Metadata loading error")
        }
    }
}

private struct AudioSlider: View {
    @Binding var duration: Double
    @Binding var playbackTime: Double
    @Bindable var audioPlayer: AudioPlayer
    
    var seek: (Double)->Void
    
    init(audioPlayer: Bindable<AudioPlayer>) {
        self._audioPlayer = audioPlayer
        self._duration = audioPlayer.duration
        self._playbackTime = audioPlayer.playbackTime
        self.seek = audioPlayer.wrappedValue.seek
    }
    
    var body: some View {
        Slider(value: $playbackTime, in: 0...duration) { isEditing in
            audioPlayer.isSeeking = isEditing
            guard !isEditing else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                seek(playbackTime)
            }
        }
        .tint(.blue.opacity(0.7))
    }
}
