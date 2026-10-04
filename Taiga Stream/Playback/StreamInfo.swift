//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import AVFoundation
import Combine
import Foundation
import MediaPlayer
import SwiftUI

public class StreamInfo: NSObject, ObservableObject {
	static let shared = StreamInfo()
	nonisolated(unsafe) let streamState = UserDefaults(
		suiteName: "group.xyz.andrewmichaelpowell.taigastream"
	)!
	var playerCancellables = Set<AnyCancellable>()
	var sessionCancellables = Set<AnyCancellable>()
	var metadataCancellable: AnyCancellable?
	var playbackHeartbeat: AnyCancellable?
	var currentStreamUrl: URL?
	var appIcon: UIImage? {
		appIconImage()
	}
	private var lastKnownArtist: String = ""
	private var lastKnownTitle: String = ""
	private var lastKnownArtwork: UIImage?
	private var hasRealArtwork = false
	private var artworkRequestID = 0
	private var fallbackRequestID = 0
	private var faviconArtworkCache: [String: UIImage] = [:]
	private var lastPolledTitle: String = ""
	private var lastStreamTitle: String = ""
	private var apiMetadataActive = false
	@Published var nowPlayingArtist: String = ""
	@Published var nowPlayingTitle: String = ""
	@Published var nowPlayingArtwork: UIImage?

	@Published var stations: [RadioStation] = {
		(1...32).map { i in
			let url =
				NSUbiquitousKeyValueStore.default.string(
					forKey: "Stream\(i)Key"
				) ?? ""
			let name =
				NSUbiquitousKeyValueStore.default.string(
					forKey: "StationName\(i)Key"
				) ?? ""
			let favicon =
				NSUbiquitousKeyValueStore.default.string(
					forKey: "StationFavicon\(i)Key"
				) ?? ""
			let idString = NSUbiquitousKeyValueStore.default.string(
				forKey: "StationID\(i)Key"
			)
			let id = idString.flatMap { UUID(uuidString: $0) } ?? UUID()
			return RadioStation(url: url, name: name, faviconUrl: favicon)
		}
	}()

	func moveStation(from source: IndexSet, to destination: Int) {
		stations.move(fromOffsets: source, toOffset: destination)
		stream.move(fromOffsets: source, toOffset: destination)
		for i in 0..<32 {
			NSUbiquitousKeyValueStore.default.set(
				stations[i].id.uuidString,
				forKey: "StationID\(i + 1)Key"
			)
			NSUbiquitousKeyValueStore.default.set(
				stations[i].url,
				forKey: "Stream\(i + 1)Key"
			)
			NSUbiquitousKeyValueStore.default.set(
				stations[i].name,
				forKey: "StationName\(i + 1)Key"
			)
			NSUbiquitousKeyValueStore.default.set(
				stations[i].faviconUrl,
				forKey: "StationFavicon\(i + 1)Key"
			)
		}
		NSUbiquitousKeyValueStore.default.synchronize()
		if isPlaying {
			for i in 0..<32 {
				if stations[i].url == currentStreamUrl?.absoluteString {
					currentStream = i + 1
					break
				}
			}
		}
	}

	func saveStation(_ station: RadioStation, at index: Int) {
		guard index >= 0 && index < 32 else { return }
		let preserved = RadioStation(
			id: stations[index].id,
			url: station.url,
			name: station.name,
			faviconUrl: station.faviconUrl
		)
		stations[index] = preserved
		stream[index] = preserved.url
		NSUbiquitousKeyValueStore.default.set(
			preserved.url,
			forKey: "Stream\(index + 1)Key"
		)
		NSUbiquitousKeyValueStore.default.set(
			preserved.name,
			forKey: "StationName\(index + 1)Key"
		)
		NSUbiquitousKeyValueStore.default.set(
			preserved.faviconUrl,
			forKey: "StationFavicon\(index + 1)Key"
		)
		NSUbiquitousKeyValueStore.default.set(
			preserved.id.uuidString,
			forKey: "StationID\(index + 1)Key"
		)
		NSUbiquitousKeyValueStore.default.synchronize()
	}

	private let metadataProviders: [MetadataProvider] = [
		AudioAddictProvider(),
		StarFMProvider(),
		RTLRadioProvider(),
		SomaFMProvider(),
		BBCRadioProvider(),
		NRKProvider(),
		RadioFranceProvider(),
		ABCRadioProvider(),
		RTERadioProvider(),
		RadioSwissProvider(),
		VirginRadioFranceProvider(),
		VirginRadioRomaniaProvider(),
		VirginRadioOmanProvider(),
		VirginRadioItalyProvider(),
		ZenoFMProvider(),
		VRTRadioProvider(),
		DeutschlandfunkProvider(),
		SverigesRadioProvider(),
		CeskyRozhlasProvider(),
		IcecastProvider(),
	]

