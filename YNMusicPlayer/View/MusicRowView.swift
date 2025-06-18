//
//  MusicRowView.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/12/25.
//
import SwiftUI

struct MusicRowView: View {
    let asset: Music
    
    @State private var title: String = "불러오는 중..."
    @State private var artist: String = ""
    @State private var artwork: UIImage? = nil

    var body: some View {
        HStack {
            if let image = artwork {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .cornerRadius(6)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .cornerRadius(6)
            }

            VStack(alignment: .leading) {
                Text(title).font(.headline).lineLimit(1)
                Text(artist).font(.caption).foregroundColor(.gray).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle()) // 셀 전체를 터치 및 백그라운드 대상 영역으로 지정
        //이미지때문에 세퍼레이터 밀리는거 방지
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
            dimensions[.leading]
        }
        .task {
            await loadMetadata()
        }
    }

    private func loadMetadata() async {
        do {
            let metadata = try await MetadataStore.shared.loadIfNeeded(for: asset)
            
            title = metadata.title
            artist = metadata.artist
            if let artworkData = metadata.artwork {
                artwork = UIImage(data: artworkData)
            }
        } catch {
            print("Shit")
        }
    }
}
