//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct VirginRadioOmanProvider: MetadataProvider {

	func matches(streamUrl: URL) -> Bool {
		guard let host = streamUrl.host else { return false }
		return host == "uk5.internet-radio.com" && streamUrl.port == 8115
	}

	func poll(streamUrl: URL, completion: @escaping (String, String) -> Void) {
		guard
			let apiUrl = URL(
				string:
					"http://uk5.internet-radio.com:8115/played?sid=1&type=json&callback=cb&_=\(Int(Date().timeIntervalSince1970 * 1000))"
			)
		else { return }

		let request = URLRequest.noCacheRequest(url: apiUrl)

		URLSession.shared.dataTask(with: request) { data, _, error in
			guard let data, error == nil,
				var text = String(data: data, encoding: .utf8)
			else { return }

			if let start = text.firstIndex(of: "["),
				let end = text.lastIndex(of: "]")
			{
				text = String(text[start...end])
			}

			guard let jsonData = text.data(using: .utf8),
				let entries = try? JSONSerialization.jsonObject(with: jsonData)
					as? [[String: Any]],
				let current = entries.first,
				let metadata = current["metadata"] as? [String: Any],
				let urlString = metadata["url"] as? String
			else { return }

			let queryString =
				urlString.hasPrefix("&")
				? String(urlString.dropFirst())
				: urlString

			var params: [String: String] = [:]
			for pair in queryString.components(separatedBy: "&") {
				let parts = pair.components(separatedBy: "=")
				guard parts.count == 2 else { continue }
				let key = parts[0]
				let value =
					parts[1]
					.replacingOccurrences(of: "+", with: " ")
					.removingPercentEncoding ?? parts[1]
				params[key] = value
			}

			let artist = (params["artist"] ?? "").trimmingCharacters(
				in: .whitespaces
			)
			let title = (params["title"] ?? "").trimmingCharacters(
				in: .whitespaces
			)
			guard !title.isEmpty else { return }

			completion(artist, title)
		}.resume()
	}
	var pollInterval: TimeInterval? { 15 }
}
