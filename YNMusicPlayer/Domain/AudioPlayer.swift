//
//  AudioPlayer.swift
//  YNMusicPlayer
//
//  Created by Yune gim on 6/11/25.
//

import AVFoundation
import MediaPlayer
import Observation

@Observable
class AudioPlayer {
    private var player: AVPlayer = AVPlayer()
    private var item: AVPlayerItem?
    private var currentItemUrl: URL?
    private var timeObserverToken: Any?
    private var rateObserver: NSKeyValueObservation?
    private var statusObserver: NSKeyValueObservation?
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()
    private let store: MusicAssetStore
    private var shouldObserveProgress = false
    
    var currentAsset: Music?
    var isPlaying: Bool { player.timeControlStatus == .playing }
    var isRepeating: Bool = false
    var isSeeking: Bool = false

    var playbackTime: Double = 0
    var duration: Double = 1
    var loadMetadataTask: Task<Void, Never>?
    
    @MainActor init(store assetStore: MusicAssetStore) {
        self.store = assetStore
        UIApplication.shared.beginReceivingRemoteControlEvents()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        setupAudioSession()
        setupRemoteTransportControls()
    }
    
    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        rateObserver?.invalidate()
        statusObserver?.invalidate()
    }
    
    func set(_ music: Music) {
        shouldObserveProgress = false
        loadMetadataTask?.cancel()
        
        duration = 0
        playbackTime = 0
        
        currentAsset = music
        
        let url = music.url
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        currentItemUrl = url
        self.item = item
        play()

        setInfoCenter(duration: item.duration.seconds)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.shouldObserveProgress = true
        }
    }
    
    func play() {
        if currentAsset == nil {
            guard let asset = store.musics.first else { return }
            set(asset)
        }
        player.play()
    }
    
    func stop() {
        guard currentAsset != nil else { return }
        item = nil
        player.pause()
        updateNowPlayingRate(0)
    }
    
    func seek(to time: Double) {
        isSeeking = true
        let time = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: time) { [weak self] _ in
            self?.isSeeking = false
        }
    }
    
    func playNextMusic() {
        guard let currentAsset, let nextMusic = store.nextMusic(at: currentAsset) else { return }
        set(nextMusic)
    }
    
    func playPrevMusic() {
        guard let currentAsset, let prevMusic = store.prevMusic(at: currentAsset) else { return }
        set(prevMusic)
    }
}

//MARK: - 셋업
private extension AudioPlayer {
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("🔴 Audio session 설정 실패: \(error)")
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
            print("🔁 시크 위치: \(event.positionTime)")
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            self?.playNextMusic()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            self?.playPrevMusic()
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
    
    func setInfoCenter(duration: Double?) {
        infoCenter.nowPlayingInfo = [:]
        updateNowPlayingRate(1)
        loadMetadataTask = Task { [weak self] in
            do {
                guard let currentAsset = self?.currentAsset else { return }
                let metadata = try await MetadataStore.shared.loadIfNeeded(for: currentAsset)
                if Task.isCancelled { return }
                self?.duration = metadata.duration
                self?.infoCenter.nowPlayingInfo![MPMediaItemPropertyArtist] = metadata.artist
                self?.infoCenter.nowPlayingInfo![MPMediaItemPropertyPlaybackDuration] = metadata.duration
                self?.infoCenter.nowPlayingInfo![MPMediaItemPropertyTitle] = metadata.title
                
                if let artworkData = metadata.artwork, let artwork = UIImage(data: artworkData) {
                    self?.infoCenter.nowPlayingInfo![MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
                }
            } catch {
                print("Shit")
            }
        }
    }
}

//Mark: 프로그래스 반영
private extension AudioPlayer {
    func updateNowPlayingRate(_ rate: Float) {
        // 재생속도 설정, 1초에 몇초를 재생할것인지.
        infoCenter.nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = rate
    }
    
    func observeProgress(player: AVPlayer) {
        let interval = CMTime(seconds: 0.2, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let isSeeking = self?.isSeeking, isSeeking == false else { return }
            guard let shouldProgress = self?.shouldObserveProgress, shouldProgress else {
                self?.playbackTime = 0
                return
            }
            self?.playbackTime = self?.isSeeking == true ? self?.playbackTime ?? 0 : time.seconds
            self?.infoCenter.nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = time.seconds
        }
    }
    
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        if let currentItem = player.currentItem {
            currentItem.seek(to: .zero, completionHandler: nil)
            duration = currentItem.duration.seconds
        }
        if isRepeating {
            player.play()
            return
        }
        playNextMusic()
    }
}
