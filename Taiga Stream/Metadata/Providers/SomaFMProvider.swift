//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct SomaFMProvider: MetadataProvider {
	func matches(streamUrl: URL) -> Bool {
		guard let host = streamUrl.host else { return false }
		return streamUrl.absoluteString.contains("somafm.com")
			&& host.contains("somafm")
	}

	private func apiUrl(from streamUrl: URL) -> URL? {
		let mountName =
			streamUrl.pathComponents.first(where: { !$0.isEmpty && $0 != "/" })
			?? ""
		let channel = mountName.components(separatedBy: "-").first ?? ""
		guard !channel.isEmpty else { return nil }
		return URL(string: "https://somafm.com/songs/\(channel).json")
	}

	func poll(
		streamUrl: URL,
		completion: @escaping (String, String) -> Void
	) {
		guard let apiUrl = apiUrl(from: streamUrl) else { return }
		URLSession.shared.dataTask(with: .noCacheRequest(url: apiUrl)) {
			data,
			_,
			error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any],
				let songs = json["songs"] as? [[String: Any]],
				let first = songs.first
			else { return }

			let title = (first["title"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let artist = (first["artist"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			completion(artist, title)
		}.resume()
	}

	var pollInterval: TimeInterval? { 15 }
}
