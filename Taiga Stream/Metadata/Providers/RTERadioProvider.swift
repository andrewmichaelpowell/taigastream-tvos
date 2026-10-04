//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct RTERadioProvider: MetadataProvider {
	private static let streamToApi: [String: String] = [
		"rte.ie/radio1": "https://onair.radioapi.io/rte/rteradio1/onair.json",
		"streamtheworld.com/RTE_RADIO1":
			"https://onair.radioapi.io/rte/rteradio1/onair.json",
		"rte.ie/2fm": "https://onair.radioapi.io/rte/rte2fm/onair.json",
		"streamtheworld.com/RTE_2FM":
			"https://onair.radioapi.io/rte/rte2fm/onair.json",
		"rte.ie/lyricfm": "https://onair.radioapi.io/rte/rtelyricfm/onair.json",
		"streamtheworld.com/RTE_LYRIC":
			"https://onair.radioapi.io/rte/rtelyricfm/onair.json",
		"rte.ie/rnag":
			"https://onair.radioapi.io/rte/rteraidionagaeltachta/onair.json",
		"streamtheworld.com/RTE_RNAG":
			"https://onair.radioapi.io/rte/rteraidionagaeltachta/onair.json",
		"rte.ie/gold":
			"https://onair.radioapi.io/rte/rtegold/onair.json",
		"streamtheworld.com/RTE_GOLD":
			"https://onair.radioapi.io/rte/rtegold/onair.json",
	]

	func matches(streamUrl: URL) -> Bool {
		let s = streamUrl.absoluteString
		return Self.streamToApi.keys.contains(where: { s.contains($0) })
	}

	private func apiUrl(from streamUrl: URL) -> URL? {
		let s = streamUrl.absoluteString
		guard
			let urlString = Self.streamToApi.first(where: { s.contains($0.key) }
			)?.value
		else { return nil }
		return URL(string: urlString)
	}

	func poll(streamUrl: URL, completion: @escaping (String, String) -> Void) {
		guard let apiUrl = apiUrl(from: streamUrl) else { return }

		URLSession.shared.dataTask(with: .noCacheRequest(url: apiUrl)) {
			data,
			_,
			error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any],
				let nowplaying = json["nowplaying"] as? [[String: Any]],
				let current = nowplaying.first(where: {
					($0["status"] as? String) == "playing"
				})
					?? nowplaying.first
			else { return }

			let artist = (current["artist"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let title = (current["title"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			guard !title.isEmpty else { return }

			if let imageUrlString = current["imageUrl"] as? String,
				!imageUrlString.isEmpty,
				let imageUrl = URL(string: imageUrlString)
			{
				URLSession.shared.dataTask(with: .noCacheRequest(url: imageUrl))
				{ imageData, _, imageError in
					if let imageData, imageError == nil,
						let image = UIImage(data: imageData)
					{
						DispatchQueue.main.async {
							StreamInfo.shared.applyArtwork(image)
						}
					}
				}.resume()
			}

			completion(artist, title)
		}.resume()
	}

	var pollInterval: TimeInterval? { 15 }
}
