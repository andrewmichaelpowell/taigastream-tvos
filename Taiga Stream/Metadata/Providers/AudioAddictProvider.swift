//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct AudioAddictProvider: MetadataProvider {
	private static let networks = [
		"di", "jazzradio", "rockradio", "radiotunes", "classicalradio",
		"zenradio",
	]

	func matches(streamUrl: URL) -> Bool {
		guard
			let items = URLComponents(
				url: streamUrl,
				resolvingAgainstBaseURL: false
			)?.queryItems,
			let network = items.first(where: { $0.name == "network" })?.value
		else { return false }
		return Self.networks.contains(network)
	}

	func poll(
		streamUrl: URL,
		completion: @escaping (String, String) -> Void
	) {
		guard
			let items = URLComponents(
				url: streamUrl,
				resolvingAgainstBaseURL: false
			)?.queryItems,
			let network = items.first(where: { $0.name == "network" })?.value,
			let channelId = items.first(where: { $0.name == "channel_id" })?
				.value,
			let apiUrl = URL(
				string:
					"https://api.audioaddict.com/v1/\(network)/currently_playing"
			)
		else { return }

		URLSession.shared.dataTask(with: .noCacheRequest(url: apiUrl)) {
			data,
			_,
			error in
			guard let data, error == nil,
				let channels = try? JSONSerialization.jsonObject(with: data)
					as? [[String: Any]],
				let match = channels.first(where: {
					if let id = $0["channel_id"] as? Int {
						return String(id) == channelId
					}
					if let id = $0["channel_id"] as? String {
						return id == channelId
					}
					return false
				}),
				let track = match["track"] as? [String: Any]
			else { return }

			let artist = (track["display_artist"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let title = (track["display_title"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			completion(artist, title)
		}.resume()
	}

	var pollInterval: TimeInterval? { 15 }
}
