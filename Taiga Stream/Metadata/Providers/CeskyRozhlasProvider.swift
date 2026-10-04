//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct CeskyRozhlasProvider: MetadataProvider {
	var pollInterval: TimeInterval? { 15 }

	private static let streamToStation: [String: String] = [
		"cro-radiozurnal": "radiozurnal",
		"cro-dvojka": "dvojka",
		"cro-vltava": "vltava",
		"cro-radio3": "radio3",
		"cro-plus": "plus",
		"cro-jazz": "jazz",
		"cro-d-dur": "ddur",
		"cro-radio-wave": "radiowave",
		"cro-radiozurnal-sport": "radiozurnalsport",
		"cro-radio-junior-zs": "radiojuniorzs",
		"cro-radio-junior": "radiojunior",
		"cro-radio-prague-int": "radiopragueint",
		"radio_zurnal_sport": "radiozurnalsport",
		"radio_junior_zs": "radiojuniorzs",
		"radio_prague_int": "radiopragueint",
		"radio_junior": "radiojunior",
		"radio_zurnal": "radiozurnal",
		"radio_wave": "radiowave",
		"radio3": "radio3",
		"dvojka": "dvojka",
		"vltava": "vltava",
		"d_dur": "ddur",
		"jazz": "jazz",
		"plus": "plus",
	]

	func matches(streamUrl: URL) -> Bool {
		guard let host = streamUrl.host else { return false }
		guard host.contains("amp.cesnet.cz") || host.contains("rozhlas.stream")
		else { return false }
		return stationCode(from: streamUrl) != nil
	}

	private func stationCode(from streamUrl: URL) -> String? {
		let s = streamUrl.absoluteString.lowercased()
		return Self.streamToStation.keys
			.sorted { $0.count > $1.count }
			.first(where: { s.contains($0) })
			.flatMap { Self.streamToStation[$0] }
	}

	func poll(streamUrl: URL, completion: @escaping (String, String) -> Void) {
		guard let station = stationCode(from: streamUrl),
			let apiUrl = URL(
				string:
					"https://api.rozhlas.cz/data/v2/playlist/now/\(station).json"
			)
		else { return }

		let request = URLRequest.noCacheRequest(url: apiUrl)

		URLSession.shared.dataTask(with: request) { data, _, error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any],
				let playlistData = json["data"] as? [String: Any],
				(playlistData["status"] as? String) == "onair"
			else { return }

			let artist = (playlistData["interpret"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let title = (playlistData["track"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			guard !title.isEmpty,
				!StreamInfo.shared.junkMetadata(title)
			else { return }

			if let files = playlistData["files"] as? [[String: Any]],
				let first = files.first,
				let assetString = first["asset"] as? String,
				let assetUrl = URL(string: assetString)
			{
				URLSession.shared.dataTask(with: assetUrl) { imageData, _, _ in
					if let imageData, let image = UIImage(data: imageData) {
						DispatchQueue.main.async {
							StreamInfo.shared.applyArtwork(image)
						}
					}
				}.resume()
			}

			completion(artist, title)
		}.resume()
	}
}
