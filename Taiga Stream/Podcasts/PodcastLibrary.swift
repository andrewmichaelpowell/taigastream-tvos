//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Combine
import Foundation
import SwiftUI

/// The saved podcasts, their feeds, and where the listener is in each one.
/// Podcasts, the selected episode and playback positions sync through the
/// same iCloud key-value store as the radio stations.
final class PodcastLibrary: ObservableObject {
	static let shared = PodcastLibrary()

	private static let kvs = NSUbiquitousKeyValueStore.default
	private static let podcastsKey = "PodcastsKey"
	private static let statesKey = "PodcastStatesKey"
	private static let positionsKey = "PodcastPositionsKey"
	private static let maxStoredPositions = 300

	private struct StoredPosition: Codable {
		var position: Double
		var updatedAt: Date
	}

	@Published private(set) var podcasts: [Podcast]
	@Published private(set) var feeds: [UUID: PodcastFeed] = [:]
	@Published private(set) var states: [UUID: PodcastEpisodeState]
	@Published private(set) var loadingFeeds = Set<UUID>()
	@Published private(set) var failedFeeds = Set<UUID>()
	private var positions: [String: StoredPosition]
	private var kvsObserver: AnyCancellable?

	private init() {
		podcasts = Self.load([Podcast].self, key: Self.podcastsKey) ?? []
		let storedStates =
			Self.load([String: PodcastEpisodeState].self, key: Self.statesKey)
			?? [:]
		states = Dictionary(
			uniqueKeysWithValues: storedStates.compactMap { key, value in
				UUID(uuidString: key).map { ($0, value) }
			}
		)
		positions =
			Self.load([String: StoredPosition].self, key: Self.positionsKey)
			?? [:]

		kvsObserver = NotificationCenter.default.publisher(
			for: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
			object: Self.kvs
		)
		.receive(on: DispatchQueue.main)
		.sink { [weak self] _ in self?.reloadFromStore() }
	}

	// MARK: Podcasts

	func podcast(at index: Int) -> Podcast {
		podcasts.indices.contains(index) ? podcasts[index] : .empty
	}

	func podcast(id: UUID) -> Podcast? {
		podcasts.first { $0.id == id }
	}

	func number(of id: UUID) -> Int? {
		podcasts.firstIndex { $0.id == id }.map { $0 + 1 }
	}

	func savePodcast(_ podcast: Podcast, at index: Int) {
		guard index >= 0 && index <= podcasts.count else { return }
		var saved: Podcast?
		if podcast.feedUrl.isEmpty {
			guard index < podcasts.count else { return }
			let removed = podcasts.remove(at: index)
			forget(removed.id)
		} else if index == podcasts.count {
			let added = Podcast(
				feedUrl: podcast.feedUrl,
				name: podcast.name,
				artworkUrl: podcast.artworkUrl
			)
			podcasts.append(added)
			saved = added
		} else {
			let previous = podcasts[index]
			let updated = Podcast(
				id: previous.id,
				feedUrl: podcast.feedUrl,
				name: podcast.name,
				artworkUrl: podcast.artworkUrl
			)
			podcasts[index] = updated
			if previous.feedUrl != updated.feedUrl {
				forget(previous.id)
			}
			saved = updated
		}
		persistPodcasts()
		PodcastPlayer.shared.podcastsDidChange()
		if let saved {
			Task { await refreshFeed(for: saved) }
		}
	}

	func clearPodcast(at index: Int) {
		savePodcast(.empty, at: index)
	}

	func movePodcast(from source: IndexSet, to destination: Int) {
		podcasts.move(fromOffsets: source, toOffset: destination)
		persistPodcasts()
		PodcastPlayer.shared.podcastsDidChange()
	}

	private func forget(_ id: UUID) {
		feeds[id] = nil
		failedFeeds.remove(id)
		if states.removeValue(forKey: id) != nil { persistStates() }
		let prefix = "\(id.uuidString)|"
		let before = positions.count
		positions = positions.filter { !$0.key.hasPrefix(prefix) }
		if positions.count != before { persistPositions() }
	}

	// MARK: Feeds

	@discardableResult
	func refreshFeed(for podcast: Podcast) async -> PodcastFeed? {
		guard !podcast.feedUrl.isEmpty else { return nil }
		loadingFeeds.insert(podcast.id)
		defer { loadingFeeds.remove(podcast.id) }
		guard let feed = try? await PodcastFeedParser.fetch(podcast.feedUrl)
		else {
			if feeds[podcast.id] == nil { failedFeeds.insert(podcast.id) }
			return feeds[podcast.id]
		}
		// The podcast may have been removed or re-pointed while loading.
		guard let current = self.podcast(id: podcast.id),
			current.feedUrl == podcast.feedUrl
		else { return nil }
		failedFeeds.remove(podcast.id)
		feeds[podcast.id] = feed
		fillDetails(of: current, from: feed)
		return feed
	}

	func refreshAllFeeds() async {
		await withTaskGroup(of: Void.self) { group in
			for podcast in podcasts {
				group.addTask { await self.refreshFeed(for: podcast) }
			}
		}
	}

	private func fillDetails(of podcast: Podcast, from feed: PodcastFeed) {
		guard let index = podcasts.firstIndex(where: { $0.id == podcast.id })
		else { return }
		var updated = podcasts[index]
		if updated.name.trimmingCharacters(in: .whitespaces).isEmpty,
			!feed.title.isEmpty
		{
			updated.name = feed.title
		}
		if updated.artworkUrl.isEmpty, !feed.artworkUrl.isEmpty {
			updated.artworkUrl = feed.artworkUrl
		}
		guard updated != podcasts[index] else { return }
		podcasts[index] = updated
		persistPodcasts()
	}

