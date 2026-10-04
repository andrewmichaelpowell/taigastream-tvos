//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct NRKProvider: MetadataProvider {
	private static let channelMap: [String: String] = [
		"p1": "https://psapi.nrk.no/channels/p1/liveelements",
		"p1pluss": "https://psapi.nrk.no/channels/p1pluss/liveelements",
		"p2": "https://psapi.nrk.no/channels/p2/liveelements",
		"p3": "https://psapi.nrk.no/channels/p3/liveelements",
		"p3musikk": "https://psapi.nrk.no/channels/p3musikk/liveelements",
		"mp3": "https://psapi.nrk.no/channels/mp3/liveelements",
		"nyheter": "https://psapi.nrk.no/channels/nyheter/liveelements",
		"radio_super": "https://psapi.nrk.no/channels/radio_super/liveelements",
		"klassisk": "https://psapi.nrk.no/channels/klassisk/liveelements",
		"sapmi": "https://psapi.nrk.no/channels/sapmi/liveelements",
		"jazz": "https://psapi.nrk.no/channels/jazz/liveelements",
		"folkemusikk": "https://psapi.nrk.no/channels/folkemusikk/liveelements",
		"sport": "https://psapi.nrk.no/channels/sport/liveelements",
	]

	private static let sortedKeys = channelMap.keys.sorted {
		$0.count > $1.count
	}

	func matches(streamUrl: URL) -> Bool {
		guard let host = streamUrl.host else { return false }
		return host.contains("nrk-live-radio-world.akamaized.net")
	}

	private func apiUrl(from streamUrl: URL) -> URL? {
		let s = streamUrl.absoluteString

		guard let key = Self.sortedKeys.first(where: { s.contains($0) }) else {
			return nil
		}

		return URL(string: Self.channelMap[key]!)
	}

	func poll(
		streamUrl: URL,
		completion: @escaping (String, String) -> Void
	) {
		guard let apiUrl = apiUrl(from: streamUrl) else { return }
		var request = URLRequest.noCacheRequest(url: apiUrl)
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		URLSession.shared.dataTask(with: request) { data, _, error in
			guard let data, error == nil,
				let elements = try? JSONSerialization.jsonObject(with: data)
					as? [[String: Any]]
			else { return }

			let current =
				elements.reversed().first {
					($0["relativeTimeType"] as? String) == "Present"
						&& ($0["type"] as? String) == "Music"
				}
				?? elements.reversed().first {
					($0["relativeTimeType"] as? String) == "Past"
						&& ($0["type"] as? String) == "Music"
				}

			guard let element = current else { return }

			let title = (element["title"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let artist = (element["description"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			guard !title.isEmpty else { return }

			if let imageUrlString = element["imageUrl"] as? String,
				!imageUrlString.isEmpty,
				let imageUrl = URL(string: imageUrlString)
			{
				URLSession.shared.dataTask(with: .noCacheRequest(url: imageUrl))
				{
					imageData,
					_,
					imageError in
					if let imageData, imageError == nil,
						let image = UIImage(data: imageData)
					{
						DispatchQueue.main.async {
							StreamInfo.shared.updateNowPlaying(
								artist: artist.isEmpty
									? "Taiga Stream" : artist,
								title: title
							)
							StreamInfo.shared.applyArtwork(image)
						}
						return
					}
					completion(artist, title)
				}.resume()
			} else {
				completion(artist, title)
			}
		}.resume()
	}

	var pollInterval: TimeInterval? { 15 }
}