	var currentStream: Int {
		get { streamState.integer(forKey: "CurrentStreamKey") }
		set {
			streamState.set(newValue, forKey: "CurrentStreamKey")
			streamState.synchronize()
		}
	}

	func fallbackTitle(forSlot slot: Int) -> String {
		guard slot >= 1, slot <= stations.count else { return "Stream \(slot)" }
		let name = stations[slot - 1].name.trimmingCharacters(in: .whitespaces)
		return name.isEmpty ? "Stream \(slot)" : name
	}

	func resetKnownNowPlaying() {
		lastKnownArtist = ""
		lastKnownTitle = ""
		lastKnownArtwork = nil
		hasRealArtwork = false
		artworkRequestID += 1
		fallbackRequestID += 1
	}

	var isPlaying: Bool {
		get { streamState.bool(forKey: "PlayingKey") }
		set {
			streamState.set(newValue, forKey: "PlayingKey")
			streamState.synchronize()
			objectWillChange.send()
			updatePlaybackState()
		}
	}

	@Published var audioPlayer = AVPlayer()
	@Published var stream: [String] = (1...32).map {
		NSUbiquitousKeyValueStore.default.string(forKey: "Stream\($0)Key") ?? ""
	}

	override init() {
		super.init()
		playerObservers()
		sessionObservers()
		commandCenter()
	}

