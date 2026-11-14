//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import AVFoundation
import Combine
import Foundation
import MediaPlayer
import UIKit

final class PodcastPlayer: ObservableObject {
	static let shared = PodcastPlayer()

	static let skipForwardInterval: Double = 30
	static let skipBackwardInterval: Double = 15
	private static let persistEvery = 10

	@Published private(set) var activePodcastID: UUID?
	@Published private(set) var activeEpisode: PodcastEpisode?
	@Published private(set) var position: Double = 0
	@Published private(set) var duration: Double?

	private var timeObserver: Any?
	private var itemCancellables = Set<AnyCancellable>()
	private var ticksSincePersist = 0
	private var artworkCache: [String: UIImage] = [:]
	private var artworkRequestID = 0

	private var streamInfo: StreamInfo { StreamInfo.shared }
	private var library: PodcastLibrary { PodcastLibrary.shared }

	var isActive: Bool { activePodcastID != nil }

	private init() {
		if currentPodcast != 0 { currentPodcast = 0 }
	}

	var currentPodcast: Int {
		get { streamInfo.streamState.integer(forKey: "CurrentPodcastKey") }
		set {
			streamInfo.streamState.set(newValue, forKey: "CurrentPodcastKey")
			streamInfo.streamState.synchronize()
		}
	}

	func isPlaying(podcastNumber: Int) -> Bool {
		isActive && streamInfo.isPlaying && currentPodcast == podcastNumber
	}

	func isPlaying(podcastID: UUID) -> Bool {
		activePodcastID == podcastID && streamInfo.isPlaying
	}

	func play(podcastNumber: Int) async {
		let podcast = library.podcast(at: podcastNumber - 1)
		guard !podcast.feedUrl.isEmpty else { return }
		if activePodcastID == podcast.id {
			if streamInfo.isPlaying {
				pause()
				return
			}
			if let activeEpisode,
				activeEpisode.id == library.currentEpisode(for: podcast)?.id
			{
				await resume()
				return
			}
		}
		guard let episode = await library.resolveEpisode(for: podcast) else {
			return
		}
		await start(episode, of: podcast)
	}

	func play(_ episode: PodcastEpisode, of podcast: Podcast) async {
		if activePodcastID == podcast.id, activeEpisode?.id == episode.id {
			if !streamInfo.isPlaying { await resume() }
			return
		}
		await start(episode, of: podcast)
	}

	private func start(_ episode: PodcastEpisode, of podcast: Podcast) async {
		guard let url = URL(string: episode.audioUrl) else { return }
		saveProgress()
		let data = streamInfo

		data.stopPlaybackHeartbeat()
		data.stopMetadataPolling()
		await PlayStream.shared.prepareSession(mode: .spokenAudio)

		removeItemObservers()
		let item = AVPlayerItem(url: url)
		data.audioPlayer.replaceCurrentItem(with: item)
		data.audioPlayer.audiovisualBackgroundPlaybackPolicy =
			.continuesIfPossible
		data.currentStreamUrl = nil
		data.currentStream = 0

		activePodcastID = podcast.id
		activeEpisode = episode
		currentPodcast = library.number(of: podcast.id) ?? 0
		duration = episode.duration
		var resumeAt = library.savedPosition(
			podcastID: podcast.id,
			episode: episode
		)
		if let known = episode.duration,
			resumeAt >= known - PodcastEpisodeState.finishedThreshold
		{
			resumeAt = 0
		}
		position = resumeAt
		library.recordProgress(
			podcastID: podcast.id,
			episode: episode,
			position: resumeAt,
			duration: duration,
			persist: true
		)

		observe(item)
		enableRemoteCommands(true)
		if resumeAt > 0 {
			_ = await data.audioPlayer.seek(
				to: CMTime(seconds: resumeAt, preferredTimescale: 600),
				toleranceBefore: .zero,
				toleranceAfter: CMTime(seconds: 1, preferredTimescale: 600)
			)
		}
		data.resetKnownNowPlaying()
		updateNowPlaying()
		loadArtwork(for: episode, of: podcast)
		data.audioPlayer.play()
		data.startPlaybackHeartbeat()
	}

	func resume() async {
		guard isActive, streamInfo.audioPlayer.currentItem != nil else {
			return
		}
		if let activePodcastID, let activeEpisode,
			let podcast = library.podcast(id: activePodcastID)
		{
			if let current = library.currentEpisode(for: podcast),
				current.id != activeEpisode.id
			{
				await start(current, of: podcast)
				return
			}
			let synced = library.savedPosition(
				podcastID: activePodcastID,
				episode: activeEpisode
			)
			if abs(synced - position) > 2 {
				position = synced
				_ = await streamInfo.audioPlayer.seek(
					to: CMTime(seconds: synced, preferredTimescale: 600),
					toleranceBefore: .zero,
					toleranceAfter: CMTime(seconds: 1, preferredTimescale: 600)
				)
			}
		}
		await PlayStream.shared.prepareSession(mode: .spokenAudio)
		streamInfo.audioPlayer.play()
		streamInfo.startPlaybackHeartbeat()
		updateNowPlaying()
	}