	// MARK: Episodes

	/// The episode the play button starts: the one the listener is partway
	/// through or picked by hand, otherwise the newest episode.
	func currentEpisode(for podcast: Podcast) -> PodcastEpisode? {
		if let state = states[podcast.id], state.isPinned || state.isInProgress
		{
			return state.episode
		}
		return feeds[podcast.id]?.episodes.first ?? states[podcast.id]?.episode
	}

	/// Like `currentEpisode(for:)`, but loads the feed first when nothing is
	/// known yet (for example when a control starts a podcast in the
	/// background).
	func resolveEpisode(for podcast: Podcast) async -> PodcastEpisode? {
		if let state = states[podcast.id], state.isPinned || state.isInProgress
		{
			return state.episode
		}
		if feeds[podcast.id] == nil {
			await refreshFeed(for: podcast)
		}
		return currentEpisode(for: podcast)
	}

	func selectEpisode(_ episode: PodcastEpisode, for podcast: Podcast) {
		states[podcast.id] = PodcastEpisodeState(
			episode: episode,
			position: savedPosition(podcastID: podcast.id, episode: episode),
			isPinned: true,
			updatedAt: Date()
		)
		persistStates()
	}

	func savedPosition(podcastID: UUID, episode: PodcastEpisode) -> Double {
		if let state = states[podcastID], state.episode.id == episode.id {
			return state.position
		}
		return positions[positionKey(podcastID, episode.id)]?.position ?? 0
	}

	func recordProgress(
		podcastID: UUID,
		episode: PodcastEpisode,
		position: Double,
		duration: Double?,
		persist: Bool
	) {
		guard podcast(id: podcastID) != nil else { return }
		var stored = episode
		if let duration, duration.isFinite, duration > 0 {
			stored.duration = duration
		}
		let pinned = states[podcastID].map {
			$0.isPinned && $0.episode.id == episode.id
		} ?? false
		states[podcastID] = PodcastEpisodeState(
			episode: stored,
			position: position,
			isPinned: pinned,
			updatedAt: Date()
		)
		positions[positionKey(podcastID, episode.id)] = StoredPosition(
			position: position,
			updatedAt: Date()
		)
		if persist {
			persistStates()
			persistPositions()
		}
	}

	func markFinished(podcastID: UUID, episode: PodcastEpisode) {
		if states[podcastID]?.episode.id == episode.id {
			states[podcastID] = nil
		}
		positions[positionKey(podcastID, episode.id)] = nil
		persistStates()
		persistPositions()
	}

	func progress(podcastID: UUID, episode: PodcastEpisode) -> Double? {
		let position = savedPosition(podcastID: podcastID, episode: episode)
		guard position > 0, let duration = episode.duration, duration > 0
		else { return nil }
		return min(max(position / duration, 0), 1)
	}

	private func positionKey(_ podcastID: UUID, _ episodeID: String) -> String
	{
		"\(podcastID.uuidString)|\(episodeID)"
	}

	// MARK: Persistence

	private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
		guard let data = kvs.data(forKey: key) else { return nil }
		return try? JSONDecoder().decode(type, from: data)
	}

	private static func store<T: Encodable>(_ value: T, key: String) {
		guard let data = try? JSONEncoder().encode(value) else { return }
		kvs.set(data, forKey: key)
		kvs.synchronize()
	}

	private func persistPodcasts() {
		Self.store(podcasts, key: Self.podcastsKey)
	}

	private func persistStates() {
		Self.store(
			Dictionary(
				uniqueKeysWithValues: states.map { ($0.key.uuidString, $0.value) }
			),
			key: Self.statesKey
		)
	}

	private func persistPositions() {
		if positions.count > Self.maxStoredPositions {
			let keep = positions.sorted { $0.value.updatedAt > $1.value.updatedAt }
				.prefix(Self.maxStoredPositions)
			positions = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
		}
		Self.store(positions, key: Self.positionsKey)
	}

	private func reloadFromStore() {
		let stored = Self.load([Podcast].self, key: Self.podcastsKey) ?? []
		if stored != podcasts {
			let newOnes = stored.filter { podcast in
				!podcasts.contains { $0.id == podcast.id && $0.feedUrl == podcast.feedUrl }
			}
			podcasts = stored
			PodcastPlayer.shared.podcastsDidChange()
			for podcast in newOnes {
				Task { await refreshFeed(for: podcast) }
			}
		}
		let storedStates =
			Self.load([String: PodcastEpisodeState].self, key: Self.statesKey)
			?? [:]
		// Take progress from other devices, except for a podcast that is
		// playing right here (this device's position is the live one), and
		// never replace newer local progress with older synced progress.
		let player = PodcastPlayer.shared
		var merged = states
		for (key, value) in storedStates {
			guard let id = UUID(uuidString: key),
				!player.isPlaying(podcastID: id)
			else { continue }
			if let local = merged[id], local.updatedAt > value.updatedAt {
				continue
			}
			merged[id] = value
		}
		for id in merged.keys
		where storedStates[id.uuidString] == nil
			&& !player.isPlaying(podcastID: id)
		{
			merged[id] = nil
		}
		if merged != states { states = merged }
		if let storedPositions = Self.load(
			[String: StoredPosition].self,
			key: Self.positionsKey
		) {
			positions.merge(storedPositions) { local, remote in
				remote.updatedAt > local.updatedAt ? remote : local
			}
		}
		PodcastPlayer.shared.syncedProgressDidChange()
	}
}
