//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct Podcast: Codable, Equatable, Identifiable {
	let id: UUID
	var feedUrl: String
	var name: String
	var artworkUrl: String

	init(
		id: UUID = UUID(),
		feedUrl: String,
		name: String,
		artworkUrl: String
	) {
		self.id = id
		self.feedUrl = feedUrl
		self.name = name
		self.artworkUrl = artworkUrl
	}

	static let empty = Podcast(feedUrl: "", name: "", artworkUrl: "")
}

struct PodcastEpisode: Codable, Hashable, Identifiable {
	let id: String
	var title: String
	var audioUrl: String
	var publishedAt: Date?
	var duration: Double?
	var artworkUrl: String?
}

struct PodcastEpisodeState: Codable, Equatable {
	var episode: PodcastEpisode
	var position: Double
	var isPinned: Bool
	var updatedAt: Date

	static let finishedThreshold: Double = 30

	var isInProgress: Bool { position >= 5 }
}

struct PodcastFeed: Equatable {
	var title: String
	var artworkUrl: String
	var episodes: [PodcastEpisode]
}