	private static func deactivateAudioSession() {
		if #available(tvOS 27.0, *) {
			AVAudioSession.sharedInstance().deactivate { _, _ in }
		} else {
			DispatchQueue.global(qos: .userInitiated).async {
				try? AVAudioSession.sharedInstance().setActive(
					false,
					options: .notifyOthersOnDeactivation
				)
			}
		}
	}

	private func commandCenter() {
		let commandCenter = MPRemoteCommandCenter.shared()
		commandCenter.playCommand.isEnabled = true
		commandCenter.playCommand.addTarget { [weak self] _ in
			guard let self else { return .commandFailed }
			self.audioPlayer.play()
			if let streamUrl = self.currentStreamUrl {
				self.startPlaybackHeartbeat()
				self.startMetadataPolling(streamUrl: streamUrl)
				if !self.lastKnownTitle.isEmpty {
					self.updateNowPlaying(
						artist: self.lastKnownArtist,
						title: self.lastKnownTitle
					)
					if let artwork = self.lastKnownArtwork {
						self.applyArtwork(artwork, isReal: self.hasRealArtwork)
					}
				}
			}
			return .success
		}

		commandCenter.stopCommand.isEnabled = true
		commandCenter.stopCommand.addTarget { [weak self] _ in
			self?.audioPlayer.pause()
			self?.stopPlaybackHeartbeat()
			self?.stopMetadataPolling()
			Self.deactivateAudioSession()
			self?.clearNowPlaying()
			return .success
		}

		commandCenter.togglePlayPauseCommand.isEnabled = true
		commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
			guard let self else { return .commandFailed }
			if self.isPlaying {
				self.audioPlayer.pause()
				self.stopPlaybackHeartbeat()
				self.stopMetadataPolling()
				Self.deactivateAudioSession()
				self.clearNowPlaying()
			} else {
				self.audioPlayer.play()
				if let streamUrl = self.currentStreamUrl {
					self.startPlaybackHeartbeat()
					self.startMetadataPolling(streamUrl: streamUrl)
					if !self.lastKnownTitle.isEmpty {
						self.updateNowPlaying(
							artist: self.lastKnownArtist,
							title: self.lastKnownTitle
						)
						if let artwork = self.lastKnownArtwork {
							self.applyArtwork(
								artwork,
								isReal: self.hasRealArtwork
							)
						}
					}
				}
			}
			return .success
		}

		commandCenter.pauseCommand.isEnabled = true
		commandCenter.pauseCommand.addTarget { [weak self] _ in
			guard let self else { return .commandFailed }
			self.audioPlayer.pause()
			self.stopPlaybackHeartbeat()
			self.stopMetadataPolling()
			Self.deactivateAudioSession()
			self.clearNowPlaying()
			return .success
		}

		commandCenter.skipForwardCommand.isEnabled = false
		commandCenter.skipForwardCommand.preferredIntervals = []
		commandCenter.skipBackwardCommand.isEnabled = false
		commandCenter.skipBackwardCommand.preferredIntervals = []
		commandCenter.nextTrackCommand.isEnabled = false
		commandCenter.previousTrackCommand.isEnabled = false
		commandCenter.changePlaybackPositionCommand.isEnabled = false
	}

	func updateNowPlaying(artist: String = "", title: String = "") {
		let existingArtwork = MPNowPlayingInfoCenter.default().nowPlayingInfo?[
			MPMediaItemPropertyArtwork
		]
		var nowPlayingInfo = [String: Any]()
		nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
		nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] =
			isPlaying ? 1.0 : 0.0
		nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
		nowPlayingInfo[MPMediaItemPropertyArtist] =
			artist.isEmpty ? "Taiga Stream" : artist
		nowPlayingInfo[MPMediaItemPropertyTitle] =
			title.isEmpty ? fallbackTitle(forSlot: currentStream) : title
		if let existingArtwork {
			nowPlayingInfo[MPMediaItemPropertyArtwork] = existingArtwork
		}
		MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
		nowPlayingArtist = artist == "Taiga Stream" ? "" : artist
		nowPlayingTitle =
			title.isEmpty ? fallbackTitle(forSlot: currentStream) : title
	}

	private func updatePlaybackState() {
		if var nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo {
			nowPlaying[MPNowPlayingInfoPropertyPlaybackRate] =
				isPlaying ? 1.0 : 0.0
			MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
		} else {
			updateNowPlaying()
		}
	}

	func clearNowPlaying() {
		var stoppedInfo = [String: Any]()
		stoppedInfo[MPNowPlayingInfoPropertyIsLiveStream] = false
		stoppedInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
		stoppedInfo[MPMediaItemPropertyTitle] = fallbackTitle(
			forSlot: self.currentStream
		)
		stoppedInfo[MPMediaItemPropertyArtist] = "Taiga Stream"
		fallbackRequestID += 1
		let requestID = fallbackRequestID
		let faviconString = stationFaviconUrl(forSlot: currentStream)
		let cachedFavicon = faviconString.flatMap { faviconArtworkCache[$0] }
		if let image = cachedFavicon ?? appIconImage() {
			stoppedInfo[MPMediaItemPropertyArtwork] = Self.mediaArtwork(image)
		}
		MPNowPlayingInfoCenter.default().nowPlayingInfo = stoppedInfo
		nowPlayingArtist = ""
		nowPlayingTitle = ""
		nowPlayingArtwork = nil

		guard let faviconString, cachedFavicon == nil else { return }
		loadFaviconArtwork(faviconString) { [weak self] composed in
			guard let self, let composed, self.fallbackRequestID == requestID,
				!self.isPlaying,
				var nowPlayingInfo = MPNowPlayingInfoCenter.default()
					.nowPlayingInfo
			else { return }
			nowPlayingInfo[MPMediaItemPropertyArtwork] = Self.mediaArtwork(
				composed
			)
			MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
		}
	}

	private static func mediaArtwork(_ image: UIImage) -> MPMediaItemArtwork {
		MPMediaItemArtwork(boundsSize: CGSize(width: 600, height: 600)) {
			requestedSize in
			UIGraphicsImageRenderer(size: requestedSize).image { _ in
				image.draw(in: CGRect(origin: .zero, size: requestedSize))
			}
		}
	}

	private func loadFaviconArtwork(
		_ urlString: String,
		completion: @escaping (UIImage?) -> Void
	) {
		guard let url = URL(string: urlString) else {
			completion(nil)
			return
		}
		URLSession.shared.dataTask(with: .noCacheRequest(url: url)) {
			[weak self] data, _, error in
			let composed =
				(error == nil ? data : nil)
				.flatMap { UIImage(data: $0) }
				.flatMap { Self.fallbackArtworkImage(from: $0) }
			DispatchQueue.main.async {
				if let composed {
					self?.faviconArtworkCache[urlString] = composed
				}
				completion(composed)
			}
		}.resume()
	}

	private var icyPollTimer: AnyCancellable?
	private var lastIcyTitle: String = ""

	func startMetadataPolling(streamUrl: URL) {
		stopMetadataPolling()
		lastPolledTitle = ""
		lastStreamTitle = ""
		apiMetadataActive = false

		guard
			let provider = metadataProviders.first(where: {
				$0.matches(streamUrl: streamUrl)
			})
		else { return }

		let aggressiveParsingProviders: [MetadataProvider.Type] = [
			ZenoFMProvider.self
		]

		useAggressiveParsing = aggressiveParsingProviders.contains {
			type(of: provider) == $0
		}

		if provider is IcecastProvider {
			observeMetadata()
		}

		let completion = makeCompletion(for: streamUrl)

		provider.poll(streamUrl: streamUrl, completion: completion)

		guard let interval = provider.pollInterval else { return }
		icyPollTimer = Timer.publish(every: interval, on: .main, in: .common)
			.autoconnect()
			.sink { _ in
				provider.poll(streamUrl: streamUrl, completion: completion)
			}
	}

	private func makeCompletion(for streamUrl: URL) -> (String, String) -> Void
	{
		{ [weak self] artist, title in
			guard let self else { return }
			let combined = "\(artist)|\(title)"
			guard !title.isEmpty, combined != self.lastPolledTitle else {
				return
			}
			self.lastPolledTitle = combined
			self.apiMetadataActive = true

			let resolvedArtist = artist.isEmpty ? "Taiga Stream" : artist
			let resolvedTitle =
				title.isEmpty
				? self.fallbackTitle(forSlot: self.currentStream) : title

			DispatchQueue.main.async {
				self.lastKnownArtist = resolvedArtist
				self.lastKnownTitle = resolvedTitle
				self.updateNowPlaying(
					artist: resolvedArtist,
					title: resolvedTitle
				)
				self.fetchArtwork(artist: resolvedArtist, title: resolvedTitle)
			}
		}
	}

	func stopMetadataPolling() {
		icyPollTimer = nil
		lastPolledTitle = ""
		lastStreamTitle = ""
		apiMetadataActive = false
		useAggressiveParsing = false
	}

	private var metadataOutput: AVPlayerItemMetadataOutput?

	func observeMetadata() {
		if let existingOutput = metadataOutput {
			audioPlayer.currentItem?.remove(existingOutput)
		}
		let output = AVPlayerItemMetadataOutput(identifiers: nil)
		output.setDelegate(self, queue: .main)
		audioPlayer.currentItem?.add(output)
		metadataOutput = output
	}

	func cleanMetadataString(_ input: String) -> String {
		var cleaned = input

		let hostedPlatformPrefixPattern =
			#"(?i)^(visit us at [^\s]+\s*-\s*|\[[^\]]+\]\s*)"#
		if let range = cleaned.range(
			of: hostedPlatformPrefixPattern,
			options: .regularExpression
		) {
			cleaned = String(cleaned[range.upperBound...])
		}

		let isrcPattern = #"\s*-\s*[A-Z][A-Z0-9]{7,11}$"#
		if let range = cleaned.range(
			of: isrcPattern,
			options: .regularExpression
		) {
			cleaned = String(cleaned[cleaned.startIndex..<range.lowerBound])
		}

		let trailingHyphenPattern = #"\s*-\s*$"#
		if let range = cleaned.range(
			of: trailingHyphenPattern,
			options: .regularExpression
		) {
			cleaned = String(cleaned[cleaned.startIndex..<range.lowerBound])
		}

		let bracketedCodePattern = #"\s*\[[A-Za-z0-9]{3,4}\]\s*$"#
		if let range = cleaned.range(
			of: bracketedCodePattern,
			options: .regularExpression
		) {
			cleaned = String(cleaned[cleaned.startIndex..<range.lowerBound])
		}

		while cleaned.contains("  ") {
			cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
		}

		return cleaned.trimmingCharacters(in: .whitespaces)
	}

	func junkMetadata(_ value: String) -> Bool {
		let trimmed = value.trimmingCharacters(in: .whitespaces)

		if trimmed.isEmpty { return true }

		if trimmed.range(
			of: #"title="[^"]*",artist=""#,
			options: .regularExpression
		) != nil {
			return true
		}

		if trimmed.contains("song_spot=") { return true }

		if trimmed.range(
			of: #"^zc\d+$"#,
			options: [.regularExpression, .caseInsensitive]
		) != nil {
			return true
		}

		if trimmed.range(
			of: #"^[a-z0-9]*_[a-z0-9_]+$"#,
			options: [.regularExpression, .caseInsensitive]
		) != nil {
			return true
		}

		if trimmed.contains("://") { return true }
		if trimmed.hasPrefix("/") || trimmed.hasSuffix("/") { return true }
		if trimmed.components(separatedBy: "/").count > 2 { return true }

		if trimmed.range(
			of: #"(?i)(spot\s+block|ad\s+break|commercial\s+break)"#,
			options: .regularExpression
		) != nil {
			return true
		}

		if trimmed.range(
			of: #"\w+\s*=\s*""#,
			options: .regularExpression
		) != nil {
			return true
		}

		return false
	}

	func splitArtistTitle(from raw: String) -> (artist: String, title: String) {
		let separators = [" — ", " – ", " - ", " / ", " · ", " | "]
		for separator in separators {
			let parts = raw.components(separatedBy: separator)
			if parts.count >= 2 {
				let artist = cleanMetadataString(
					parts[0].trimmingCharacters(in: .whitespaces)
				)
				let title = cleanMetadataString(
					parts.dropFirst().joined(separator: separator)
						.trimmingCharacters(in: .whitespaces)
				)
				if !artist.isEmpty && !title.isEmpty {
					return (artist, title)
				}
			}
		}

		return (
			"", cleanMetadataString(raw.trimmingCharacters(in: .whitespaces))
		)
	}

	private var useAggressiveParsing = false

	private func parseMetadata(_ metadataItems: [AVMetadataItem]) {
		guard !apiMetadataActive else { return }
		Task {
			var artist = ""
			var title = ""
			for item in metadataItems {
				if item.commonKey == .commonKeyArtist,
					let value = try? await item.load(.stringValue)
				{
					let cleaned = cleanMetadataString(value)
					artist = junkMetadata(cleaned) ? "" : cleaned
				} else if item.commonKey == .commonKeyTitle,
					let value = try? await item.load(.stringValue)
				{

					if value.contains("title=") && value.contains("artist=") {
					}

					if value.contains("text=") && value.contains("song_spot=") {
						var parsedTitle = ""
						var parsedArtist = ""

						if let textRange = value.range(
							of: #"text="([^"]*)""#,
							options: .regularExpression
						) {
							let match = String(value[textRange])
							parsedTitle =
								match
								.replacingOccurrences(of: "text=\"", with: "")
								.replacingOccurrences(of: "\"", with: "")
								.trimmingCharacters(in: .whitespaces)
						}

						if let separatorRange = value.range(of: " - text=\"") {
							parsedArtist = String(
								value[..<separatorRange.lowerBound]
							)
							.trimmingCharacters(in: .whitespaces)
						}

						if !parsedTitle.isEmpty {
							title = cleanMetadataString(parsedTitle)
							if !parsedArtist.isEmpty {
								artist = cleanMetadataString(parsedArtist)
							}
							continue
						}
					}

					if value.contains("~") {
						let parts = value.components(separatedBy: "~")
							.map { $0.trimmingCharacters(in: .whitespaces) }
						let parsedArtist =
							parts.count > 0 ? cleanMetadataString(parts[0]) : ""
						let parsedTitle =
							parts.count > 1 ? cleanMetadataString(parts[1]) : ""
						if !parsedArtist.isEmpty && !parsedTitle.isEmpty {
							artist =
								junkMetadata(parsedArtist) ? "" : parsedArtist
							title = junkMetadata(parsedTitle) ? "" : parsedTitle
							continue
						}
					}
					let parts = value.components(separatedBy: " - ")
					let isrcPattern = #"^[A-Z][A-Z0-9]{7,11}$"#
					let lastPart =
						parts.last?.trimmingCharacters(in: .whitespaces) ?? ""
					let lastIsIsrc =
						lastPart.range(
							of: isrcPattern,
							options: .regularExpression
						) != nil
					let lastIsEmpty = lastPart.isEmpty

					if lastIsIsrc || lastIsEmpty {
						let cleanParts = parts.dropLast().map {
							$0.trimmingCharacters(in: .whitespaces)
						}
						title = cleanMetadataString(cleanParts.first ?? "")
						artist = cleanMetadataString(
							cleanParts.dropFirst().joined(separator: " - ")
						)
					} else {
						let (parsedArtist, parsedTitle) = splitArtistTitle(
							from: value
						)
						if !parsedArtist.isEmpty {
							artist = parsedArtist
							title = parsedTitle
						} else {
							title =
								parsedTitle.isEmpty
								? cleanMetadataString(value) : parsedTitle
						}
					}
				}

				if junkMetadata(title) { title = "" }
				if junkMetadata(artist) { artist = "" }
			}

			var artistFieldTitle = ""
			if artist.contains(" - ") || artist.contains(" – ")
				|| artist.contains(" — ")
			{
				let (parsedArtist, parsedTitle) = splitArtistTitle(from: artist)
				if !parsedArtist.isEmpty && !parsedTitle.isEmpty {
					artist = parsedArtist
					artistFieldTitle = parsedTitle
				}
			} else if useAggressiveParsing,
				let range = artist.range(
					of: #"\s*-\s*"#,
					options: .regularExpression
				)
			{
				let parsedArtist = cleanMetadataString(
					String(artist[..<range.lowerBound])
				)
				let parsedTitle = cleanMetadataString(
					String(artist[range.upperBound...])
				)
				if !parsedArtist.isEmpty && !parsedTitle.isEmpty {
					artist = parsedArtist
					artistFieldTitle = parsedTitle
				}
			}

			if !artistFieldTitle.isEmpty {
				title = artistFieldTitle
			} else if !artist.isEmpty && !title.isEmpty {
				var separators = [
					" — ", " – ", " - ", " / ", " · ", " | ",
				]

				if useAggressiveParsing {
					separators.append("-")
				}

				for separator in separators {
					guard title.contains(separator) else { continue }
					let parts = title.components(separatedBy: separator)
						.map { $0.trimmingCharacters(in: .whitespaces) }
					guard parts.count > 1 else { continue }

					let firstPart = parts[0]
					let secondPart = parts[1]

					if firstPart.caseInsensitiveCompare(artist) == .orderedSame
					{
						let cleaned = cleanMetadataString(secondPart)
						if !cleaned.isEmpty {
							title = cleaned
							break
						}
					} else {
						let cleaned = cleanMetadataString(firstPart)
						if !cleaned.isEmpty {
							title = cleaned
							break
						}
					}
				}
			}

			let resolvedArtist = artist.isEmpty ? "Taiga Stream" : artist
			let resolvedTitle =
				title.isEmpty ? fallbackTitle(forSlot: currentStream) : title

			await MainActor.run {
				let combined = "\(resolvedArtist)|\(resolvedTitle)"
				guard combined != self.lastStreamTitle else { return }
				self.lastStreamTitle = combined
				self.lastKnownArtist = resolvedArtist
				self.lastKnownTitle = resolvedTitle
				updateNowPlaying(artist: resolvedArtist, title: resolvedTitle)
				fetchArtwork(artist: resolvedArtist, title: resolvedTitle)

			}
		}
	}

	var isFallbackArtworkSet = false

	private func fetchArtwork(artist: String, title: String) {
		artworkRequestID += 1
		let requestID = artworkRequestID

		guard
			artist != "Taiga Stream"
				|| title != fallbackTitle(forSlot: currentStream)
		else {
			if !isFallbackArtworkSet {
				hasRealArtwork = false
				setFallbackArtwork()
				isFallbackArtworkSet = true
			}
			return
		}

		hasRealArtwork = false
		isFallbackArtworkSet = false
		let nowPlayingQuery =
			"\(artist) \(title)"
			.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
			?? ""
		let urlString =
			"https://itunes.apple.com/search?term=\(nowPlayingQuery)&entity=song&limit=1"
		guard let searchUrl = URL(string: urlString) else {
			setFallbackArtwork()
			return
		}

		URLSession.shared.dataTask(with: .noCacheRequest(url: searchUrl)) {
			[weak self] data, _, error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any],
				let results = json["results"] as? [[String: Any]],
				let firstResult = results.first,
				let artworkString = firstResult["artworkUrl100"] as? String
			else {
				self?.useFallbackArtwork(ifRequest: requestID)
				return
			}

			let highResArtworkString = artworkString.replacingOccurrences(
				of: "100x100bb",
				with: "600x600bb"
			)
			guard let artworkUrl = URL(string: highResArtworkString) else {
				self?.useFallbackArtwork(ifRequest: requestID)
				return
			}

			URLSession.shared.dataTask(with: .noCacheRequest(url: artworkUrl)) {
				[weak self] imageData, _, imageError in
				guard let imageData, imageError == nil,
					let artworkImage = UIImage(data: imageData)
				else {
					self?.useFallbackArtwork(ifRequest: requestID)
					return
				}
				DispatchQueue.main.async {
					guard let self, self.artworkRequestID == requestID else {
						return
					}
					self.applyArtwork(artworkImage)
				}
			}.resume()
		}.resume()
	}

	private func useFallbackArtwork(ifRequest requestID: Int) {
		DispatchQueue.main.async { [weak self] in
			guard let self, self.artworkRequestID == requestID else { return }
			self.setFallbackArtwork()
		}
	}

	func applyArtwork(_ image: UIImage, isReal: Bool = true) {
		if isReal {
			hasRealArtwork = true
		} else if hasRealArtwork {
			return
		}
		lastKnownArtwork = image
		nowPlayingArtwork = image
		let artwork = Self.mediaArtwork(image)
		if var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
		{
			nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
			MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
		}
	}

	func setFallbackArtwork() {
		guard !hasRealArtwork else { return }
		fallbackRequestID += 1
		let requestID = fallbackRequestID

		let faviconString = stationFaviconUrl(forSlot: currentStream)
		guard let faviconString, URL(string: faviconString) != nil else {
			applyAppIconFallback()
			return
		}

		if let cached = faviconArtworkCache[faviconString] {
			applyArtwork(cached, isReal: false)
			return
		}

		applyAppIconFallback()

		loadFaviconArtwork(faviconString) { [weak self] composed in
			guard let self, self.fallbackRequestID == requestID,
				!self.hasRealArtwork
			else { return }
			if let composed {
				self.applyArtwork(composed, isReal: false)
			} else {
				self.applyAppIconFallback()
			}
		}
	}

	private func applyAppIconFallback() {
		guard let icon = appIconImage() ?? UIImage(systemName: "radio") else {
			return
		}
		applyArtwork(icon, isReal: false)
	}

	private func stationFaviconUrl(forSlot slot: Int) -> String? {
		guard slot >= 1, slot <= stations.count else { return nil }
		let value = stations[slot - 1].faviconUrl
			.trimmingCharacters(in: .whitespacesAndNewlines)
		return value.isEmpty ? nil : value
	}

	static let transparentIconInset: CGFloat = 0.80
	static let artworkEdgeBleed: CGFloat = 1.05

	private static func fallbackArtworkImage(from source: UIImage) -> UIImage? {
		let side: CGFloat = 600
		guard source.size.width > 0, source.size.height > 0 else { return nil }
		let size = CGSize(width: side, height: side)
		let format = UIGraphicsImageRendererFormat()
		format.scale = 1
		format.opaque = true
		return UIGraphicsImageRenderer(size: size, format: format).image {
			context in
			UIColor.white.setFill()
			context.fill(CGRect(origin: .zero, size: size))
			context.cgContext.interpolationQuality = .high
			let fillScale = max(
				side / source.size.width,
				side / source.size.height
			)
			let fitScale = min(
				side / source.size.width,
				side / source.size.height
			)
			let treatment = faviconTreatment(for: source)
			let scale =
				treatment.needsInset
				? fitScale * Self.transparentIconInset
				: fillScale
					* (treatment.needsBleed ? cornerBleedScale(for: source) : 1)
			let width = source.size.width * scale
			let height = source.size.height * scale
			source.draw(
				in: CGRect(
					x: (side - width) / 2,
					y: (side - height) / 2,
					width: width,
					height: height
				)
			)
		}
	}

	static func isSquare(_ size: CGSize) -> Bool {
		abs(size.width - size.height) <= max(size.width, size.height) * 0.02
	}

	static func faviconTreatment(for image: UIImage) -> (
		needsBackground: Bool, needsInset: Bool, needsBleed: Bool
	) {
		let square = isSquare(image.size)
		let alpha = alphaProfile(of: image)
		let needsInset =
			!square || (alpha.hasTransparency && !alpha.hasOpaqueEdges)
		return (
			needsBackground: needsInset,
			needsInset: needsInset,
			needsBleed: square && alpha.hasTransparency && alpha.hasOpaqueEdges
		)
	}

	static func cornerBleedScale(for image: UIImage) -> CGFloat {
		guard let cgImage = image.cgImage else { return artworkEdgeBleed }
		let side = 128
		var pixels = [UInt8](repeating: 0, count: side * side * 4)
		let drewImage = pixels.withUnsafeMutableBytes { buffer -> Bool in
			guard
				let context = CGContext(
					data: buffer.baseAddress,
					width: side,
					height: side,
					bitsPerComponent: 8,
					bytesPerRow: side * 4,
					space: CGColorSpaceCreateDeviceRGB(),
					bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
				)
			else { return false }
			context.interpolationQuality = .medium
			context.draw(
				cgImage,
				in: CGRect(x: 0, y: 0, width: side, height: side)
			)
			return true
		}
		guard drewImage else { return artworkEdgeBleed }

		let corners = [
			(0, 0, 1, 1), (side - 1, 0, -1, 1),
			(0, side - 1, 1, -1), (side - 1, side - 1, -1, -1),
		]
		var inset = 0
		for (x, y, dx, dy) in corners {
			var step = 0
			while step < side / 2,
				pixels[((y + dy * step) * side + x + dx * step) * 4 + 3] < 128
			{
				step += 1
			}
			inset = max(inset, step)
		}
		let fraction = CGFloat(inset + 1) / CGFloat(side)
		guard fraction < 0.5 else { return artworkEdgeBleed }
		return min(max(0.5 / (0.5 - fraction), artworkEdgeBleed), 1.3)
	}

	private static func alphaProfile(of image: UIImage) -> (
		hasTransparency: Bool, hasOpaqueEdges: Bool
	) {
		guard let cgImage = image.cgImage else { return (false, true) }
		switch cgImage.alphaInfo {
		case .none, .noneSkipFirst, .noneSkipLast: return (false, true)
		default: break
		}
		let width = min(cgImage.width, 64)
		let height = min(cgImage.height, 64)
		var pixels = [UInt8](repeating: 255, count: width * height * 4)
		let drewImage = pixels.withUnsafeMutableBytes { buffer -> Bool in
			guard
				let context = CGContext(
					data: buffer.baseAddress,
					width: width,
					height: height,
					bitsPerComponent: 8,
					bytesPerRow: width * 4,
					space: CGColorSpaceCreateDeviceRGB(),
					bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
				)
			else { return false }
			context.clear(CGRect(x: 0, y: 0, width: width, height: height))
			context.interpolationQuality = .medium
			context.draw(
				cgImage,
				in: CGRect(x: 0, y: 0, width: width, height: height)
			)
			return true
		}
		guard drewImage else { return (false, true) }

		let hasTransparency = stride(from: 3, to: pixels.count, by: 4).contains
		{
			pixels[$0] < 255
		}
		guard hasTransparency else { return (false, true) }

		let xRange = Int(Double(width) * 0.2)..<Int(Double(width) * 0.8)
		let yRange = Int(Double(height) * 0.2)..<Int(Double(height) * 0.8)
		var edgeAlphas = [UInt8]()
		for x in xRange {
			edgeAlphas.append(pixels[x * 4 + 3])
			edgeAlphas.append(pixels[((height - 1) * width + x) * 4 + 3])
		}
		for y in yRange {
			edgeAlphas.append(pixels[y * width * 4 + 3])
			edgeAlphas.append(pixels[(y * width + width - 1) * 4 + 3])
		}
		let edgeOpaque = edgeAlphas.filter { $0 >= 128 }.count
		return (true, edgeOpaque * 10 >= edgeAlphas.count * 9)
	}

	private func appIconImage() -> UIImage? {
		UIImage(named: "FallbackIcon")
	}

	private func playerObservers() {
		playerCancellables.removeAll()

		audioPlayer.publisher(for: \.timeControlStatus)
			.receive(on: DispatchQueue.main)
			.sink { [weak self] status in
				if status == .paused {
					self?.isPlaying = false
				} else if status == .playing {
					self?.isPlaying = true
				}
			}
			.store(in: &playerCancellables)

		audioPlayer.publisher(for: \.currentItem?.status)
			.receive(on: DispatchQueue.main)
			.sink { [weak self] status in
				if status == .failed { self?.isPlaying = false }
			}
			.store(in: &playerCancellables)

		NotificationCenter.default.publisher(
			for: .AVPlayerItemFailedToPlayToEndTime
		)
		.receive(on: DispatchQueue.main)
		.sink { [weak self] _ in self?.isPlaying = false }
		.store(in: &playerCancellables)

		NotificationCenter.default.publisher(for: .AVPlayerItemPlaybackStalled)
			.receive(on: DispatchQueue.main)
			.sink { [weak self] _ in self?.isPlaying = false }
			.store(in: &playerCancellables)
	}

	private func sessionObservers() {
		sessionCancellables.removeAll()

		NotificationCenter.default.publisher(
			for: AVAudioSession.interruptionNotification
		)
		.receive(on: DispatchQueue.main)
		.sink { [weak self] notification in
			guard let userInfo = notification.userInfo,
				let typeValue = userInfo[AVAudioSessionInterruptionTypeKey]
					as? UInt,
				let type = AVAudioSession.InterruptionType(rawValue: typeValue)
			else { return }
			if type == .began {
				self?.isPlaying = false
				self?.audioPlayer.pause()
			}
		}
		.store(in: &sessionCancellables)

		NotificationCenter.default.publisher(
			for: AVAudioSession.silenceSecondaryAudioHintNotification
		)
		.receive(on: DispatchQueue.main)
		.sink { [weak self] notification in
			guard let userInfo = notification.userInfo,
				let typeValue = userInfo[
					AVAudioSessionSilenceSecondaryAudioHintTypeKey
				] as? UInt,
				let type = AVAudioSession.SilenceSecondaryAudioHintType(
					rawValue: typeValue
				)
			else { return }
			if type == .begin {
				self?.isPlaying = false
				self?.audioPlayer.pause()
			}
		}
		.store(in: &sessionCancellables)

		NotificationCenter.default.publisher(
			for: AVAudioSession.routeChangeNotification
		)
		.receive(on: DispatchQueue.main)
		.sink { [weak self] notification in
			guard let userInfo = notification.userInfo,
				let typeValue = userInfo[AVAudioSessionRouteChangeReasonKey]
					as? UInt,
				let type = AVAudioSession.RouteChangeReason(rawValue: typeValue)
			else { return }
			if type == .categoryChange,
				AVAudioSession.sharedInstance()
					.secondaryAudioShouldBeSilencedHint
			{
				self?.isPlaying = false
				self?.audioPlayer.pause()
			}
		}
		.store(in: &sessionCancellables)

		NotificationCenter.default.publisher(
			for: AVAudioSession.mediaServicesWereLostNotification
		)
		.sink { [weak self] _ in
			self?.isPlaying = false
			self?.audioPlayer.pause()
		}
		.store(in: &sessionCancellables)

		NotificationCenter.default.publisher(
			for: AVAudioSession.mediaServicesWereResetNotification
		)
		.sink { [weak self] _ in
			self?.isPlaying = false
			self?.audioPlayer.pause()
		}
		.store(in: &sessionCancellables)
	}

	func startPlaybackHeartbeat() {
		playbackHeartbeat = Timer.publish(every: 1.0, on: .main, in: .common)
			.autoconnect()
			.sink { [weak self] _ in
				guard let self else { return }
				if self.audioPlayer.timeControlStatus != .playing
					&& self.isPlaying
				{
					self.isPlaying = false
				}
			}
	}

	func stopPlaybackHeartbeat() {
		playbackHeartbeat = nil
	}
}

extension StreamInfo: AVPlayerItemMetadataOutputPushDelegate {
	public func metadataOutput(
		_ output: AVPlayerItemMetadataOutput,
		didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
		from track: AVPlayerItemTrack?
	) {
		parseMetadata(groups.flatMap { $0.items })
	}
}
