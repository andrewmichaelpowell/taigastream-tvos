//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import AVFoundation
import Foundation

class PlayStream {
	static let shared = PlayStream()

	private func deactivateSession() async {
		let session = AVAudioSession.sharedInstance()
		if #available(tvOS 27.0, *) {
			_ = try? await session.deactivate()
		} else {
			try? session.setActive(false, options: .notifyOthersOnDeactivation)
		}
	}

	private func activateSession() async {
		let session = AVAudioSession.sharedInstance()
		if #available(tvOS 27.0, *) {
			_ = try? await session.activate()
		} else {
			try? session.setActive(true)
		}
	}

	private func startStream(_ streamUrl: URL, streamNumber: Int) async {
		let newStreamItem = AVPlayerItem(url: streamUrl)
		let data = StreamInfo.shared

		await deactivateSession()
		try? AVAudioSession.sharedInstance().setCategory(
			.playback,
			mode: .default,
			options: []
		)
		await activateSession()

		data.audioPlayer.replaceCurrentItem(with: newStreamItem)
		data.audioPlayer.audiovisualBackgroundPlaybackPolicy =
			.continuesIfPossible
		data.currentStream = streamNumber
		data.currentStreamUrl = streamUrl
		data.resetKnownNowPlaying()
		data.isFallbackArtworkSet = false
		data.updateNowPlaying(title: data.fallbackTitle(forSlot: streamNumber))
		data.setFallbackArtwork()
		data.isFallbackArtworkSet = true
		data.observeMetadata()
		data.audioPlayer.play()
		data.startPlaybackHeartbeat()
		data.startMetadataPolling(streamUrl: streamUrl)
	}

	private func playAction(streamUrl: URL, streamNumber: Int) async {
		let data = StreamInfo.shared
		if data.isPlaying && data.currentStream == streamNumber {
			data.audioPlayer.pause()
			data.stopPlaybackHeartbeat()
			data.stopMetadataPolling()
			await deactivateSession()
			data.clearNowPlaying()
		} else {
			await deactivateSession()
			await startStream(streamUrl, streamNumber: streamNumber)
		}
	}

	public func play(streamNumber: Int) async {
		guard let url = URL(string: StreamInfo.shared.stream[streamNumber - 1])
		else { return }
		await playAction(streamUrl: url, streamNumber: streamNumber)
	}
}
