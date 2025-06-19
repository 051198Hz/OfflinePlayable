//
//  AudioPlayer.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/11/25.
//

import MediaPlayer
import Observation
import AVFoundation
import OSLog

@Observable
final class AudioPlayer: @unchecked Sendable {
    private let logger = Logger()
    private var lock = NSLock()
    private let player: AVPlayer = AVPlayer()
    private var timeObserverToken: Any?
    private var rateObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private let commandCenter = MPRemoteCommandCenter.shared()
    private let store: MusicAssetStore
    private var shouldObserveProgress = false
    private var session: MPNowPlayingSession?
    
    var currentAsset: Music?
    var isPlaying: Bool { player.timeControlStatus == .playing }
    var isRepeating: Bool = false
    var isSeeking: Bool = false
    
    var playbackTime: Double = 0
    var duration: Double = 1
    var loadMetadataTask: Task<Void, Never>?
    
    @MainActor
    init(store assetStore: MusicAssetStore) {
        self.store = assetStore
        UIApplication.shared.beginReceivingRemoteControlEvents()
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { notification in
            self.playerDidFinishPlaying(notification)
        }
        setupAudioSession()
        self.session = MPNowPlayingSession(players: [player])
        self.session?.automaticallyPublishesNowPlayingInfo = true
        setupRemoteTransportControls()
    }
    
    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        
        rateObserver?.invalidate()
        statusObserver?.invalidate()
    }
    
    @MainActor
    func set(_ music: Music) async {
        shouldObserveProgress = false
        loadMetadataTask?.cancel()
        
        duration = 0
        playbackTime = 0
        
        currentAsset = music
        
        let url = music.url
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        await setInfoCenter()
        player.replaceCurrentItem(with: item)
        await play()
        shouldObserveProgress = true
    }
    
    func play() async {
        if currentAsset == nil {
            guard let asset = store.musics.first else { return }
            await set(asset)
        }
        player.play()
    }
    
    func stop() {
        guard currentAsset != nil else { return }
        updateNowPlayingRate(0)
        player.pause()
    }
    
    func seek(to time: Double) {
        isSeeking = true
        let time = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: time) { [weak self] _ in
            self?.isSeeking = false
        }
    }
    @MainActor
    func playNextMusic() async {
        guard let currentAsset, let nextMusic = store.nextMusic(at: currentAsset) else { return }
        await set(nextMusic)
    }
    
    @MainActor
    func playPrevMusic() async {
        guard let currentAsset, let prevMusic = store.prevMusic(at: currentAsset) else { return }
        await set(prevMusic)
    }
}

//MARK: - 셋업
private extension AudioPlayer {
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.debug("🔴 Audio session 설정 실패: \(error)")
        }
    }
    
    func setupRemoteTransportControls() {
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.player.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.player.pause()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            
            let time = CMTime(seconds: event.positionTime, preferredTimescale: 600)
            self?.player.seek(to: time)
            self?.logger.debug("🔁 시크 위치: \(event.positionTime)")
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { event in
            Task { @MainActor [weak self] in
                await self?.playNextMusic()
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { event in
            Task { @MainActor [weak self] in
                await self?.playPrevMusic()
            }
            return .success
        }
        
        commandCenter.changeRepeatModeCommand.isEnabled = true
        commandCenter.changeRepeatModeCommand.addTarget { [weak self] event in
            guard let event = (event as? MPChangeRepeatModeCommandEvent) else { return .commandFailed }
            switch event.repeatType {
            case .off:
                self?.isRepeating = false
            case .one:
                self?.isRepeating = true
            case .all:
                return .commandFailed
            @unknown default:
                return .commandFailed
            }
            return .success
        }
        observeProgress(player: player)
    }
    
    @MainActor
    func setInfoCenter() async {
        do {
            guard let currentAsset = self.currentAsset else { return }
            async let metadata = try MetadataStore.shared.loadIfNeeded(for: currentAsset)
            if Task.isCancelled { return }
            self.duration = try await metadata.duration
            
            let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()

            var info = nowPlayingInfoCenter.nowPlayingInfo ?? [String: Any]()

            info[MPMediaItemPropertyArtist] = try await metadata.artist
            info[MPMediaItemPropertyPlaybackDuration] = try await metadata.duration
            info[MPMediaItemPropertyTitle] = try await metadata.title
            updateNowPlayingRate(1)
            if let artworkData = try await metadata.artwork {
                let artwork = transferArtworkImage(artworkData)
                info[MPMediaItemPropertyArtwork] = artwork
            } else {
                info[MPMediaItemPropertyArtwork] = nil
            }
            
            if Task.isCancelled { return }
            
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        } catch {
            logger.debug("🔴 메타데이터 로딩 실패: \(error)")
        }
    }

    private func transferArtworkImage(_ data: Data) -> MPMediaItemArtwork {
        let image = UIImage(data: data)!
        
        return MPMediaItemArtwork(boundsSize: image.size) { _ in
            return image
        }
    }
}

//Mark: 프로그래스 반영
private extension AudioPlayer {
    func updateNowPlayingRate(_ rate: Float) {
        // 재생속도 설정, 1초에 몇초를 재생할것인지.
        let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
        var info = nowPlayingInfoCenter.nowPlayingInfo ?? [String: Any]()
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        
        nowPlayingInfoCenter.nowPlayingInfo = info
    }
    
    func observeProgress(player: AVPlayer) {
        let interval = CMTime(seconds: 0.2, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            guard !self.isSeeking else { return }
            guard self.shouldObserveProgress else {
                self.playbackTime = 0
                return
            }
            
            self.playbackTime = time.seconds
            
            let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()

            var info = nowPlayingInfoCenter.nowPlayingInfo ?? [String: Any]()
            
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time.seconds
            
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
    
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        Task { @MainActor [weak self] in
            
            if let currentItem = self?.player.currentItem {
                currentItem.seek(to: .zero, completionHandler: nil)
                self?.duration = currentItem.duration.seconds
            }
            if let isRepeating = self?.isRepeating, isRepeating {
                self?.player.play()
                return
            }
            
            await self?.playNextMusic()
        }
    }
}
