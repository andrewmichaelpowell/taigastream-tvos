//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct RadioFranceProvider: MetadataProvider {
	private static let streamToApi: [String: String] = [
		"icecast.radiofrance.fr/fb100pour100annees80":
			"https://api.radiofrance.fr/livemeta/live/5602/transistor_musical_player",
		"icecast.radiofrance.fr/fbchansonfrancaise":
			"https://api.radiofrance.fr/livemeta/live/5601/transistor_musical_player",
		"icecast.radiofrance.fr/fip-hifi":
			"https://api.radiofrance.fr/livemeta/live/7/transistor_musical_player",
		"icecast.radiofrance.fr/fip-midfi":
			"https://api.radiofrance.fr/livemeta/live/7/transistor_musical_player",
		"icecast.radiofrance.fr/fipcultes":
			"https://api.radiofrance.fr/livemeta/live/709/transistor_musical_player",
		"icecast.radiofrance.fr/fipelectro":
			"https://api.radiofrance.fr/livemeta/live/74/transistor_musical_player",
		"icecast.radiofrance.fr/fipgroove":
			"https://api.radiofrance.fr/livemeta/live/66/transistor_musical_player",
		"icecast.radiofrance.fr/fiphiphop":
			"https://api.radiofrance.fr/livemeta/live/95/transistor_musical_player",
		"icecast.radiofrance.fr/fipjazz":
			"https://api.radiofrance.fr/livemeta/live/65/transistor_musical_player",
		"icecast.radiofrance.fr/fipmetal":
			"https://api.radiofrance.fr/livemeta/live/77/transistor_musical_player",
		"icecast.radiofrance.fr/fipmonde":
			"https://api.radiofrance.fr/livemeta/live/69/transistor_musical_player",
		"icecast.radiofrance.fr/fipnouveautes":
			"https://api.radiofrance.fr/livemeta/live/70/transistor_musical_player",
		"icecast.radiofrance.fr/fippop":
			"https://api.radiofrance.fr/livemeta/live/78/transistor_musical_player",
		"icecast.radiofrance.fr/fipreggae":
			"https://api.radiofrance.fr/livemeta/live/71/transistor_musical_player",
		"icecast.radiofrance.fr/fiprock":
			"https://api.radiofrance.fr/livemeta/live/64/transistor_musical_player",
		"icecast.radiofrance.fr/fipsacrefrancais":
			"https://api.radiofrance.fr/livemeta/live/96/transistor_musical_player",
		"icecast.radiofrance.fr/franceinter-hifi":
			"https://api.radiofrance.fr/livemeta/live/1/transistor_inter_player",
		"icecast.radiofrance.fr/franceinter-midfi":
			"https://api.radiofrance.fr/livemeta/live/1/transistor_inter_player",
		"icecast.radiofrance.fr/franceinterlamusiqueinter":
			"https://api.radiofrance.fr/livemeta/live/1101/transistor_musical_player",
		"icecast.radiofrance.fr/francemusique-hifi":
			"https://api.radiofrance.fr/livemeta/live/4/transistor_musique_player",
		"icecast.radiofrance.fr/francemusique-midfi":
			"https://api.radiofrance.fr/livemeta/live/4/transistor_musique_player",
		"icecast.radiofrance.fr/francemusiquebaroque":
			"https://api.radiofrance.fr/livemeta/live/408/transistor_musical_player",
		"icecast.radiofrance.fr/francemusiqueclassiquelove":
			"https://api.radiofrance.fr/livemeta/live/411/transistor_musical_player",
		"icecast.radiofrance.fr/francemusiqueclassiqueplus":
			"https://api.radiofrance.fr/livemeta/live/402/transistor_musical_player",
		"icecast.radiofrance.fr/francemusiqueconcertsradiofrance":
			"https://api.radiofrance.fr/livemeta/live/403/transistor_musical_player",
		"icecast.radiofrance.fr/francemusiqueeasyclassique":
			"https://api.radiofrance.fr/livemeta/live/401/transistor_musical_player",
		"icecast.radiofrance.fr/francemusiquelajazz":
			"https://api.radiofrance.fr/livemeta/live/407/transistor_musical_player",
		"icecast.radiofrance.fr/francemusiquelacontemporaine":
			"https://api.radiofrance.fr/livemeta/live/406/transistor_musical_player",
		"icecast.radiofrance.fr/francemusiquelalabo":
			"https://api.radiofrance.fr/livemeta/live/405/transistor_musical_player",
		"icecast.radiofrance.fr/francemusiquecoramonde":
			"https://api.radiofrance.fr/livemeta/live/404/transistor_musical_player",
		"icecast.radiofrance.fr/francemusiqueOpera":
			"https://api.radiofrance.fr/livemeta/live/409/transistor_musical_player",
		"icecast.radiofrance.fr/francemusiquepianozen":
			"https://api.radiofrance.fr/livemeta/live/410/transistor_musical_player",
		"icecast.radiofrance.fr/mouv-hifi":
			"https://api.radiofrance.fr/livemeta/live/6/transistor_mouv_player",
		"icecast.radiofrance.fr/mouv-midfi":
			"https://api.radiofrance.fr/livemeta/live/6/transistor_mouv_player",
	]

	func matches(streamUrl: URL) -> Bool {
		let s = streamUrl.absoluteString
		return Self.streamToApi.keys.contains(where: { s.contains($0) })
	}

	private func apiUrl(from streamUrl: URL) -> URL? {
		let s = streamUrl.absoluteString
		guard
			let urlString = Self.streamToApi.first(where: { s.contains($0.key) }
			)?
			.value
		else { return nil }
		return URL(string: urlString)
	}

	var pollInterval: TimeInterval? { nil }

	func poll(
		streamUrl: URL,
		completion: @escaping (String, String) -> Void
	) {
		guard let apiUrl = apiUrl(from: streamUrl) else { return }
		pollRadioFrance(
			apiUrl: apiUrl,
			streamUrl: streamUrl,
			completion: completion
		)
	}

	private func pollRadioFrance(
		apiUrl: URL,
		streamUrl: URL,
		completion: @escaping (String, String) -> Void
	) {
		var request = URLRequest(url: apiUrl)
		request.setValue("application/json", forHTTPHeaderField: "Accept")

		URLSession.shared.dataTask(with: request) { data, _, error in
			guard let data, error == nil,
				let json = try? JSONSerialization.jsonObject(with: data)
					as? [String: Any]
			else { return }

			if let delay = json["delayToRefresh"] as? TimeInterval {
				let interval = max(delay / 1000, 10)
				DispatchQueue.main.async {
					DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
						[self] in
						guard StreamInfo.shared.currentStreamUrl == streamUrl
						else { return }
						self.pollRadioFrance(
							apiUrl: apiUrl,
							streamUrl: streamUrl,
							completion: completion
						)
					}
				}
			}

			let nowBlock = json["now"] as? [String: Any]
			let nextBlock = (json["next"] as? [[String: Any]])?.first
			let block: [String: Any]?
			if nowBlock?["favoriteUuid"] is String {
				block = nowBlock
			} else if nextBlock?["favoriteUuid"] is String {
				block = nextBlock
			} else {
				block = nowBlock
			}

			guard let activeBlock = block else { return }

			let firstLine = (activeBlock["firstLine"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let secondLine = (activeBlock["secondLine"] as? String ?? "")
				.trimmingCharacters(in: .whitespaces)
			let parts = secondLine.components(separatedBy: " • ")

			let artist: String
			let title: String
			if parts.count >= 2 {
				artist = StreamInfo.shared.cleanMetadataString(
					parts[0].trimmingCharacters(in: .whitespaces)
				)
				title = StreamInfo.shared.cleanMetadataString(
					parts.dropFirst().joined(separator: " • ")
						.trimmingCharacters(in: .whitespaces)
				)
			} else {
				artist = ""
				title = StreamInfo.shared.cleanMetadataString(firstLine)
			}

			guard !title.isEmpty, !StreamInfo.shared.junkMetadata(title) else {
				return
			}
			completion(artist, title)
		}.resume()
	}
}
