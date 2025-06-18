//
//  MetadataStore.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/12/25.
//
import AVFoundation

struct AudioMetadata {
    let title: String
    let artist: String
    let artwork: Data?
    let duration: Double
}

final class MetadataStore: @unchecked Sendable {
    static let shared = MetadataStore()

    private var cache: [Music: AudioMetadata] = [:]
    private let queue = DispatchQueue(label: "MetadataCache", attributes: .concurrent)
    
    private init() { }
    
    func get(for asset: Music) -> AudioMetadata? {
        var result: AudioMetadata?
        queue.sync {
            result = cache[asset]
        }
        return result
    }

    func set(_ data: AudioMetadata, for asset: Music) {
        queue.async(flags: .barrier) {
            self.cache[asset] = data
        }
    }

    func loadIfNeeded(for asset: Music) async throws -> AudioMetadata {
        if let cached = get(for: asset) {
            return cached
        }

        let avasset = AVURLAsset(url: asset.url)
        let metadata = try await fetchMetadata(from: avasset, asset.originalName)
        set(metadata, for: asset)
        return metadata
    }

    private func fetchMetadata(from asset: AVAsset, _ alterTitle: String? = nil) async throws -> AudioMetadata {
        var title: String? = alterTitle
        var artist: String?
        var artwork: Data?
        let durarion = try await asset.load(.duration).seconds

        let metadata = try await asset.load(.commonMetadata)
        
        let titleItems = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: AVMetadataIdentifier.commonIdentifierTitle
        )
        if let item = titleItems.first {
            title = try await item.load(.stringValue)
        }
        
        let artworkItems = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: AVMetadataIdentifier.commonIdentifierArtwork
        )
        if let artworkItem = artworkItems.first {
            artwork = try await artworkItem.load(.dataValue)
        }
        
        let artistItems = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: AVMetadataIdentifier.commonIdentifierArtist
        )
        if let artistItem = artistItems.first {
            artist = try await artistItem.load(.stringValue)
        }
        
        return AudioMetadata(
            title: title ?? "Unknown",
            artist: artist ?? "Unknown",
            artwork: artwork,
            duration: durarion
        )
    }
}
