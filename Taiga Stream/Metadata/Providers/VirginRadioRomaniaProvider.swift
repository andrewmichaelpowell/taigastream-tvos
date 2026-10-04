//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct VirginRadioRomaniaProvider: MetadataProvider {

	func matches(streamUrl: URL) -> Bool {
		streamUrl.host?.contains("astreaming.edi.ro") == true
	}

	func poll(streamUrl: URL, completion: @escaping (String, String) -> Void) {
		guard let apiUrl = URL(string: "https://virginradio.ro/track_info.json")
		else { return }

		let request = URLRequest.noCacheRequest(url: apiUrl)

		URLSession.shared.dataTask(with: request) { data, _, error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any],
				let songs = json["songs"] as? [[String: Any]],
				let current = songs.first
			else { return }

			let artist = (current["artist"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let title = (current["track"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			guard !title.isEmpty else { return }

			completion(artist, title)
		}.resume()
	}

	var pollInterval: TimeInterval? { 15 }
}