	func pause() {
		guard isActive else { return }
		streamInfo.audioPlayer.pause()
		streamInfo.stopPlaybackHeartbeat()
		readPosition()
		saveProgress()
		updateNowPlaying()
	}

	func togglePlayPause() async {
		if streamInfo.isPlaying {
			pause()
		} else {
			await resume()
		}
	}

	func skip(by seconds: Double) {
		seek(to: position + seconds)
	}

	func seek(to seconds: Double) {
		guard isActive else { return }
		var target = max(seconds, 0)
		if let duration, duration > 0 { target = min(target, duration - 1) }
		position = target
		streamInfo.audioPlayer.seek(
			to: CMTime(seconds: target, preferredTimescale: 600),
			toleranceBefore: .zero,
			toleranceAfter: .zero
		) { [weak self] _ in
			DispatchQueue.main.async {
				self?.saveProgress()
				self?.updateNowPlaying()
			}
		}
		updateNowPlaying()
	}

	func syncedProgressDidChange() {
		guard let activePodcastID, let activeEpisode, !streamInfo.isPlaying,
			let podcast = library.podcast(id: activePodcastID),
			library.currentEpisode(for: podcast)?.id == activeEpisode.id
		else { return }
		let synced = library.savedPosition(
			podcastID: activePodcastID,
			episode: activeEpisode
		)
		guard abs(synced - position) > 2 else { return }
		position = synced
		streamInfo.audioPlayer.seek(
			to: CMTime(seconds: synced, preferredTimescale: 600),
			toleranceBefore: .zero,
			toleranceAfter: .zero
		)
		updateNowPlaying()
	}

	func deactivate() {
		guard isActive else {
			if currentPodcast != 0 { currentPodcast = 0 }
			return
		}
		readPosition()
		saveProgress()
		removeItemObservers()
		activePodcastID = nil
		activeEpisode = nil
		duration = nil
		position = 0
		currentPodcast = 0
		enableRemoteCommands(false)
	}

	func podcastsDidChange() {
		guard let activePodcastID else { return }
		if let number = library.number(of: activePodcastID) {
			if currentPodcast != number {
				currentPodcast = number
			}
		} else {
			streamInfo.audioPlayer.pause()
			streamInfo.stopPlaybackHeartbeat()
			deactivate()
			streamInfo.audioPlayer.replaceCurrentItem(with: nil)
			MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
		}
	}

	private func observe(_ item: AVPlayerItem) {
		ticksSincePersist = 0
		timeObserver = streamInfo.audioPlayer.addPeriodicTimeObserver(
			forInterval: CMTime(seconds: 1, preferredTimescale: 600),
			queue: .main
		) { [weak self] _ in
			MainActor.assumeIsolated {
				guard let self else { return }
				self.readPosition()
				self.ticksSincePersist += 1
				if self.ticksSincePersist >= Self.persistEvery {
					self.ticksSincePersist = 0
					self.saveProgress()
				}
			}
		}

		item.publisher(for: \.duration)
			.receive(on: DispatchQueue.main)
			.sink { [weak self] value in
				guard let self, value.isNumeric, value.seconds > 0 else {
					return
				}
				if self.duration != value.seconds {
					self.duration = value.seconds
					self.updateNowPlaying()
				}
			}
			.store(in: &itemCancellables)

		streamInfo.audioPlayer.publisher(for: \.timeControlStatus)
			.dropFirst()
			.receive(on: DispatchQueue.main)
			.sink { [weak self] status in
				guard let self, self.isActive, status == .paused else { return }
				self.readPosition()
				self.saveProgress()
				self.updateNowPlaying()
			}
			.store(in: &itemCancellables)

		NotificationCenter.default.publisher(
			for: AVPlayerItem.didPlayToEndTimeNotification,
			object: item
		)
		.receive(on: DispatchQueue.main)
		.sink { [weak self] _ in self?.episodeDidFinish() }
		.store(in: &itemCancellables)
	}

	private func removeItemObservers() {
		if let timeObserver {
			streamInfo.audioPlayer.removeTimeObserver(timeObserver)
		}
		timeObserver = nil
		itemCancellables.removeAll()
	}

	private func readPosition() {
		guard isActive else { return }
		let seconds = streamInfo.audioPlayer.currentTime().seconds
		if seconds.isFinite, seconds >= 0 { position = seconds }
	}

	private func saveProgress() {
		guard let activePodcastID, let activeEpisode else { return }
		if let duration, duration > 0,
			position >= duration - PodcastEpisodeState.finishedThreshold
		{
			library.markFinished(
				podcastID: activePodcastID,
				episode: activeEpisode
			)
			return
		}
		library.recordProgress(
			podcastID: activePodcastID,
			episode: activeEpisode,
			position: position,
			duration: duration,
			persist: true
		)
	}

