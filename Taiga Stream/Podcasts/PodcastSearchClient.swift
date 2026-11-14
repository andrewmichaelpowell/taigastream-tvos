//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct PodcastSearchResult: Identifiable, Decodable, Equatable {
	let id: Int
	let name: String
	let author: String
	let feedUrl: String
	let artworkUrl: String
	let genre: String

	private enum CodingKeys: String, CodingKey {
		case collectionId, collectionName, artistName, feedUrl
		case artworkUrl600, artworkUrl100, primaryGenreName
	}

	init(from decoder: Decoder) throws {
		let c = try decoder.container(keyedBy: CodingKeys.self)
		id = try c.decode(Int.self, forKey: .collectionId)
		name = try c.decodeIfPresent(String.self, forKey: .collectionName) ?? ""
		author = try c.decodeIfPresent(String.self, forKey: .artistName) ?? ""
		feedUrl = try c.decodeIfPresent(String.self, forKey: .feedUrl) ?? ""
		artworkUrl =
			try c.decodeIfPresent(String.self, forKey: .artworkUrl600)
			?? c.decodeIfPresent(String.self, forKey: .artworkUrl100) ?? ""
		genre = try c.decodeIfPresent(String.self, forKey: .primaryGenreName) ?? ""
	}
}

/// Searches the public iTunes podcast directory, which returns each
/// podcast's RSS feed URL.
enum PodcastSearchClient {
	private struct Response: Decodable {
		let results: [PodcastSearchResult]
	}

	static func search(_ term: String, limit: Int = 50) async -> [PodcastSearchResult] {
		var components = URLComponents(string: "https://itunes.apple.com/search")!
		components.queryItems = [
			URLQueryItem(name: "media", value: "podcast"),
			URLQueryItem(name: "entity", value: "podcast"),
			URLQueryItem(name: "term", value: term),
			URLQueryItem(name: "limit", value: String(limit)),
		]
		if let country = Locale.current.region?.identifier {
			components.queryItems?.append(
				URLQueryItem(name: "country", value: country)
			)
		}
		guard let url = components.url,
			let (data, _) = try? await URLSession.shared.data(
				for: .noCacheRequest(url: url)
			),
			let response = try? JSONDecoder().decode(Response.self, from: data)
		else { return [] }
		return response.results.filter { !$0.feedUrl.isEmpty }
	}
}
