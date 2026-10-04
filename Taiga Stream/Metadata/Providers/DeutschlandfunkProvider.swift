//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct DeutschlandfunkProvider: MetadataProvider {
	var pollInterval: TimeInterval? { 15 }

	private enum APIStyle { case nova, kultur }
	private struct APIConfig {
		let url: String
		let style: APIStyle
	}

	private static let streamToConfig: [String: APIConfig] = [
		"st03.sslstream.dlf.de": APIConfig(
			url:
				"https://static.deutschlandfunknova.de/actions/dradio/playlist/onair",
			style: .nova
		),
		"st03.dlf.de": APIConfig(
			url:
				"https://static.deutschlandfunknova.de/actions/dradio/playlist/onair",
			style: .nova
		),
		"/dlf/03/": APIConfig(
			url:
				"https://static.deutschlandfunknova.de/actions/dradio/playlist/onair",
			style: .nova
		),
		"st02.sslstream.dlf.de": APIConfig(
			url: "https://streamtext.dradio.de/drk_utf8.txt",
			style: .kultur
		),
		"st02.dlf.de": APIConfig(
			url: "https://streamtext.dradio.de/drk_utf8.txt",
			style: .kultur
		),
		"/dlf/02/": APIConfig(
			url: "https://streamtext.dradio.de/drk_utf8.txt",
			style: .kultur
		),
	]

	func matches(streamUrl: URL) -> Bool {
		let s = streamUrl.absoluteString
		return Self.streamToConfig.keys.contains(where: { s.contains($0) })
	}

	private func config(from streamUrl: URL) -> APIConfig? {
		let s = streamUrl.absoluteString
		return Self.streamToConfig.first(where: { s.contains($0.key) })?.value
	}

	func poll(streamUrl: URL, completion: @escaping (String, String) -> Void) {
		guard let config = config(from: streamUrl),
			let apiUrl = URL(string: config.url)
		else { return }

		let request = URLRequest.noCacheRequest(url: apiUrl)

		URLSession.shared.dataTask(with: request) { data, _, error in
			guard let data, error == nil else { return }

			switch config.style {
			case .nova:
				self.parseNova(data: data, completion: completion)
			case .kultur:
				self.parseKultur(data: data, completion: completion)
			}
		}.resume()
	}

	private func parseNova(
		data: Data,
		completion: @escaping (String, String) -> Void
	) {
		guard
			let json = try? JSONSerialization.jsonObject(with: data)
				as? [String: Any],
			let item = json["playlistItem"] as? [String: Any],
			(item["type"] as? String) == "Music"
		else { return }

		let title = (item["title"] as? String ?? "")
			.trimmingCharacters(in: .whitespaces)
		let artist = (item["artist"] as? String ?? "")
			.trimmingCharacters(in: .whitespaces)
		guard !title.isEmpty else { return }

		completion(artist, title)
	}

	private func parseKultur(
		data: Data,
		completion: @escaping (String, String) -> Void
	) {
		guard
			let text = String(data: data, encoding: .utf8)?
				.trimmingCharacters(in: .whitespacesAndNewlines)
		else { return }

		let (author, workTitle) = StreamInfo.shared.splitArtistTitle(from: text)
		guard !workTitle.isEmpty else { return }
		completion(author, workTitle)
	}
}
