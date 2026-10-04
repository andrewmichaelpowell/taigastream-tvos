//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct VirginRadioItalyProvider: MetadataProvider {

	func matches(streamUrl: URL) -> Bool {
		streamUrl.host?.contains("unitedradio.it") == true
	}

	func poll(streamUrl: URL, completion: @escaping (String, String) -> Void) {
		var allowedCharacters = CharacterSet.urlQueryAllowed
		allowedCharacters.remove(charactersIn: ":/?#[]@!$&'()*+,;=")

		var httpsComponents = URLComponents(
			url: streamUrl,
			resolvingAgainstBaseURL: false
		)
		httpsComponents?.scheme = "https"
		let httpsStreamUrl =
			httpsComponents?.url?.absoluteString ?? streamUrl.absoluteString

		guard
			let encodedStream = httpsStreamUrl.addingPercentEncoding(
				withAllowedCharacters: allowedCharacters
			),
			let apiUrl = URL(
				string:
					"https://www.virginradio.it/wp-json/mediaset-mediaplayer/v1/getStreamInfo?stream=\(encodedStream)"
			)
		else { return }

		let request = URLRequest.noCacheRequest(url: apiUrl)

		URLSession.shared.dataTask(with: request) { data, _, error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any],
				json["success"] as? Bool == true
			else { return }

			let artist = (json["artist"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let title = (json["title"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			guard !title.isEmpty else { return }

			completion(artist, title)
		}.resume()
	}

	var pollInterval: TimeInterval? { 15 }
}
