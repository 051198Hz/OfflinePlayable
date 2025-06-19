//
//  MiniPlayerView.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/12/25.
//
import SwiftUI
import OSLog

struct MiniPlayerView: View {
    private let logger = Logger()
    
    @Bindable var audioPlayer: AudioPlayer
    
    @State private var title: String = "재생 중이 아님"
    @State private var artist: String = ""
    @State private var artwork: UIImage? = nil
    @State private var isPlaying: Bool = false
    @State var uuid = UUID()
    
    var body: some View {
        HStack(spacing: 12) {
            if let image = artwork {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
                    .clipped()
                //                    .matchedGeometryEffect(id: "artwork", in: namespace)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
                //                    .matchedGeometryEffect(id: "artwork", in: namespace)
            }
            
            // 타이틀 & 아티스트
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                //                    .matchedGeometryEffect(id: "title", in: namespace)
                
                Text(artist)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                //                    .matchedGeometryEffect(id: "artist", in: namespace)
                
                // 프로그래스 바
                ProgressView(value: audioPlayer.playbackTime,
                             total: audioPlayer.duration)
                    .id(uuid)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.blue.opacity(0.7))
            }
            
            HStack(spacing: 12) {
                // 재생/일시정지 버튼
                Button {
                    Task {
                        await audioPlayer.isPlaying ? audioPlayer.stop() : audioPlayer.play()
                    }
                } label: {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.primary)
                        .imageScale(.large)
                        .animation(.easeInOut, value: audioPlayer.isPlaying)
                        .accessibilityLabel(audioPlayer.isPlaying ? "일시정지" : "재생")
                }
                .buttonStyle(.plain)
                
                Button {
                    audioPlayer.isRepeating.toggle()
                } label: {
                    Image(systemName: audioPlayer.isRepeating ? "repeat" : "repeat")
                        .foregroundColor(audioPlayer.isRepeating ? .blue.opacity(0.7) : .gray)
                        .imageScale(.large)
                        .animation(.easeInOut, value: audioPlayer.isRepeating)
                        .accessibilityLabel(audioPlayer.isRepeating ? "한 곡 반복 켜짐" : "반복 꺼짐")
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground)) // 원하는 배경색
        )
        .padding(.horizontal)
        .onChange(of: audioPlayer.currentAsset, initial: true) { oldAsset, newAsset  in
            uuid = UUID()
            Task {
                await loadMetadata(from: newAsset)
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
            logger.debug("🔴 메타데이터 로딩 실패: \(error)")
        }
    }
}
