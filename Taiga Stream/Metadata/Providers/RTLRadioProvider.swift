//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct RTLRadioProvider: MetadataProvider {
	func matches(streamUrl: URL) -> Bool {
		guard let host = streamUrl.host else { return false }
		return streamUrl.absoluteString.contains("streamabc.net")
			&& host.contains("rtl")
	}

	private func channelKey(from streamUrl: URL) -> String? {
		guard
			let pathFirst = streamUrl.pathComponents.first(where: {
				!$0.isEmpty && $0 != "/"
			})
		else { return nil }
		let parts = pathFirst.components(separatedBy: "-")
		let key = parts.dropFirst().prefix(while: {
			Int($0) == nil && $0 != "mp3" && $0 != "aac"
				&& !["128", "64", "192", "320"].contains($0)
		}).joined(separator: "-")
		return key.isEmpty ? nil : key
	}

	func poll(
		streamUrl: URL,
		completion: @escaping (String, String) -> Void
	) {
		guard let channelKey = channelKey(from: streamUrl),
			let apiUrl = URL(
				string:
					"https://www.rtlradio.de/services/program-info/live/lux"
			)
		else { return }

		URLSession.shared.dataTask(with: .noCacheRequest(url: apiUrl)) {
			data,
			_,
			error in
			guard let data, error == nil,
				let channels = try? JSONSerialization.jsonObject(with: data)
					as? [[String: Any]]
			else { return }

			let normalizedTarget = channelKey.replacingOccurrences(
				of: "-",
				with: ""
			)
			guard
				let match = channels.first(where: {
					let key = ($0["channelKey"] as? String ?? "")
						.replacingOccurrences(of: "-", with: "")
					return key == normalizedTarget
				}),
				let history = (match["playHistories"] as? [[String: Any]])?
					.first,
				let track = history["track"] as? [String: Any]
			else { return }

			let artist = (track["artist"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let title = (track["title"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)

			if let artworkUrlString = track["itunesCover"] as? String,
				let artworkUrl = URL(string: artworkUrlString)
			{
				URLSession.shared.dataTask(
					with: .noCacheRequest(url: artworkUrl)
				) {
					imageData,
					_,
					imageError in
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
