//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct RadioSwissProvider: MetadataProvider {

	private static let streamToApi: [String: String] = [
		"srg-ssr.ch/srgssr/rsp":
			"https://api.radioswisspop.ch/api/v1/rsp/en/current",
		"srg-ssr.ch/m/rsp":
			"https://api.radioswisspop.ch/api/v1/rsp/en/current",
		"srg-ssr.ch/rsp": "https://api.radioswisspop.ch/api/v1/rsp/en/current",
		"radioswisspop.ch":
			"https://api.radioswisspop.ch/api/v1/rsp/en/current",
		"srg-ssr.ch/srgssr/rsj":
			"https://api.radioswissjazz.ch/api/v1/rsj/en/current",
		"srg-ssr.ch/m/rsj":
			"https://api.radioswissjazz.ch/api/v1/rsj/en/current",
		"srg-ssr.ch/rsj": "https://api.radioswissjazz.ch/api/v1/rsj/en/current",
		"radioswissjazz.ch":
			"https://api.radioswissjazz.ch/api/v1/rsj/en/current",
		"srg-ssr.ch/srgssr/rsc":
			"https://api.radioswissclassic.ch/api/v1/rsc/en/current",
		"srg-ssr.ch/m/rsc":
			"https://api.radioswissclassic.ch/api/v1/rsc/en/current",
		"srg-ssr.ch/rsc":
			"https://api.radioswissclassic.ch/api/v1/rsc/en/current",
		"radioswissclassic.ch":
			"https://api.radioswissclassic.ch/api/v1/rsc/en/current",
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
		let request = URLRequest.noCacheRequest(url: apiUrl)

		URLSession.shared.dataTask(with: request) { data, _, error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any],
				let channel = json["channel"] as? [String: Any],
				let playingNow = channel["playingnow"] as? [String: Any],
				let current = playingNow["current"] as? [String: Any],
				let metadata = current["metadata"] as? [String: Any]
			else { return }

			let title = (metadata["title"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			guard !title.isEmpty else { return }

			let artist =
				[metadata["artist"], metadata["composer"]]
				.compactMap { $0 as? String }
				.map { $0.trimmingCharacters(in: .whitespaces) }
				.first(where: { !$0.isEmpty }) ?? ""

			completion(artist, title)
		}.resume()
	}

	var pollInterval: TimeInterval? { 15 }
}
