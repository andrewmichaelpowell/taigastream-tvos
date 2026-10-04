//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct VirginRadioFranceProvider: MetadataProvider {

	private static let streamToApi: [String: (apiUrl: String, key: String)] = [
		"virginradio.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "1"
		),
		"virginclassiquerock.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "5"
		),
		"virginrocklive.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "4"
		),
		"virginrockfrancais.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "8"
		),
		"virginlegendesdurock.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "7"
		),
		"virginmetal.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "9"
		),
		"virginrockannees60.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "15"
		),
		"virginrockannees70.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "16"
		),
		"virginrockannees80.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "10"
		),
		"virginrockannees90.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "6"
		),
		"virginrockannees2000.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "3"
		),
		"virginrockamericain.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "11"
		),
		"virginnoveauxtalents.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "14"
		),
		"virginrockparty.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "13"
		),
		"virginrockanglais.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "12"
		),
		"virginradiorockballad.ice.infomaniak.ch": (
			"https://virginradio.fr/lite/update_onair", "19"
		),
	]

	func matches(streamUrl: URL) -> Bool {
		let s = streamUrl.absoluteString
		return Self.streamToApi.keys.contains(where: { s.contains($0) })
	}

	private func apiEntry(from streamUrl: URL) -> (apiUrl: String, key: String)?
	{
		let s = streamUrl.absoluteString
		return Self.streamToApi.first(where: { s.contains($0.key) })?.value
	}

	func poll(streamUrl: URL, completion: @escaping (String, String) -> Void) {
		guard let entry = apiEntry(from: streamUrl),
			let apiUrl = URL(string: entry.apiUrl),
			let siteUrl = URL(string: "https://virginradio.fr")
		else { return }

		let sessionConfig = URLSessionConfiguration.ephemeral
		sessionConfig.httpCookieAcceptPolicy = .always
		sessionConfig.httpShouldSetCookies = true
		let session = URLSession(configuration: sessionConfig)

		session.dataTask(with: URLRequest.noCacheRequest(url: siteUrl)) {
			_,
			_,
			_ in
			self.fetchOnAir(
				session: session,
				apiUrl: apiUrl,
				entry: entry,
				completion: completion
			)
		}.resume()
	}

	private func fetchOnAir(
		session: URLSession,
		apiUrl: URL,
		entry: (apiUrl: String, key: String),
		completion: @escaping (String, String) -> Void
	) {
		var request = URLRequest.noCacheRequest(url: apiUrl)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.setValue("*/*", forHTTPHeaderField: "Accept")
		request.setValue(
			"https://virginradio.fr/",
			forHTTPHeaderField: "Referer"
		)
		request.setValue("https://virginradio.fr", forHTTPHeaderField: "Origin")
		request.setValue(
			"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
			forHTTPHeaderField: "User-Agent"
		)
		request.httpBody = try? JSONSerialization.data(
			withJSONObject: ["radio_ids": [entry.key]]
		)

		session.dataTask(with: request) { data, response, error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any],
				let station = json[entry.key] as? [String: Any]
			else { return }

			let artist = (station["artist"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let title = (station["title"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			guard !title.isEmpty else { return }

			if let coverString = station["cover"] as? String,
				!coverString.isEmpty,
				!coverString.hasPrefix("/"),
				let coverUrl = URL(string: coverString)
			{
				session.dataTask(with: coverUrl) { imageData, _, imageError in
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