	private func episodeDidFinish() {
		guard let activePodcastID, let activeEpisode else { return }
		library.markFinished(podcastID: activePodcastID, episode: activeEpisode)
		streamInfo.stopPlaybackHeartbeat()
		streamInfo.isPlaying = false
		position = 0
		streamInfo.audioPlayer.seek(to: .zero)
		updateNowPlaying()
	}

	func updateNowPlaying() {
		guard let activeEpisode, let activePodcastID else { return }
		let podcast = library.podcast(id: activePodcastID)
		let existingArtwork = MPNowPlayingInfoCenter.default().nowPlayingInfo?[
			MPMediaItemPropertyArtwork
		]
		var info = [String: Any]()
		info[MPNowPlayingInfoPropertyIsLiveStream] = false
		info[MPNowPlayingInfoPropertyMediaType] =
			MPNowPlayingInfoMediaType.audio.rawValue
		info[MPMediaItemPropertyTitle] =
			activeEpisode.title.isEmpty
			? (podcast?.name ?? "Taiga Stream") : activeEpisode.title
		info[MPMediaItemPropertyArtist] =
			podcast?.name.isEmpty == false ? podcast?.name : "Taiga Stream"
		info[MPMediaItemPropertyAlbumTitle] = podcast?.name
		info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
		if let duration, duration > 0 {
			info[MPMediaItemPropertyPlaybackDuration] = duration
		}
		info[MPNowPlayingInfoPropertyPlaybackRate] =
			streamInfo.isPlaying ? 1.0 : 0.0
		info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
		if let existingArtwork {
			info[MPMediaItemPropertyArtwork] = existingArtwork
		} else if let icon = streamInfo.appIcon {
			info[MPMediaItemPropertyArtwork] = Self.mediaArtwork(icon)
		}
		MPNowPlayingInfoCenter.default().nowPlayingInfo = info
	}

	private func loadArtwork(for episode: PodcastEpisode, of podcast: Podcast) {
		artworkRequestID += 1
		let requestID = artworkRequestID
		let candidates = [episode.artworkUrl ?? "", podcast.artworkUrl]
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
		guard let urlString = candidates.first, let url = URL(string: urlString)
		else {
			applyArtwork(streamInfo.appIcon)
			return
		}
		if let cached = artworkCache[urlString] {
			applyArtwork(cached)
			return
		}
		applyArtwork(streamInfo.appIcon)
		URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
			let image = data.flatMap { UIImage(data: $0) }
			DispatchQueue.main.async {
				guard let self, let image, self.artworkRequestID == requestID
				else { return }
				self.artworkCache[urlString] = image
				self.applyArtwork(image)
			}
		}.resume()
	}

	private func applyArtwork(_ image: UIImage?) {
		guard let image, isActive else { return }
		streamInfo.showArtwork(image)
		guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo
		else { return }
		info[MPMediaItemPropertyArtwork] = Self.mediaArtwork(image)
		MPNowPlayingInfoCenter.default().nowPlayingInfo = info
	}

	private static func mediaArtwork(_ image: UIImage) -> MPMediaItemArtwork {
		MPMediaItemArtwork(boundsSize: image.size) { requestedSize in
			UIGraphicsImageRenderer(size: requestedSize).image { _ in
				image.draw(in: CGRect(origin: .zero, size: requestedSize))
			}
		}
	}

	private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []

	private func enableRemoteCommands(_ enabled: Bool) {
		let center = MPRemoteCommandCenter.shared()
		for (command, target) in remoteCommandTargets {
			command.removeTarget(target)
		}
		remoteCommandTargets = []
		center.stopCommand.isEnabled = !enabled
		center.skipForwardCommand.preferredIntervals =
			enabled ? [NSNumber(value: Self.skipForwardInterval)] : []
		center.skipBackwardCommand.preferredIntervals =
			enabled ? [NSNumber(value: Self.skipBackwardInterval)] : []
		defer {
			center.skipForwardCommand.isEnabled = enabled
			center.skipBackwardCommand.isEnabled = enabled
			center.changePlaybackPositionCommand.isEnabled = enabled
		}
		guard enabled else { return }

		let forward = center.skipForwardCommand.addTarget { _ in
			guard PodcastPlayer.shared.isActive else { return .commandFailed }
			PodcastPlayer.shared.skip(by: Self.skipForwardInterval)
			return .success
		}
		let backward = center.skipBackwardCommand.addTarget { _ in
			guard PodcastPlayer.shared.isActive else { return .commandFailed }
			PodcastPlayer.shared.skip(by: -Self.skipBackwardInterval)
			return .success
		}
		let scrub = center.changePlaybackPositionCommand.addTarget { event in
			guard PodcastPlayer.shared.isActive,
				let event = event as? MPChangePlaybackPositionCommandEvent
			else { return .commandFailed }
			PodcastPlayer.shared.seek(to: event.positionTime)
			return .success
		}
		remoteCommandTargets = [
			(center.skipForwardCommand, forward),
			(center.skipBackwardCommand, backward),
			(center.changePlaybackPositionCommand, scrub),
		]
	}
}
