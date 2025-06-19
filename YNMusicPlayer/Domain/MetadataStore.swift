//
//  MetadataStore.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/12/25.
//
@preconcurrency import AVFoundation
import OSLog

struct AudioMetadata : Sendable {
    let title: String
    let artist: String
    let artwork: Data?
    let duration: Double
}

final class MetadataStore: @unchecked Sendable {
    private let logger: Logger
    static let shared = MetadataStore()

    private var cache: [Music: AudioMetadata] = [:]
    private let queue = DispatchQueue(label: "MetadataCache", attributes: .concurrent)
    
    private init(logger: Logger = Logger()) {
        self.logger = logger
    }
    
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
        async let duration = try await asset.load(.duration).seconds
        let metadata = try await asset.load(.commonMetadata)
        
        let titleTask = Task { @Sendable in
            let titleItem = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: AVMetadataIdentifier.commonIdentifierTitle
            ).first
            
            logger.debug("타이틀 로딩")
            return try await titleItem?.load(.stringValue)
        }

        let artistTask = Task { @Sendable in
            let artistItem = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: AVMetadataIdentifier.commonIdentifierArtist
            ).first
            
            logger.debug("아티스트 로딩")
            return try await artistItem?.load(.stringValue)
        }

        let artworkTask = Task { @Sendable in
            let artworkItem = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: AVMetadataIdentifier.commonIdentifierArtwork
            ).first
            
            logger.debug("아트워크 로딩")
            return try await artworkItem?.load(.dataValue)
        }
        
        return AudioMetadata(
            title: try await titleTask.value ?? alterTitle ?? "Unknown",
            artist: try await artistTask.value ?? "Unknown",
            artwork: try await artworkTask.value,
            duration: try await duration
        )
    }
}
